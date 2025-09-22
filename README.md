# Django Docker Deployment with Static Files

This project demonstrates how to containerize a Django application using Docker with proper static file handling, database migrations, and production-ready configuration.

## 📁 Project Structure

```
deploydockerdj/
├── dockerfile              # Multi-stage Docker build configuration
├── entrypoint.sh           # Container startup script
├── requirements.txt        # Python dependencies
├── .env                   # Environment variables (development)
├── manage.py              # Django management script
├── dockerdj/              # Main Django project
│   ├── settings.py        # Django configuration
│   ├── urls.py           # URL routing
│   ├── wsgi.py           # WSGI application
│   └── static/           # Project static files
│       └── css/
│           └── index.css  # Stylesheet
├── hello/                 # Django app
│   ├── views.py          # View functions
│   └── templates/        # HTML templates
│       └── index.html    # Main template
└── staticfiles/          # Collected static files (created by Django)
```

## 🐳 Dockerfile Explanation

Our Dockerfile uses a **multi-stage build** for optimization and security:

### Stage 1: Builder Stage
```dockerfile
FROM python:3.13-slim AS builder
```
**Purpose**: Creates a temporary build environment
- **Why python:3.13-slim**: Smaller base image (~45MB vs ~380MB for full python:3.13)
- **AS builder**: Names this stage for later reference
- **Benefits**: Reduces final image size by excluding build tools

```dockerfile
RUN mkdir /app
WORKDIR /app
```
**Purpose**: Sets up the working directory
- **mkdir /app**: Creates application directory inside container
- **WORKDIR /app**: Sets current directory for subsequent commands
- **Why /app**: Common convention, easy to remember and reference

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
```
**Purpose**: Optimizes Python for containerized environments
- **PYTHONDONTWRITEBYTECODE=1**: Prevents Python from creating `.pyc` bytecode files
  - **Why**: Saves space and avoids permission issues in containers
  - **Benefit**: Faster container startup, smaller image size
- **PYTHONUNBUFFERED=1**: Forces Python output to go directly to terminal
  - **Why**: Essential for seeing logs in Docker containers
  - **Benefit**: Real-time log output, better debugging experience

```dockerfile
RUN pip install --upgrade pip
```
**Purpose**: Ensures we have the latest pip version
- **Why upgrade**: Latest pip has security fixes and performance improvements
- **Alternative**: Could pin specific version like `pip==23.3.1` for reproducibility

```dockerfile
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt
```
**Purpose**: Installs Python dependencies efficiently
- **Why copy requirements.txt first**: Docker layer caching optimization
  - If code changes but requirements don't, this layer is reused
  - Speeds up rebuilds significantly
- **--no-cache-dir**: Prevents pip from storing download cache

### Stage 2: Production Stage
```dockerfile
FROM python:3.13-slim
```
**Purpose**: Creates clean production environment
- **Why fresh image**: Excludes build tools and temporary files from builder stage
- **Result**: Smaller, more secure final image

```dockerfile
RUN useradd -m -r appuser && \
   mkdir /app && \
   mkdir /app/staticfiles && \
   chown -R appuser /app
