import multer from 'multer'; // The middleware library used to intercept incoming file uploads
import path from 'path';
import { AppError } from '../middlewares/error.middleware.js';

// ==========================================
// 1. FILE FILTER
// A security checkpoint. We don't want hackers uploading .exe viruses or malicious scripts.
// ==========================================
const fileFilter = (req, file, cb) => {
  // Regex defining exactly which file extensions we consider "safe"
  const allowedTypes = /jpeg|jpg|png|gif|webp|pdf|doc|docx/;
  
  // Test the file extension (e.g., ".jpg")
  const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
  // Test the hidden MIME type (e.g., "image/jpeg")
  const mimetype = allowedTypes.test(file.mimetype);

  if (extname && mimetype) {
    // Pass the checkpoint
    cb(null, true);
  } else {
    // Fail the checkpoint
    cb(new AppError('Only images (JPG, PNG, GIF, WebP) and documents (PDF, DOC) are allowed', 400), false);
  }
};

// Instead of saving files to the hard drive, we hold them purely in RAM (memory).
// This is because we immediately forward them to `imgbb.util.js` (cloud hosting) and don't need to keep a local copy.
const storage = multer.memoryStorage();

// The configured engine, complete with a 10MB file size limit to prevent people from crashing the server by uploading 4K movies.
export const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 Megabytes
  fileFilter,
});

// ==========================================
// UPLOAD SINGLE
// Intercepts exactly one file. E.g. When a user changes their profile picture.
// ==========================================
export const uploadSingle = (fieldName) => upload.single(fieldName);

// ==========================================
// UPLOAD MULTIPLE
// Intercepts an array of files. E.g. When creating a new room and uploading 5 photos of the bathroom/bed.
// Limits them to 5 maximum to prevent spam.
// ==========================================
export const uploadMultiple = (fieldName, maxCount = 5) => upload.array(fieldName, maxCount);
