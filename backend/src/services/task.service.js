import Task from '../models/task.model.js'; // The database model representing a chore/maintenance ticket
import Property from '../models/property.model.js'; // Database model representing the hotel
import User from '../models/user.model.js'; // Database model representing staff members
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import { generateTaskCode } from '../utils/codeGenerator.js'; // Helper that makes a random string like "TSK-3F9A"


// ==========================================
// 1. CREATE TASK
// Creates a new chore and optionally assigns it right away
// ==========================================
export const createTask = async (data, assignedBy) => {
  const property = await Property.findById(data.property);
  if (!property) throw new AppError('Property not found', 404);

  // If the manager specified a staff member, verify they actually exist
  if (data.assignedTo) {
    const assignee = await User.findById(data.assignedTo);
    if (!assignee) throw new AppError('Assigned user not found', 404);
  }

  // If the task is linked to a specific hotel room (e.g., "Clean Room 101")
  if (data.room) {
    // Dynamic import to avoid circular dependency loops between room and task models
    const { default: Room } = await import('../models/room.model.js');
    const room = await Room.findById(data.room);
    if (!room) throw new AppError('Room not found', 404);
    
    // Security check: Make sure they aren't assigning a task to a room in a totally different hotel
    if (room.property.toString() !== data.property) {
      throw new AppError('Room does not belong to this property', 400);
    }
  }

  // Generate the task and unique ID
  const task = await Task.create({ ...data, assignedBy, code: await generateTaskCode() });
  
  // Return the newly created task, but immediately inject the full details of the assignee and room so the frontend can display them right away
  return task.populate(['assignedTo', 'room', 'booking']);
};


// ==========================================
// 2. GET TASKS (For Managers)
// Fetches the master list of all chores across the whole hotel
// ==========================================
export const getTasks = async (propertyId, { page = 1, limit = 20, status, type, assignedTo, priority }) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  const query = { property: propertyId };
  if (status) query.status = status; // e.g. "Only show 'open' tasks"
  if (type) query.type = type;       // e.g. "Only show 'housekeeping'"
  if (assignedTo) query.assignedTo = assignedTo; // e.g. "Show me all tasks assigned to John"
  if (priority) query.priority = priority; // e.g. "Only show 'high' priority"

  const total = await Task.countDocuments(query);
  const tasks = await Task.find(query)
    .populate('assignedTo', 'name email') // Show who is doing it
    .populate('assignedBy', 'name email') // Show who ordered it
    .populate('room', 'roomNumber roomType') // Show where it is
    .populate('booking', 'guest.name checkIn checkOut') // Show if it relates to a specific guest's stay
    .sort({ priority: 1, dueDate: 1 }) // Automatically sort by Priority first, then by Due Date
    .skip((page - 1) * limit)
    .limit(limit);
    
  return { tasks, total, page, limit };
};


// ==========================================
// 3. GET MY TASKS (For Staff)
// A simplified view where a cleaner only sees their own to-do list
// ==========================================
export const getMyTasks = async (userId, { page = 1, limit = 20, status }) => {
  const query = { assignedTo: userId };
  if (status) query.status = status;

  const total = await Task.countDocuments(query);
  const tasks = await Task.find(query)
    .populate('assignedTo', 'name email')
    .populate('room', 'roomNumber roomType')
    .populate('booking', 'guest.name checkIn checkOut')
    .sort({ priority: 1, dueDate: 1 }) // Prioritize the most urgent stuff
    .skip((page - 1) * limit)
    .limit(limit);

  return { tasks, total, page, limit };
};


// ==========================================
// 4. GET TASK BY ID
// ==========================================
export const getTaskById = async (taskId) => {
  const task = await Task.findById(taskId)
    .populate('assignedTo', 'name email')
    .populate('assignedBy', 'name email')
    .populate('room', 'roomNumber roomType')
    .populate('booking', 'guest.name checkIn checkOut');
  if (!task) throw new AppError('Task not found', 404);
  return task;
};


// The fields that are legally allowed to be edited
const ALLOWED_TASK_UPDATES = ['title', 'description', 'type', 'priority', 'status', 'assignedTo', 'dueDate', 'dueTime', 'notes', 'images', 'estimatedDuration'];