```
**Purpose**: Creates secure runtime environment
- **useradd -m -r appuser**: Creates system user with home directory
  - **-m**: Creates home directory
  - **-r**: System user 
- **mkdir /app/staticfiles**: Pre-creates directory for collected static files
  - **Why**: Ensures directory exists with correct permissions
- **chown -R appuser /app**: Changes ownership to app user

```dockerfile
COPY --from=builder /usr/local/lib/python3.13/site-packages/ /usr/local/lib/python3.13/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
```
**Purpose**: Copies installed Python packages from builder stage
- **--from=builder**: References the builder stage
- **Why copy packages**: Gets all installed dependencies without pip cache
- **Result**: Clean production environment with only necessary files

```dockerfile
COPY --chown=appuser:appuser . .
```
**Purpose**: Copies entire application code
- **--chown appuser:appuser**: Ensures files are owned by app user
- **. .**: Copies from current directory (host) to current directory (container)
- **Why after pip install**: Better Docker layer caching

```dockerfile
COPY --chown=appuser:appuser entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh
```
**Purpose**: Sets up startup script
- **Why separate copy**: Ensures entrypoint script has correct permissions
- **chmod +x**: Makes script executable
- **Security**: Owned by appuser, not root

```dockerfile
USER appuser
```
**Purpose**: Switches to non-root user
- **Security**: Prevents privilege escalation attacks
- **Best Practice**: Containers should never run as root in production

```dockerfile
EXPOSE 8000
```
**Purpose**: Documents which port the application uses
- **Note**: Doesn't actually publish the port (done with `docker run -p`)
- **Why 8000**: Django's default development server port
- **Documentation**: Helps other developers understand the application

```dockerfile
CMD ["./entrypoint.sh"]
```
**Purpose**: Defines default command when container starts
- **Why entrypoint script**: Allows complex startup logic
- **Alternative**: Could directly run Django, but loses automation benefits

## 🚀 Entrypoint Script Explanation

The `entrypoint.sh` script handles application initialization:


```bash
set -e
```
**Purpose**: Exit immediately if any command fails
- **Why**: Prevents container from starting in broken state
- **Benefit**: Fail-fast behavior, easier debugging

```bash
echo "Collecting static files..."
python manage.py collectstatic --noinput
```
**Purpose**: Gathers all static files into one directory
- **collectstatic**: Django command that copies static files from apps
- **--noinput**: Runs without prompting for user input
- **Why needed**: 
  - Production deployment requirement
  - WhiteNoise needs files in STATIC_ROOT
  - Combines files from multiple Django apps

```bash
echo "Running database migrations..."
python manage.py migrate
```
**Purpose**: Applies database schema changes
- **migrate**: Updates database structure to match Django models
- **Why automated**: Ensures database is always up-to-date
- **Safety**: Migrations are idempotent (safe to run multiple times)

```bash
if [ "$DJANGO_ENV" = "production" ]; then
    gunicorn --bind 0.0.0.0:8000 --workers 3 dockerdj.wsgi:application
else
    python manage.py runserver 0.0.0.0:8000
fi
```
**Purpose**: Starts appropriate server based on environment
- **Environment check**: Different servers for different environments
- **Production path**: 
  - **gunicorn**: Production WSGI server
  - **--bind 0.0.0.0:8000**: Listen on all interfaces, port 8000
  - **--workers 3**: Three worker processes for handling requests
  - **dockerdj.wsgi:application**: Points to Django WSGI application
- **Development path**:
  - **runserver**: Django's development server
  - **0.0.0.0:8000**: Listen on all interfaces (required for Docker)

## ⚙️ Django Configuration Changes

### Static Files Configuration
```python
STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
STATICFILES_DIRS = [
    os.path.join(BASE_DIR, 'dockerdj/static'),
]
```
**Purpose**: Configures static file handling
- **STATIC_URL**: URL prefix for static files in templates
- **STATIC_ROOT**: Where `collectstatic` puts files (for production)
- **STATICFILES_DIRS**: Additional directories to search for static files

### WhiteNoise Integration
```python
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # Added for static files
    # ...existing middleware...
]

STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
```
**Purpose**: Serves static files without separate web server
- **WhiteNoise**: Python package for serving static files
- **Why needed**: Django doesn't serve static files in production
- **Compression**: Automatically compresses files for faster delivery
- **Manifest**: Creates fingerprinted filenames for cache busting

### Environment Variable Configuration
```python
from dotenv import load_dotenv
load_dotenv()

SECRET_KEY = os.environ.get("SECRET_KEY", 'django-insecure-fallback-key-change-in-production')
DEBUG = os.getenv("DEBUG", "0").lower() in ("1", "true", "yes", "on")
ALLOWED_HOSTS = (
    os.getenv("DJANGO_ALLOWED_HOSTS")
    or os.getenv("ALLOWED_HOSTS")
    or "127.0.0.1"
).split(",")
```
**Purpose**: Configures Django from environment variables
- **Security**: Keeps secrets out of code
- **Flexibility**: Different configurations for different environments
- **12-Factor App**: Follows modern application configuration practices

## 📦 Dependencies Explanation

### Core Dependencies
- **Django==5.1.3**: Web framework
- **gunicorn==23.0.0**: Production WSGI server
- **whitenoise==6.6.0**: Static file serving
- **python-dotenv==1.0.1**: Environment variable loading


## 🛠️ Build and Run Instructions

### 1. Build the Docker Image
```bash
docker build -t django-docker-app .
```
**What happens**:
1. Downloads Python 3.13-slim base image
2. Creates builder stage and installs dependencies
3. Creates production stage with minimal footprint
4. Copies application code and sets up user permissions
5. Configures entrypoint script

### 2. Run the Container
```bash
# Development mode
docker run -p 8000:8000 django-docker-app

# Production mode
docker run -p 8000:8000 -e DJANGO_ENV=production django-docker-app
