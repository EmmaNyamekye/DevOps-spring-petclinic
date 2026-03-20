# ─────────────────────────────────────────────────
# Dockerfile · Spring PetClinic
# Multi-stage build:
#   Stage 1 (builder) – compiles the JAR
#   Stage 2 (runtime) – lean production image
# ─────────────────────────────────────────────────

# ── Stage 1: Build ────────────────────────────────
FROM eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /app

# Copy Maven wrapper and pom first (layer caching –
# only re-downloads dependencies when pom changes)
COPY mvnw pom.xml ./
COPY .mvn .mvn

RUN ./mvnw dependency:go-offline -q

# Copy source and build
COPY src ./src
RUN ./mvnw package -DskipTests -q

# ── Stage 2: Runtime ──────────────────────────────
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Non-root user for security best practice
RUN addgroup -S petclinic && adduser -S petclinic -G petclinic
USER petclinic

# Copy only the fat JAR from the builder stage
COPY --from=builder /app/target/*.jar app.jar

# Expose the default Spring Boot port
EXPOSE 8080

# Health check – Docker will mark container unhealthy
# if the actuator endpoint stops responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]