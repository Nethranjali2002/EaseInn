import express from 'express';
import cookieParser from 'cookie-parser';
import path from 'path';
import { fileURLToPath } from 'url';
import { helmetMiddleware, corsMiddleware, rateLimiter } from './middlewares/security.middleware.js';
import errorHandler from './middlewares/error.middleware.js';
import routes from './routes/index.js';
import { setupSwagger } from './config/swagger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

app.use(helmetMiddleware);
app.use(corsMiddleware);
app.use(rateLimiter);
app.use(express.json({ limit: '10kb' }));
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());

setupSwagger(app);

app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use('/guest', express.static(path.join(__dirname, '../web')));

app.use('/api/v1', routes);

app.use((_req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

app.use(errorHandler);

export default app;
