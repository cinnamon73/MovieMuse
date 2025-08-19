# Use a small Node image
FROM node:18-alpine

# Create app directory
WORKDIR /app

# Install deps
COPY package*.json ./
RUN npm ci --only=production

# Copy source
COPY server.js ./

# Expose port
ENV PORT=3001
EXPOSE 3001

# Health
HEALTHCHECK --interval=30s --timeout=5s CMD wget -qO- http://localhost:$PORT/health || exit 1

# Start
CMD ["node", "server.js"] 