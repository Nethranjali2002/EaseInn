import pino from 'pino'; // An extremely fast, modern logging library

// Determine if the server is running live on the internet, or just locally on a developer's laptop
const isProduction = process.env.NODE_ENV === 'production';

// ==========================================
// PINO LOGGER CONFIGURATION
// This replaces standard `console.log()` to provide timestamped, colorized, and structured logs.
// In production, it prints raw, lightning-fast JSON so analytics tools (like Datadog/Splunk) can parse it.
// In development, it uses 'pino-pretty' to format it beautifully for human eyes in the terminal.
// ==========================================
const logger = pino({
  level: process.env.LOG_LEVEL || 'info', // 'debug', 'info', 'warn', 'error'
  ...(isProduction
    ? {} // Production: Output raw JSON for maximum speed and machine readability
    : {
        // Development: Make it pretty
        transport: {
          target: 'pino-pretty',
          options: {
            colorize: true, // Make warnings yellow, errors red, etc.
            translateTime: 'SYS:yyyy-mm-dd HH:MM:ss', // Add human-readable timestamps
            ignore: 'pid,hostname', // Hide unnecessary machine info from the terminal
          },
        },
      }),
});

export default logger;
