import * as roomService from '../services/room.service.js';
import { sendSuccess } from '../utils/response.util.js';
import { logAudit } from '../utils/audit.util.js';

export const createRoom = async (req, res, next) => {
  try {
    const room = await roomService.createRoom(req.params.propertyId, req.user.sub, req.body);
    await logAudit({ user: req.user.sub, action: 'create', entity: 'Room', entityId: room._id, description: `Created room: ${room.roomNumber}`, ip: req.ip });
    return sendSuccess(res, { statusCode: 201, message: 'Room created', data: { room } });
  } catch (err) { return next(err); }
};

export const getRooms = async (req, res, next) => {
  try {
    const { page, limit, status, roomType, search } = req.query;
    const result = await roomService.getRooms(req.params.propertyId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, status, roomType, search });
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

export const getRoomById = async (req, res, next) => {
  try {
    const room = await roomService.getRoomById(req.params.id);
    return sendSuccess(res, { data: { room } });
  } catch (err) { return next(err); }
};

export const updateRoom = async (req, res, next) => {
  try {
    const room = await roomService.updateRoom(req.params.id, req.body);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Room', entityId: room._id, description: `Updated room: ${room.roomNumber}`, ip: req.ip });
    return sendSuccess(res, { message: 'Room updated', data: { room } });
  } catch (err) { return next(err); }
};

export const deleteRoom = async (req, res, next) => {
  try {
    await roomService.deleteRoom(req.params.id);
    await logAudit({ user: req.user.sub, action: 'delete', entity: 'Room', entityId: req.params.id, description: 'Deleted room', ip: req.ip });
    return sendSuccess(res, { message: 'Room deleted' });
  } catch (err) { return next(err); }
};

export const getAvailableRooms = async (req, res, next) => {
  try {
    const { checkIn, checkOut, roomType } = req.query;
    const rooms = await roomService.getAvailableRooms(req.params.propertyId, checkIn, checkOut, roomType);
    return sendSuccess(res, { data: { rooms } });
  } catch (err) { return next(err); }
};
