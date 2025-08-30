# Use OpenJDK 17 as base image - slim version for smaller image size
FROM openjdk:17-jdk-slim

# Set metadata for the image
LABEL maintainer="developer@example.com"
LABEL description="Spring Boot Demo REST API"
LABEL version="1.0.0"

# Set working directory inside container
WORKDIR /app

# Copy the JAR file from target directory to container
# The * wildcard handles different JAR naming conventions
COPY target/*.jar app.jar

# Expose port 8080 (default Spring Boot port)
# This is for documentation - actual port mapping happens at runtime
EXPOSE 8080

# Set JVM options for optimal container performance
ENV JAVA_OPTS="-Xms256m -Xmx512m -Djava.security.egd=file:/dev/./urandom"

# Create non-root user for security
RUN addgroup --system --gid 1001 appuser && \
    adduser --system --uid 1001 --gid 1001 --no-create-home appuser

# Change ownership of app directory to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Run the Spring Boot application
# Using exec form to ensure proper signal handling
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
