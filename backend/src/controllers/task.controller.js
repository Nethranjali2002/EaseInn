import * as taskService from '../services/task.service.js'; // Imports the Brain handling Staff Tasks (e.g. housekeeping)
import { sendSuccess } from '../utils/response.util.js'; // Helper for formatting JSON responses
import { logAudit } from '../utils/audit.util.js'; // Records task creation and assignment for accountability


// ==========================================
// 1. CREATE TASK
// ==========================================
export const createTask = async (req, res, next) => {
  try {
    // Pass the raw task data (title, assigned staff ID, due date) and the creator's ID to the Service
    const task = await taskService.createTask(req.body, req.user.sub, req.user.role);
    
    // Log exactly who created this task and for what
    await logAudit({ user: req.user.sub, action: 'create', entity: 'Task', entityId: task._id, description: `Created task: ${task.title}`, ip: req.ip });
    
    // Respond with a 201 Created and the new task object
    return sendSuccess(res, { statusCode: 201, message: 'Task created', data: { task } });
  } catch (err) { return next(err); }
};


// ==========================================
// 2. GET TASKS
// ==========================================
export const getTasks = async (req, res, next) => {
  try {
    // Extract filters (e.g., status='pending', priority='high', or assignedTo='staff123')
    const { page, limit, status, priority, assignedTo, search } = req.query;
    
    // Pass the property ID, filters, and the user's role to the Service. 
    // The Service will ensure normal Staff only see their OWN tasks, while Admins see ALL tasks.
    const result = await taskService.getTasks(req.params.propertyId, req.user.sub, req.user.role, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, status, priority, assignedTo, search });
    
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};


// ==========================================
// 3. GET TASK BY ID
// ==========================================
export const getTaskById = async (req, res, next) => {
  try {
    // Fetches the full details of a single task (including checklist items and room numbers)
    const task = await taskService.getTaskById(req.params.id, req.user.sub, req.user.role);
    return sendSuccess(res, { data: { task } });
  } catch (err) { return next(err); }
};


// ==========================================
// 4. UPDATE TASK
// ==========================================
export const updateTask = async (req, res, next) => {
  try {
    // Passes the task ID and new data to the Service. Only Admins or the assigned Staff member can update it.
    const task = await taskService.updateTask(req.params.id, req.body, req.user.sub, req.user.role);
    
    // Log the exact update
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Task', entityId: task._id, description: `Updated task: ${task.title}`, ip: req.ip });
    
    return sendSuccess(res, { message: 'Task updated', data: { task } });
  } catch (err) { return next(err); }
};


// ==========================================
// 5. UPDATE TASK STATUS
// ==========================================
export const updateTaskStatus = async (req, res, next) => {
  try {
    // A fast endpoint just for changing status (e.g., dragging a task from "To Do" to "In Progress" on a Kanban board)
    const task = await taskService.updateTaskStatus(req.params.id, req.body.status, req.user.sub, req.user.role);
    
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Task', entityId: task._id, changes: { status: req.body.status }, description: `Task status updated to ${req.body.status}`, ip: req.ip });
    
    return sendSuccess(res, { data: { task } });
  } catch (err) { return next(err); }
};


// ==========================================
// 6. TOGGLE SUBTASK (Checklist items)
// ==========================================
export const toggleSubtask = async (req, res, next) => {
  try {
    // Updates a specific subtask (e.g., "Cleaned Mirror") inside a main Housekeeping Task
    const task = await taskService.toggleSubtask(req.params.id, parseInt(req.params.index), req.body.completed, req.user.sub, req.user.role);
    
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Task', entityId: req.params.id, changes: { index: parseInt(req.params.index), completed: req.body.completed }, description: 'Subtask toggled', ip: req.ip });
    
    return sendSuccess(res, { data: { task } });
  } catch (err) { return next(err); }
};


// ==========================================
// 7. TOGGLE CHECKLIST
// ==========================================
export const toggleChecklist = async (req, res, next) => {
  try {
    // Similar to Subtasks, toggles specific checklist items
    const task = await taskService.toggleChecklist(req.params.id, parseInt(req.params.index), req.body.checked, req.user.sub, req.user.role);
    
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Task', entityId: req.params.id, changes: { index: parseInt(req.params.index), checked: req.body.checked }, description: 'Checklist item toggled', ip: req.ip });
    
    return sendSuccess(res, { data: { task } });
  } catch (err) { return next(err); }
};


// ==========================================
// 8. GET TASK STATS
// ==========================================
export const getTaskStats = async (req, res, next) => {
  try {
    // Fetches math for the dashboard (e.g., 5 Pending, 2 In Progress, 10 Completed today)
    const stats = await taskService.getTaskStats(req.params.propertyId);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};


// ==========================================
// 9. DELETE TASK
// ==========================================
export const deleteTask = async (req, res, next) => {
  try {
    // Permanently deletes the task (restricted to Admins)
    await taskService.deleteTask(req.params.id, req.user.sub, req.user.role);
    
    await logAudit({ user: req.user.sub, action: 'delete', entity: 'Task', entityId: req.params.id, description: 'Deleted task', ip: req.ip });
    
    return sendSuccess(res, { message: 'Task deleted successfully' });
  } catch (err) { return next(err); }
};
