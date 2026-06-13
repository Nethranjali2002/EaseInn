import * as roomService from '../services/room.service.js'; // Imports the Brain that handles Room logic (like checking capacity)
import { sendSuccess } from '../utils/response.util.js'; // Helper to format JSON response beautifully
import { logAudit } from '../utils/audit.util.js'; // Helper to silently record manager actions for security tracking

// ==========================================
// 1. CREATE ROOM
// ==========================================
export const createRoom = async (req, res, next) => {
  try {
    // Pass the specific property ID, the user creating it, and the raw room JSON data to the Service
    const room = await roomService.createRoom(req.params.propertyId, req.user.sub, req.body);
    
    // Silently log that this specific manager created this exact room number
    await logAudit({ user: req.user.sub, action: 'create', entity: 'Room', entityId: room._id, description: `Created room: ${room.roomNumber}`, ip: req.ip });
    
    // Respond to the frontend with a 201 Created and the new room object
    return sendSuccess(res, { statusCode: 201, message: 'Room created', data: { room } });
  } catch (err) { 
    // Catch validation or duplicate errors (like room already exists) and pass to Global Error Handler
    return next(err); 
  }
};

// ==========================================
// 2. GET ROOMS
// ==========================================
export const getRooms = async (req, res, next) => {
  try {
    // Extract search filters (e.g., roomType='deluxe', status='available') from the URL query
    const { page, limit, status, roomType, search } = req.query;
    
    // Pass the property ID and pagination/search filters to the Service to fetch the correct data slice
    const result = await roomService.getRooms(req.params.propertyId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, status, roomType, search });
    
    // Send the resulting array of rooms back to the frontend
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

// ==========================================
// 3. GET ROOM BY ID
// ==========================================
export const getRoomById = async (req, res, next) => {
  try {
    // Fetch a single, specific room's full details (images, amenities, past bookings) using its unique ID
    const room = await roomService.getRoomById(req.params.id);
    return sendSuccess(res, { data: { room } });
  } catch (err) { return next(err); }
};

// ==========================================
// 4. UPDATE ROOM
// ==========================================
export const updateRoom = async (req, res, next) => {
  try {
    // Pass the room ID, the new data, and the user's role to the Service (to ensure only Admins can change prices)
    const room = await roomService.updateRoom(req.params.id, req.body, req.user.sub, req.user.role);
    
    // Log the exact update in the Audit Logs
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Room', entityId: room._id, description: `Updated room: ${room.roomNumber}`, ip: req.ip });
    
    return sendSuccess(res, { message: 'Room updated', data: { room } });
  } catch (err) { return next(err); }
};

// ==========================================
// 5. DELETE ROOM
// ==========================================
export const deleteRoom = async (req, res, next) => {
  try {
    // Permanently erases the room (but restricts this action to Admins or specific Manager roles)
    await roomService.deleteRoom(req.params.id, req.user.sub, req.user.role);
    
    // Log the destructive action
    await logAudit({ user: req.user.sub, action: 'delete', entity: 'Room', entityId: req.params.id, description: 'Deleted room', ip: req.ip });
    
    return sendSuccess(res, { message: 'Room deleted' });
  } catch (err) { return next(err); }
};

// ==========================================
// 6. GET AVAILABLE ROOMS (Booking Engine)
// ==========================================
export const getAvailableRooms = async (req, res, next) => {
  try {
    // Extract exact check-in and check-out dates from the URL query
    const { checkIn, checkOut, roomType } = req.query;
    
    // The Service runs a complex MongoDB query to find rooms that DO NOT overlap with existing bookings on those dates
    const rooms = await roomService.getAvailableRooms(req.params.propertyId, checkIn, checkOut, roomType);
    
    // Send only the actually available rooms back to the guest booking engine
    return sendSuccess(res, { data: { rooms } });
  } catch (err) { return next(err); }
};
