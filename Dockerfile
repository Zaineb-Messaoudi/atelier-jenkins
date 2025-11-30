FROM alpine:3.21

# Install Java and bash
RUN apk add --no-cache openjdk17 bash

# Set working directory
WORKDIR /app

# Copy Spring Boot JAR
COPY target/student-management-0.0.1-SNAPSHOT.jar /app/student-management.jar

# Copy wait-for-it.sh
COPY wait-for-it.sh /app/wait-for-it.sh
RUN chmod +x /app/wait-for-it.sh

# Default command (optional, can be overridden in compose)
CMD ["./wait-for-it.sh", "mysql-db:3306", "--", "java", "-jar", "/app/student-management.jar"]

