import swaggerJsdoc from 'swagger-jsdoc';
import swaggerUi from 'swagger-ui-express';

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'EaseInn API',
      version: '1.0.0',
      description: 'Resort Property Management System API',
    },
    servers: [
      { url: 'http://localhost:3000/api/v1', description: 'Development' },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      schemas: {
        User: {
          type: 'object',
          properties: {
            _id: { type: 'string' },
            name: { type: 'string' },
            email: { type: 'string' },
            role: { type: 'string', enum: ['user', 'admin'] },
          },
        },
        Property: {
          type: 'object',
          properties: {
            _id: { type: 'string' },
            name: { type: 'string' },
            description: { type: 'string' },
            address: { type: 'object' },
            totalRooms: { type: 'integer' },
          },
        },
        Room: {
          type: 'object',
          properties: {
            _id: { type: 'string' },
            roomNumber: { type: 'string' },
            roomType: { type: 'string' },
            capacity: { type: 'integer' },
            basePrice: { type: 'number' },
            status: { type: 'string' },
          },
        },
        Booking: {
          type: 'object',
          properties: {
            _id: { type: 'string' },
            guest: { type: 'object' },
            checkIn: { type: 'string', format: 'date' },
            checkOut: { type: 'string', format: 'date' },
            bookingStatus: { type: 'string' },
            paymentStatus: { type: 'string' },
            pricing: { type: 'object' },
          },
        },
        Task: {
          type: 'object',
          properties: {
            _id: { type: 'string' },
            title: { type: 'string' },
            type: { type: 'string' },
            priority: { type: 'string' },
            status: { type: 'string' },
          },
        },
        Payment: {
          type: 'object',
          properties: {
            _id: { type: 'string' },
            amount: { type: 'number' },
            method: { type: 'string' },
            status: { type: 'string' },
            invoiceNumber: { type: 'string' },
          },
        },
        Error: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: false },
            message: { type: 'string' },
          },
        },
      },
    },
    security: [{ bearerAuth: [] }],
  },
  apis: [],
};

const swaggerSpec = swaggerJsdoc(options);

export const setupSwagger = (app) => {
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'EaseInn API Documentation',
  }));
  app.get('/api-docs.json', (req, res) => res.json(swaggerSpec));
};
