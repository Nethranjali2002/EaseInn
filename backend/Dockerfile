FROM node:20-alpine AS base

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

RUN mkdir -p /app/uploads/images /app/uploads/documents && chown -R appuser:appgroup /app/uploads

COPY package*.json ./

FROM base AS production
RUN npm ci --omit=dev
COPY src/ ./src/
RUN chown -R appuser:appgroup /app/uploads
USER appuser
EXPOSE 3000
CMD ["node", "src/server.js"]

FROM base AS development
RUN npm install
COPY . .
RUN chown -R appuser:appgroup /app/uploads
USER appuser
EXPOSE 3000
CMD ["node", "--watch", "src/server.js"]
