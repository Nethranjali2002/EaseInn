import * as taskService from '../services/task.service.js';
import { sendSuccess } from '../utils/response.util.js';
import { logAudit } from '../utils/audit.util.js';
import { sendTaskAssignedNotification, sendTaskCompletedNotification } from '../utils/push.util.js';

export const createTask = async (req, res, next) => {
  try {
    const task = await taskService.createTask(req.body, req.user.sub);
    await logAudit({ user: req.user.sub, action: 'create', entity: 'Task', entityId: task._id, description: `Created task: ${task.title}`, ip: req.ip });
    await sendTaskAssignedNotification(task).catch(() => {});
    return sendSuccess(res, { statusCode: 201, message: 'Task created', data: { task } });
  } catch (err) { return next(err); }
};

export const getTasks = async (req, res, next) => {
  try {
    const { page, limit, status, type, assignedTo, priority } = req.query;
    const result = await taskService.getTasks(req.params.propertyId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, status, type, assignedTo, priority });
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

export const getMyTasks = async (req, res, next) => {
  try {
    const { page, limit, status } = req.query;
    const result = await taskService.getMyTasks(req.user.sub, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, status });
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

export const getTaskById = async (req, res, next) => {
  try {
    const task = await taskService.getTaskById(req.params.id);
    return sendSuccess(res, { data: { task } });
  } catch (err) { return next(err); }
};

export const updateTask = async (req, res, next) => {
  try {
    const oldTask = await taskService.getTaskById(req.params.id);
    const oldAssignee = oldTask.assignedTo?._id?.toString();
    const task = await taskService.updateTask(req.params.id, req.body, req.user.sub, req.user.role);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Task', entityId: task._id, description: `Updated task: ${task.title}`, ip: req.ip });
    if (req.body.assignedTo && req.body.assignedTo !== oldAssignee) {
      await sendTaskAssignedNotification(task).catch(() => {});
    }
    return sendSuccess(res, { message: 'Task updated', data: { task } });
  } catch (err) { return next(err); }
};

export const completeTask = async (req, res, next) => {
  try {
    const task = await taskService.completeTask(req.params.id, req.user.sub, req.user.role, req.body);
    await logAudit({ user: req.user.sub, action: 'task', entity: 'Task', entityId: task._id, description: `Completed task: ${task.title}`, ip: req.ip });
    await sendTaskCompletedNotification(task).catch(() => {});
    return sendSuccess(res, { message: 'Task completed', data: { task } });
  } catch (err) { return next(err); }
};

export const toggleSubtask = async (req, res, next) => {
  try {
    const task = await taskService.toggleSubtask(req.params.id, parseInt(req.params.index), req.body.completed, req.user.sub, req.user.role);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Task', entityId: req.params.id, changes: { index: parseInt(req.params.index), completed: req.body.completed }, description: 'Subtask toggled', ip: req.ip });
    return sendSuccess(res, { data: { task } });
  } catch (err) { return next(err); }
};

export const toggleChecklist = async (req, res, next) => {
  try {
    const task = await taskService.toggleChecklist(req.params.id, parseInt(req.params.index), req.body.checked, req.user.sub, req.user.role);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Task', entityId: req.params.id, changes: { index: parseInt(req.params.index), checked: req.body.checked }, description: 'Checklist item toggled', ip: req.ip });
    return sendSuccess(res, { data: { task } });
  } catch (err) { return next(err); }
};

export const getTaskStats = async (req, res, next) => {
  try {
    const stats = await taskService.getTaskStats(req.params.propertyId);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};

export const deleteTask = async (req, res, next) => {
  try {
    await taskService.deleteTask(req.params.id, req.user.sub, req.user.role);
    await logAudit({ user: req.user.sub, action: 'delete', entity: 'Task', entityId: req.params.id, description: 'Deleted task', ip: req.ip });
    return sendSuccess(res, { message: 'Task deleted successfully' });
  } catch (err) { return next(err); }
};
