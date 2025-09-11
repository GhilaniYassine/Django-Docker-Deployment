# Django Docker Deployment with Multistage Build

This project demonstrates how to containerize a Django application using Docker with multistage builds for production-ready deployment.

## What is Multistage Docker Build?

A **multistage build** uses multiple `FROM` statements in a single Dockerfile. Each stage can serve different purposes:
- **Build Stage**: Install dependencies, compile code, download packages
- **Production Stage**: Copy only necessary artifacts from build stage

**Benefits:**
- **Smaller final image**: Build tools and caches are left in the build stage
- **Security**: Fewer attack vectors (no build tools in production)
- **Performance**: Faster deployment and less storage usage

## Dockerfile Analysis

### Stage 1: Builder Stage
```dockerfile
FROM python:3.13-slim AS builder
```
**Purpose**: Creates the build environment
- `python:3.13-slim`: Smaller base image (~45MB vs ~350MB for full Python)
- `AS builder`: Names this stage for referencing later
- **Alternative**: Could use `alpine` for even smaller size (~15MB)

```dockerfile
RUN mkdir /app
WORKDIR /app
```
**Purpose**: Sets up working directory
- Creates application directory
- Sets context for subsequent commands

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
```
**Purpose**: Optimizes Python for containers
- `PYTHONDONTWRITEBYTECODE=1`: No `.pyc` files (saves space, faster builds)
- `PYTHONUNBUFFERED=1`: Real-time output (crucial for Docker logs)

```dockerfile
RUN pip install --upgrade pip
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
```
**Purpose**: Installs dependencies efficiently
- Updates pip for latest features/security
- `--no-cache-dir`: Prevents pip cache storage (reduces image size)
- **Layer Caching**: requirements.txt copied separately for cache optimization

### Stage 2: Production Stage
```dockerfile
FROM python:3.13-slim
```
**Purpose**: Fresh, clean base for production
- Same base image but without build artifacts
- Clean slate for production environment

```dockerfile
RUN useradd -m -r appuser && \
   mkdir /app && \
   chown -R appuser /app
```
**Purpose**: Security best practices
- `useradd -m -r appuser`: Creates non-root user with home directory
- `-r`: System user (no login shell)
- `chown -R appuser /app`: Gives ownership to app user
- **Security**: Prevents privilege escalation attacks

```dockerfile
COPY --from=builder /usr/local/lib/python3.13/site-packages/ /usr/local/lib/python3.13/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
```
**Purpose**: Copies only installed packages from builder
- `--from=builder`: References first stage
- Copies Python packages without pip cache or build tools
- **Result**: All dependencies available without build overhead

```dockerfile
COPY --chown=appuser:appuser . .
```
**Purpose**: Copies application code with proper ownership
- `--chown`: Sets ownership during copy (more efficient than separate chown)
- Copies entire project to container

```dockerfile
USER appuser
```
**Purpose**: Switches to non-root user
- **Security**: Application runs with limited privileges
- **Best Practice**: Never run containers as root in production

```dockerfile
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "3", "dockerdj.wsgi:application"]
```
**Purpose**: Production-ready WSGI server
- **Gunicorn**: Production WSGI server (vs Django's dev server)
- `--bind 0.0.0.0:8000`: Binds to all interfaces on port 8000
- `--workers 3`: Multiple worker processes for concurrency
- `dockerdj.wsgi:application`: Points to Django WSGI application

## Why Gunicorn Instead of Django Dev Server?

### Django Development Server (`manage.py runserver`)
- **Purpose**: Development only
- **Limitations**: 
  - Single-threaded
  - Not secure
  - Poor performance
  - Memory leaks
  - No production features

### Gunicorn (Green Unicorn)
- **Purpose**: Production WSGI server
- **Benefits**:
  - Multi-worker processes
  - Better performance
  - Memory management
  - Process recycling
  - Load balancing
  - Signal handling

## Stream Buffering in Docker

### Buffered vs Unbuffered Output

**Buffered Mode (Default)**:
```python
# Output collected in buffer
print("Hello")  # Stored in buffer
print("World")  # Still in buffer
# Buffer flushed when full or program exits
```

**Unbuffered Mode (`PYTHONUNBUFFERED=1`)**:
```python
# Output sent immediately
print("Hello")  # Immediately visible in Docker logs
print("World")  # Immediately visible in Docker logs
```

### Why `PYTHONUNBUFFERED=1` Matters in Docker

**Without Unbuffered**:
- Logs appear delayed or not at all
- Debugging becomes difficult
- Health checks may fail
- Poor monitoring experience

**With Unbuffered**:
- Real-time log streaming
- Immediate error visibility
- Better debugging experience
- Proper health monitoring

## Image Size Comparison

| Build Type | Approximate Size | Components |
|------------|------------------|------------|
| Single Stage | ~400MB | Base image + pip cache + build tools + dependencies + app |
| Multistage | ~180MB | Base image + dependencies + app only |
| Alpine Multistage | ~120MB | Alpine base + dependencies + app only |

## Security Benefits

### Non-Root User
```dockerfile
USER appuser
```
- **Prevents**: Privilege escalation attacks
- **Limits**: File system access
- **Reduces**: Attack surface

### Clean Production Image
- No build tools (pip, gcc, etc.)
- No package caches
- Minimal attack vectors
- Reduced complexity

## Build and Run Commands

### Build the Image
```bash
docker build -t django-app:multistage .
```

### Run in Development
```bash
docker run -p 8000:8000 django-app:multistage
```

### Run with Environment File
```bash
docker run -p 8000:8000 --env-file .env django-app:multistage
```

### Production Deployment
```bash
docker run -d \
  --name django-prod \
  -p 80:8000 \
  --restart unless-stopped \
  --env-file .env.prod \
  django-app:multistage
```

## Best Practices Implemented

1. **Multistage Build**: Smaller, cleaner production images
2. **Non-Root User**: Enhanced security
3. **Proper Ownership**: Correct file permissions
4. **Production WSGI**: Gunicorn for performance and reliability
5. **Environment Variables**: Flexible configuration
6. **Layer Optimization**: Efficient Docker layer caching
7. **Unbuffered Output**: Real-time logging and monitoring

This configuration provides a production-ready Django application with optimal security, performance, and maintainability.
