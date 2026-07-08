import pino from 'pino'; 

const isProduction = process.env.NODE_ENV === 'production';

// PINO LOGGER CONFIGURATION
// This replaces standard `console.log()` to provide timestamped, colorized, and structured logs.
// In production, it prints raw, lightning-fast JSON so analytics tools (like Datadog/Splunk) can parse it.
// In development, it uses 'pino-pretty' to format it beautifully for human eyes in the terminal.
const logger = pino({
  level: process.env.LOG_LEVEL || 'info', // 'debug', 'info', 'warn', 'error'
  ...(isProduction
    ? {} 
    : {
        transport: {
          target: 'pino-pretty',
          options: {
            colorize: true, 
            translateTime: 'SYS:yyyy-mm-dd HH:MM:ss', 
            ignore: 'pid,hostname', 
          },
        },
      }),
});

export default logger;
