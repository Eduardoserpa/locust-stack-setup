# Build layer - uses local matrix-locust directory
FROM python:3.11-alpine as builder

# Install build tools (git not needed since we use COPY, gcc for compiling Python packages)
RUN apk add --no-cache gcc libffi-dev musl-dev openssl-dev poetry python3-dev

# Set the working directory
WORKDIR /app

# Copy the local matrix-locust directory (instead of cloning from GitHub)
COPY . .

# Install the dependencies using Poetry without creating a virtual environment
RUN poetry config virtualenvs.create false && \
    poetry install --only main --no-root

# Main image - minimal runtime
FROM python:3.11-alpine

# Install runtime dependencies only (no build tools)
RUN apk add --no-cache libffi openssl

# Set the working directory
WORKDIR /app

# Copy the entire application and installed packages from builder
COPY --from=builder /app .
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages/

# Update the PATH environment variable to include the app directory
ENV PATH="/app:${PATH}"
PYTHONUNBUFFERED=1

# Expose web UI running from container
EXPOSE 8089

# Default command - keep container running
CMD ["sleep", "infinity"]
