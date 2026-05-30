import Task from '../models/task.model.js';
import Property from '../models/property.model.js';
import { AppError } from '../middlewares/error.middleware.js';

export const createTask = async (data, assignedBy) => {
  const property = await Property.findById(data.property);
  if (!property) throw new AppError('Property not found', 404);

  const task = await Task.create({ ...data, assignedBy });
  return task.populate(['assignedTo', 'room', 'booking']);
};

export const getTasks = async (propertyId, { page = 1, limit = 20, status, type, assignedTo, priority }) => {
  const query = { property: propertyId };
  if (status) query.status = status;
  if (type) query.type = type;
  if (assignedTo) query.assignedTo = assignedTo;
  if (priority) query.priority = priority;

  const total = await Task.countDocuments(query);
  const tasks = await Task.find(query)
    .populate('assignedTo', 'name email')
    .populate('assignedBy', 'name email')
    .populate('room', 'roomNumber roomType')
    .populate('booking', 'guest.name checkIn checkOut')
    .sort({ priority: 1, dueDate: 1 })
    .skip((page - 1) * limit)
    .limit(limit);
  return { tasks, total, page, limit };
};

export const getMyTasks = async (userId, { page = 1, limit = 20, status }) => {
  const query = { assignedTo: userId };
  if (status) query.status = status;

  const total = await Task.countDocuments(query);
  const tasks = await Task.find(query)
    .populate('assignedTo', 'name email')
    .populate('room', 'roomNumber roomType')
    .populate('booking', 'guest.name checkIn checkOut')
    .sort({ priority: 1, dueDate: 1 })
    .skip((page - 1) * limit)
    .limit(limit);
    
  console.log(`[DEBUG] getMyTasks for user \${userId}: found \${tasks.length} tasks.`);
  tasks.forEach(t => console.log(`[DEBUG] Task \${t._id} assigned to \${t.assignedTo?._id || t.assignedTo}`));
  
  return { tasks, total, page, limit };
};

export const getTaskById = async (taskId) => {
  const task = await Task.findById(taskId)
    .populate('assignedTo', 'name email')
    .populate('assignedBy', 'name email')
    .populate('room', 'roomNumber roomType')
    .populate('booking', 'guest.name checkIn checkOut');
  if (!task) throw new AppError('Task not found', 404);
  return task;
};

export const updateTask = async (taskId, updates, userId, userRole) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);
  if (userRole === 'staff' && task.assignedTo?.toString() !== userId) {
    throw new AppError('You can only update tasks assigned to you', 403);
  }
  Object.assign(task, updates);
  await task.save();
  return task.populate(['assignedTo', 'room', 'booking']);
};

export const completeTask = async (taskId, userId, userRole) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);
  if (userRole === 'staff' && task.assignedTo?.toString() !== userId) {
    throw new AppError('You can only complete tasks assigned to you', 403);
  }
  task.status = 'completed';
  task.completedAt = new Date();
  task.completedBy = userId;

  // Calculate actual duration in minutes if task was created with a timestamp
  if (task.createdAt) {
    const durationMs = new Date() - new Date(task.createdAt);
    task.actualDuration = Math.round(durationMs / 60000);
  }

  await task.save();
  return task.populate(['assignedTo', 'room', 'booking']);
};

export const toggleSubtask = async (taskId, subtaskIndex, completed, userId, userRole) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);
  if (userRole === 'staff' && task.assignedTo?.toString() !== userId) {
    throw new AppError('You can only modify tasks assigned to you', 403);
  }
  if (subtaskIndex >= task.subtasks.length) throw new AppError('Subtask not found', 404);

  task.subtasks[subtaskIndex].completed = completed;
  task.subtasks[subtaskIndex].completedAt = completed ? new Date() : undefined;
  await task.save();
  return task;
};

export const toggleChecklist = async (taskId, checklistIndex, checked, userId, userRole) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);
  if (userRole === 'staff' && task.assignedTo?.toString() !== userId) {
    throw new AppError('You can only modify tasks assigned to you', 403);
  }
  if (checklistIndex >= task.checklist.length) throw new AppError('Checklist item not found', 404);

  task.checklist[checklistIndex].checked = checked;
  task.checklist[checklistIndex].checkedAt = checked ? new Date() : undefined;
  await task.save();
  return task;
};

export const getTaskStats = async (propertyId) => {
  const totalTasks = await Task.countDocuments({ property: propertyId });
  const openTasks = await Task.countDocuments({ property: propertyId, status: 'open' });
  const inProgressTasks = await Task.countDocuments({ property: propertyId, status: 'in-progress' });
  const completedTasks = await Task.countDocuments({ property: propertyId, status: 'completed' });
  const overdueTasks = await Task.countDocuments({
    property: propertyId,
    status: { $in: ['open', 'in-progress'] },
    dueDate: { $lt: new Date() },
  });

  return { totalTasks, openTasks, inProgressTasks, completedTasks, overdueTasks };
};

export const deleteTask = async (taskId, userId, userRole) => {
  const task = await Task.findById(taskId);
  if (!task) throw new AppError('Task not found', 404);
  
  if (userRole === 'staff') {
    throw new AppError('Staff members cannot delete tasks', 403);
  }
  
  await Task.findByIdAndDelete(taskId);
  return true;
};