// ==========================================
// 5. UPDATE TASK
// ==========================================
export const updateTask = async (taskId, updates, userId, userRole) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);

  // Security: Cleaners can only edit tasks that are actually assigned to them
  if (userRole === 'staff' && task.assignedTo?.toString() !== userId) {
    throw new AppError('You can only update tasks assigned to you', 403);
  }

  // Security: Basic Managers can only edit tasks they created, or tasks assigned to them.
  // (Full Admins skip this check and can edit anything)
  if (userRole !== 'admin' && userRole !== 'manager') {
    if (task.assignedBy?.toString() !== userId && task.assignedTo?.toString() !== userId) {
      throw new AppError('You can only update tasks you created or are assigned to', 403);
    }
  }

  const sanitized = {};
  for (const key of ALLOWED_TASK_UPDATES) {
    if (updates[key] !== undefined) sanitized[key] = updates[key];
  }

  if (Object.keys(sanitized).length === 0) {
    throw new AppError('No valid fields to update', 400);
  }

  Object.assign(task, sanitized);
  await task.save();
  return task.populate(['assignedTo', 'room', 'booking']);
};


// ==========================================
// 6. COMPLETE TASK
// A specialized workflow to close out a task and log exactly how long it took
// ==========================================
export const completeTask = async (taskId, userId, userRole, data = {}) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);

  // Security check for standard staff
  if (userRole === 'staff' && task.assignedTo?.toString() !== userId) {
    throw new AppError('You can only complete tasks assigned to you', 403);
  }

  if (task.status === 'completed') {
    throw new AppError('Task is already completed', 409);
  }

  // Update core status
  task.status = 'completed';
  task.completedAt = new Date();
  task.completedBy = userId; // Log exactly who pressed the button

  // If the staff member uploaded proof photos (e.g. "Look, the toilet is clean")
  if (data.completedImages && Array.isArray(data.completedImages)) {
    task.completedImages = data.completedImages;
  }

  if (data.completionNotes) {
    task.notes = data.completionNotes;
  }

  // Calculate Performance Metric: Exactly how many minutes passed between creation and completion
  if (task.createdAt) {
    const durationMs = new Date() - new Date(task.createdAt);
    task.actualDuration = Math.round(durationMs / 60000); // convert milliseconds to minutes
  }

  await task.save();
  return task.populate(['assignedTo', 'room', 'booking']);
};


// ==========================================
// 7. TOGGLE SUBTASK
// Allows checking off individual steps inside a larger task
// ==========================================
export const toggleSubtask = async (taskId, subtaskIndex, completed, userId, userRole) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);

  if (userRole === 'staff' && task.assignedTo?.toString() !== userId) {
    throw new AppError('You can only modify tasks assigned to you', 403);
  }

  if (subtaskIndex < 0 || subtaskIndex >= task.subtasks.length) {
    throw new AppError('Subtask not found', 404);
  }

  task.subtasks[subtaskIndex].completed = completed;
  task.subtasks[subtaskIndex].completedAt = completed ? new Date() : undefined;
  await task.save();
  return task;
};


// ==========================================
// 8. TOGGLE CHECKLIST
// Similar to subtasks, but specifically for the built-in standardized checklists
// ==========================================
export const toggleChecklist = async (taskId, checklistIndex, checked, userId, userRole) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);

  if (userRole === 'staff' && task.assignedTo?.toString() !== userId) {
    throw new AppError('You can only modify tasks assigned to you', 403);
  }

  if (checklistIndex < 0 || checklistIndex >= task.checklist.length) {
    throw new AppError('Checklist item not found', 404);
  }

  task.checklist[checklistIndex].checked = checked;
  task.checklist[checklistIndex].checkedAt = checked ? new Date() : undefined;
  await task.save();
  return task;
};


// ==========================================
// 9. GET TASK STATS
// Math engine for the dashboard widgets to show manager bottlenecks
// ==========================================
export const getTaskStats = async (propertyId) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  // Run multiple rapid counts
  const totalTasks = await Task.countDocuments({ property: propertyId });
  const openTasks = await Task.countDocuments({ property: propertyId, status: 'open' });
  const inProgressTasks = await Task.countDocuments({ property: propertyId, status: 'in-progress' });
  const completedTasks = await Task.countDocuments({ property: propertyId, status: 'completed' });
  
  // Custom query to find things that are NOT done, and the due date has already passed
  const overdueTasks = await Task.countDocuments({
    property: propertyId,
    status: { $in: ['open', 'in-progress'] },
    dueDate: { $lt: new Date() },
  });

  return { totalTasks, openTasks, inProgressTasks, completedTasks, overdueTasks };
};


// ==========================================
// 10. DELETE TASK
// ==========================================
export const deleteTask = async (taskId, userId, userRole) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);

  // Security: Staff can never delete tasks to hide their work.
  if (userRole === 'staff') {
    throw new AppError('Staff members cannot delete tasks', 403);
  }

  const property = await Property.findById(task.property);
  if (property && property.owner.toString() !== userId && userRole !== 'admin') {
    throw new AppError('You can only delete tasks in your own properties', 403);
  }

  await Task.findByIdAndDelete(taskId);
  return true;
};
