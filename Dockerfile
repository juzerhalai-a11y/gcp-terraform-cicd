FROM node:18-alpine

WORKDIR /app

# Copy application dependencies and install them
COPY package*.json ./
RUN npm install

# Copy the rest of your application source code
COPY . .

# Embed the wizexercise.txt file with your name as required by the exercise
RUN echo "JuzerHalai - Wiz Exercise" > /app/wizexercise.txt

EXPOSE 3000
CMD ["npm", "start"]