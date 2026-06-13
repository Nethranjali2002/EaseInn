import swaggerJsdoc from 'swagger-jsdoc'; // Tool to read `/* @swagger */` comments from our code and turn them into JSON
import swaggerUi from 'swagger-ui-express'; // Tool to generate a beautiful HTML webpage from that JSON

// ==========================================
// SWAGGER CONFIGURATION
// This powers the interactive API documentation page available at /api-docs
// ==========================================
const options = {
  definition: {
    openapi: '3.0.0', // We are using OpenAPI specification version 3
    info: {
      title: 'EaseInn API',
      version: '1.0.0',
      description: 'Resort Property Management System API',
    },
    servers: [
      // The base URL that the "Try it out" buttons will send requests to
      { url: 'http://localhost:3000/api/v1', description: 'Development' },
    ],
    components: {
      // Tells Swagger that our API requires a "Bearer Token" in the Authorization header
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
      // ==========================================
      // REUSABLE SCHEMAS (Data Models)
      // We define these here so we don't have to re-type them in every single route's documentation
      // ==========================================
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
        // Standardized Error Response Model
        Error: {
          type: 'object',
          properties: {
            success: { type: 'boolean', example: false },
            message: { type: 'string' },
          },
        },
      },
    },
    // Applies the Bearer Token requirement globally to all endpoints by default
    security: [{ bearerAuth: [] }],
  },
  // Tells the Swagger engine to go look inside the 'routes' folder and scrape out all the comments
  apis: ['./src/routes/*.js'],
};

// Generate the final JSON specification
const swaggerSpec = swaggerJsdoc(options);

// ==========================================
// SETUP SWAGGER
// Mounts the HTML UI and the raw JSON file to our Express app
// ==========================================
export const setupSwagger = (app) => {
  // Mount the interactive UI to the /api-docs route
  app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }', // Hide the green Swagger logo bar for a cleaner look
    customSiteTitle: 'EaseInn API Documentation',
  }));
  
  // Provide the raw JSON file at /api-docs.json (useful if you want to import our API into Postman)
  app.get('/api-docs.json', (req, res) => res.json(swaggerSpec));
};
