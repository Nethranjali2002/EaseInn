import app from './app.js';
import env from './config/env.config.js';
import connectDB from './config/db.config.js';
import logger from './utils/logger.util.js';
import { startScheduler } from './utils/scheduler.util.js';

const start = async () => {
  if (!env.jwt.secret) {
    logger.fatal('JWT_SECRET is not set — aborting');
    process.exit(1);
  }

  await connectDB();

  startScheduler();

  app.listen(env.port, () => {
    logger.info(`Server running in ${env.nodeEnv} mode on port ${env.port}`);
  });
};

process.on('unhandledRejection', (err) => {
  logger.fatal({ err }, 'Unhandled rejection — shutting down');
  process.exit(1);
});

process.on('uncaughtException', (err) => {
  logger.fatal({ err }, 'Uncaught exception — shutting down');
  process.exit(1);
});

start();
