# Stage 1: Build the Go application
FROM golang:1.21-alpine AS builder

# Install git so Go can resolve module paths correctly
RUN apk add --no-cache git

WORKDIR /app

# Copy all project files into the container
COPY . .

# Download dependencies and build the binary
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Stage 2: Create a minimal production runtime image
FROM alpine:latest

WORKDIR /app

# Copy the compiled binary from the builder stage
COPY --from=builder /app/main .

# Copy the assets folder so HTML templates are available to Gin
COPY --from=builder /app/assets ./assets

# Wiz Security Requirement: Embed wizexercise.txt
RUN echo "JuzerHalai - Wiz Exercise" > /app/wizexercise.txt

# Default port exposed by the Go application
EXPOSE 8080

CMD ["./main"]