import { env } from '../config/env.config.js'; // Brings in secure environment variables
import logger from './logger.util.js';

// The specific internet address where ImgBB accepts incoming files
const IMGBB_API_URL = 'https://api.imgbb.com/1/upload';

// ==========================================
// 1. UPLOAD TO IMG B B (Core Engine)
// Takes raw binary image data (a "Buffer") and pushes it to an external image hosting service.
// We do this so the hotel's own server doesn't run out of hard drive space holding thousands of photos.
// ==========================================
export const uploadToImgBB = async (buffer, filename, mimeType, expiration = 0) => {
  if (!env.imgbbApiKey) {
    throw new Error('IMGBB_API_KEY is not configured');
  }

  // Convert the raw binary data into a giant string of text (Base64) so it can be sent inside an HTTP request
  const base64Data = buffer.toString('base64');

  // Prepare the data package exactly how the ImgBB API expects it
  const formData = new URLSearchParams();
  formData.append('key', env.imgbbApiKey); // Our secret password for the service
  formData.append('image', base64Data);    // The actual picture
  formData.append('name', filename.replace(/\.[^.]+$/, '')); // The file name, stripping off the '.jpg' at the end
  
  if (expiration > 0) {
    formData.append('expiration', String(expiration));
  }

  // Shoot the data package over the internet
  const response = await fetch(IMGBB_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: formData.toString(),
  });

  const result = await response.json();

  if (!result.success) {
    logger.error({ result }, 'ImgBB upload failed');
    throw new Error(result.error?.message || 'ImgBB upload failed');
  }

  // Return the public URL so the frontend can display the newly uploaded image immediately
  return {
    url: result.data.url,
    displayUrl: result.data.display_url,
    deleteUrl: result.data.delete_url,
    width: parseInt(result.data.width, 10) || 0,
    height: parseInt(result.data.height, 10) || 0,
    size: parseInt(result.data.size, 10) || 0,
  };
};

// ==========================================
// 2. UPLOAD FILE TO IMG B B (Multer Wrapper)
// A helper function designed to work nicely with "Multer" (the tool we use in the routes to catch incoming files)
// ==========================================
export const uploadFileToImgBB = async (file, expiration = 0) => {
  // If Multer gave us the file in memory, use it. If Multer saved it to the local disk temporarily, read it from the disk.
  const buffer = file.buffer || (file.path ? await import('fs').then(fs => fs.readFileSync(file.path)) : null);
  if (!buffer) {
    throw new Error('No file buffer available for upload');
  }
  // Pass it off to the core engine above
  return uploadToImgBB(buffer, file.originalname, file.mimetype, expiration);
};

// ==========================================
// 3. UPLOAD MULTIPLE TO IMG B B
// Handles arrays of files (like when a manager uploads 5 pictures of a new room at the same time)
// ==========================================
export const uploadMultipleToImgBB = async (files, expiration = 0) => {
  // Create an array of upload tasks
  const uploads = files.map(file => uploadFileToImgBB(file, expiration));
  
  // `Promise.all` fires them all off at the exact same time, rather than waiting for them to finish one by one.
  // This makes uploading multiple photos extremely fast.
  return Promise.all(uploads);
};
