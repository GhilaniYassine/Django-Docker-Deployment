# Django Docker Deployment

This project demonstrates how to containerize a Django application using Docker with proper environment variable management.

## Docker Configuration Process

### Dockerfile Breakdown

```dockerfile
FROM python:3.13
```
**Purpose**: Sets the base image for our container
- Uses Python 3.13 official image from Docker Hub
- Includes Python runtime and pip pre-installed
- **Alternative**: Could use `python:3.13-slim` for smaller image size or `python:3.13-alpine` for minimal footprint

```dockerfile
RUN mkdir /app
WORKDIR /app
```
**Purpose**: Creates and sets the working directory
- Creates `/app` directory inside container
- Sets it as working directory for subsequent commands
- **Alternative**: Could use `/usr/src/app` (more conventional) or any other path

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
```
**Purpose**: Optimizes Python behavior in containers
- `PYTHONDONTWRITEBYTECODE=1`: Prevents Python from creating `.pyc` files (saves space)
- `PYTHONUNBUFFERED=1`: Forces Python output to be sent directly to terminal (better logging)
- **Benefits**: Faster builds, better debugging, cleaner container

```dockerfile
RUN pip install --upgrade pip
```
**Purpose**: Ensures latest pip version
- Updates pip to latest version for security and features
- **Alternative**: Could pin specific pip version for reproducibility

```dockerfile
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
```
**Purpose**: Installs Python dependencies efficiently
- Copies requirements first (Docker layer caching optimization)
- `--no-cache-dir`: Reduces image size by not storing pip cache
- **Benefits**: If code changes but requirements don't, this layer is cached

```dockerfile
COPY . /app/
```
**Purpose**: Copies entire project to container
- Copies all project files to `/app/`
- Done after pip install for better caching

```dockerfile
EXPOSE 8000
```
**Purpose**: Documents which port the container uses
- Informs Docker that app listens on port 8000
- **Note**: Doesn't actually publish the port (done with `docker run -p`)

```dockerfile
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```
**Purpose**: Defines default command when container starts
- Runs Django development server
- `0.0.0.0:8000`: Binds to all interfaces (necessary for Docker networking)
- **Alternative**: Could use `gunicorn` for production

## Django Settings Changes

### Environment Variable Loading
```python
from dotenv import load_dotenv
load_dotenv()
```
**Purpose**: Loads environment variables from `.env` file
- **Benefits**: 
  - Keeps secrets out of code
  - Different configs for dev/prod
  - Easy configuration management

### Secret Key Management
```python
SECRET_KEY = os.environ.get("SECRET_KEY", 'django-insecure-fallback-key-change-in-production')
```
**Changes Made**: Added fallback value and environment variable loading
- **Benefits**:
  - Prevents empty SECRET_KEY errors
  - Allows different keys per environment
  - Security best practice (secrets in env vars)

### Debug Configuration
```python
DEBUG = bool(os.environ.get("DEBUG", default=0))
```
**Purpose**: Controls debug mode via environment
- **Benefits**:
  - Easy to disable debug in production
  - No code changes needed between environments

### Allowed Hosts
```python
ALLOWED_HOSTS = os.environ.get("ALLOWED_HOSTS","127.0.0.1").split(",")
```
**Purpose**: Configures allowed hosts from environment
- **Benefits**:
  - Different hosts for different environments
  - Easy to add new hosts without code changes
  - Security: prevents host header attacks

## Why These Changes Are Beneficial

### 1. **Security**
- Secrets in environment variables, not code
- Easy to rotate keys without code changes
- Different secrets per environment

### 2. **Flexibility**
- Same codebase works in dev/staging/production
- Configuration via environment variables
- Easy deployment across different platforms

### 3. **Docker Best Practices**
- Efficient layer caching
- Optimized Python behavior
- Proper port exposure
- Clean, minimal images

### 4. **Development Workflow**
- Easy local development with `.env` file
- Container isolation
- Consistent environment across team

## Usage

1. Build the image:
   ```bash
   docker build -t django-app .
   ```

2. Run the container:
   ```bash
   docker run -p 8000:8000 django-app
   ```

3. Access the application at `http://localhost:8000`
