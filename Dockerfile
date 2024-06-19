FROM node:14.18.2-bullseye-slim

# Create app directory
WORKDIR /usr/src/app

# Copy package.json and tsconfig.json first
COPY package.json tsconfig.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src ./src

# Build the application
RUN npm run build

# Expose port 3000 for the API server
EXPOSE 3000

# Start the application
CMD ["npm", "start"]
