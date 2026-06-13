import app from './app.js'; // Imports the fully configured Express application
import env from './config/env.config.js'; // Imports our sanitized environment variables
import connectDB from './config/db.config.js'; // Helper function to establish the MongoDB connection
import logger from './utils/logger.util.js'; // The centralized logging utility
import { startScheduler } from './utils/scheduler.util.js'; // The cron job manager for hourly reminders

// ==========================================
// SERVER BOOTSTRAP (The Starting Point)
// This file is the absolute entry point of the entire backend application.
// When you run `npm start`, this is the file that Node.js executes first.
// ==========================================

const start = async () => {
  // CRITICAL SECURITY CHECK: Never start the server if the JWT secret is missing
  // Doing so would mean passwords and tokens are either unencrypted or encrypted with 'undefined'
  if (!env.jwt.secret) {
    logger.fatal('JWT_SECRET is not set — aborting');
    process.exit(1); // Exit code 1 tells the host OS that the app crashed
  }

  // Await the database connection. If this fails, the server won't start.
  await connectDB();

  // Boot up the background worker that sends hourly emails and reminders
  startScheduler();

  // Finally, open the port and start listening for incoming HTTP requests
  app.listen(env.port, () => {
    logger.info(`Server running in ${env.nodeEnv} mode on port ${env.port}`);
  });
};

// ==========================================
// UNHANDLED ERROR CATCHERS
// If a Promise fails and we forgot to add a .catch() block, it ends up here.
// These are absolute safety nets to prevent "silent failures" where the app is frozen but running.
// ==========================================

process.on('unhandledRejection', (err) => {
  logger.fatal({ err }, 'Unhandled rejection — shutting down');
  // It's safer to kill the process and let Docker/PM2 restart it than to continue in an unknown state
  process.exit(1);
});

// If synchronous code crashes and we didn't wrap it in a try/catch, it ends up here.
process.on('uncaughtException', (err) => {
  logger.fatal({ err }, 'Uncaught exception — shutting down');
  process.exit(1);
});

// Fire the ignition!
start();
