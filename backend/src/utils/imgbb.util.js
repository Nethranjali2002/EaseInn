import { env } from '../config/env.config.js'; // Brings in secure environment variables
import logger from './logger.util.js';

const IMGBB_API_URL = 'https://api.imgbb.com/1/upload';

export const uploadToImgBB = async (buffer, filename, mimeType, expiration = 0) => {
  if (!env.imgbbApiKey) {
    throw new Error('IMGBB_API_KEY is not configured');
  }

  const base64Data = buffer.toString('base64');

  const formData = new URLSearchParams();
  formData.append('key', env.imgbbApiKey); 
  formData.append('image', base64Data);    
  formData.append('name', filename.replace(/\.[^.]+$/, '')); 
  
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

// 
export const uploadFileToImgBB = async (file, expiration = 0) => {
  const buffer = file.buffer || (file.path ? await import('fs').then(fs => fs.readFileSync(file.path)) : null);
  if (!buffer) {
    throw new Error('No file buffer available for upload');
  }
  return uploadToImgBB(buffer, file.originalname, file.mimetype, expiration);
};

export const uploadMultipleToImgBB = async (files, expiration = 0) => {
  const uploads = files.map(file => uploadFileToImgBB(file, expiration));
  
  return Promise.all(uploads);
};
