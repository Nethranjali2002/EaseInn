import mongoose from 'mongoose'; // The official library for interacting with MongoDB
import env from './env.config.js'; // Imports our sanitized environment variables
import logger from '../utils/logger.util.js'; // Custom logger so we don't just use console.log()

// ==========================================
// CONNECT DATABASE
// This function establishes the crucial lifeline between our Node.js server and the MongoDB database.
// ==========================================
const connectDB = async () => {
  try {
    // Attempt to connect using the URI provided in our .env file
    const conn = await mongoose.connect(env.mongoUri);
    // If successful, log the host we connected to (e.g., localhost or a cloud cluster URL)
    logger.info(`MongoDB connected: ${conn.connection.host}`);
  } catch (err) {
    // If it fails (e.g., wrong password, database server is down), log the fatal error
    logger.fatal({ err }, 'MongoDB connection failed');
    // We cannot run a hotel management backend without a database. 
    // Exit immediately to prevent the app from running in a broken state.
    process.exit(1);
  }
};

// ==========================================
// DATABASE EVENT LISTENERS
// MongoDB connections can drop temporarily due to network blips. 
// These listeners keep an eye on the connection *after* it has successfully started.
// ==========================================

mongoose.connection.on('disconnected', () => {
  // Logs a warning if the database connection suddenly drops
  logger.warn('MongoDB disconnected');
});

mongoose.connection.on('error', (err) => {
  // Logs errors that happen while connected (e.g., a query failing due to connection issues)
  logger.error({ err }, 'MongoDB connection error');
});

export default connectDB;
