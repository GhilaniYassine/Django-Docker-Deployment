# Django Docker Deployment Guide

A complete guide to containerizing Django applications with Docker and PostgreSQL using Docker Compose.

## Table of Contents
- [What is Docker Compose?](#what-is-docker-compose)
- [Project Structure](#project-structure)
- [Step-by-Step Setup](#step-by-step-setup)
- [Docker Compose Configuration](#docker-compose-configuration)
- [Environment Variables](#environment-variables)
- [Building and Running](#building-and-running)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## What is Docker Compose?

**Docker Compose** is a tool for defining and running multi-container Docker applications. Instead of managing multiple containers individually, Compose allows you to:

- **Define services** in a single YAML file
- **Manage dependencies** between containers
- **Configure networks** and volumes
- **Start/stop entire application stacks** with single commands
- **Share configurations** across development and production

### Why Use Docker Compose for Django?

1. **Multi-service applications**: Django apps typically need databases, caches, message queues
2. **Environment consistency**: Same setup across development, testing, and production
3. **Easy orchestration**: Automatic service discovery and dependency management
4. **Volume management**: Persistent data storage and file synchronization
5. **Network isolation**: Secure communication between services

## Project Structure

```
deploydockerdj/
├── compose.yml          # Docker Compose configuration
├── Dockerfile          # Multi-stage build configuration
├── .env               # Environment variables
├── requirements.txt   # Python dependencies
├── manage.py         # Django management script
├── dockerdj/         # Django project directory
│   ├── settings.py   # Django settings
│   ├── urls.py       # URL routing
│   └── wsgi.py       # WSGI application
├── hello/            # Django app
│   └── views.py      # Application views
└── templates/        # HTML templates
```

## Step-by-Step Setup

### Step 1: Create Environment Configuration

Create `.env` file with application settings:

```properties
# Django Settings
DJANGO_SECRET_KEY=your-secret-key-here
SECRET_KEY=your-secret-key-here
DEBUG=True
DJANGO_LOGLEVEL=info
DJANGO_ALLOWED_HOSTS=127.0.0.1,localhost,0.0.0.0,db

# Database Settings
DATABASE_ENGINE=postgresql
DATABASE_NAME=polls
DATABASE_USERNAME=myprojectuser
DATABASE_PASSWORD=password
DATABASE_HOST=db
DATABASE_PORT=5432
```

### Step 2: Configure Django Settings

Update `dockerdj/settings.py`:

```python
# Environment variable loading
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY") or os.environ.get("SECRET_KEY")
DEBUG = bool(os.environ.get("DEBUG", default=0))
ALLOWED_HOSTS = os.environ.get("DJANGO_ALLOWED_HOSTS","127.0.0.1").split(",")

# Database configuration
DATABASE_ENGINE = os.getenv('DATABASE_ENGINE', 'sqlite3')
if DATABASE_ENGINE == 'postgresql':
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.getenv('DATABASE_NAME'),
            'USER': os.getenv('DATABASE_USERNAME'),
            'PASSWORD': os.getenv('DATABASE_PASSWORD'),
            'HOST': os.getenv('DATABASE_HOST'),
            'PORT': os.getenv('DATABASE_PORT'),
        }
    }
```

### Step 3: Create Docker Compose Configuration

The `compose.yml` file defines our multi-container application:

```yaml
services:
  db:
    image: postgres:17
    environment:
      POSTGRES_DB: ${DATABASE_NAME}
      POSTGRES_USER: ${DATABASE_USERNAME}
      POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
    ports:
      - "5433:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    env_file:
      - .env
 
  django-web:
    build: .
    container_name: django-docker
    ports:
      - "8000:8000"
    depends_on:
      - db
    env_file:
      - .env
    command: >
      sh -c "
        while ! nc -z db 5432; do
          echo 'Waiting for database...'
          sleep 1
        done
        python manage.py migrate &&
        python manage.py collectstatic --noinput &&
        gunicorn --bind 0.0.0.0:8000 --workers 3 dockerdj.wsgi:application
      "

volumes:
  postgres_data:
```

## Docker Compose Configuration Explained

### Services Section

#### Database Service (`db`)
```yaml
db:
  image: postgres:17
```
**Purpose**: Defines the PostgreSQL database container
- `image: postgres:17`: Uses official PostgreSQL 17 image from Docker Hub
- **Alternative**: Could use `postgres:15` or `postgres:alpine` for smaller size

```yaml
environment:
  POSTGRES_DB: ${DATABASE_NAME}
  POSTGRES_USER: ${DATABASE_USERNAME}
  POSTGRES_PASSWORD: ${DATABASE_PASSWORD}
```
**Purpose**: Sets PostgreSQL environment variables
- `POSTGRES_DB`: Creates initial database
- `POSTGRES_USER`: Creates database user
- `POSTGRES_PASSWORD`: Sets user password
- **Variables**: Loaded from `.env` file using `${VARIABLE}` syntax

```yaml
ports:
  - "5433:5432"
```
**Purpose**: Port mapping for database access
- `5433`: Host port (your machine)
- `5432`: Container port (PostgreSQL default)
- **Why 5433?**: Avoids conflicts with local PostgreSQL installations

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data
```
**Purpose**: Persistent data storage
- `postgres_data`: Named volume for database files
- `/var/lib/postgresql/data`: PostgreSQL data directory
- **Benefit**: Data survives container restarts

```yaml
env_file:
  - .env
```
**Purpose**: Loads environment variables from file
- **Security**: Keeps secrets out of compose file
- **Flexibility**: Easy to change settings per environment

#### Django Web Service (`django-web`)
```yaml
django-web:
  build: .
```
**Purpose**: Builds Django container from Dockerfile
- `build: .`: Uses Dockerfile in current directory
- **Alternative**: Could use `image:` to pull pre-built image

```yaml
container_name: django-docker
```
**Purpose**: Sets custom container name
- **Benefit**: Easier to identify in `docker ps`
- **Optional**: Docker generates names if not specified

```yaml
ports:
  - "8000:8000"
```
**Purpose**: Exposes Django development server
- `8000`: Both host and container port
- **Access**: Application available at `http://localhost:8000`

```yaml
depends_on:
  - db
```
**Purpose**: Defines service dependencies
- **Behavior**: Starts `db` service before `django-web`
- **Note**: Doesn't wait for database to be ready, just started

```yaml
command: >
  sh -c "
    while ! nc -z db 5432; do
      echo 'Waiting for database...'
      sleep 1
    done
    python manage.py migrate &&
    python manage.py collectstatic --noinput &&
    gunicorn --bind 0.0.0.0:8000 --workers 3 dockerdj.wsgi:application
  "
```
**Purpose**: Custom startup command with database wait
- `while ! nc -z db 5432`: Waits for database to be ready
- `python manage.py migrate`: Applies database migrations
- `python manage.py collectstatic --noinput`: Collects static files
- `gunicorn --bind 0.0.0.0:8000 --workers 3`: Starts production WSGI server

### Volumes Section
```yaml
volumes:
  postgres_data:
```
**Purpose**: Defines named volumes
- **Persistence**: Data survives container deletion
- **Sharing**: Can be shared between containers
- **Management**: Docker manages storage location

## Environment Variables Explained

### Django Settings
- `DJANGO_SECRET_KEY`: Django's cryptographic signing key
- `SECRET_KEY`: Fallback for secret key
- `DEBUG`: Enables/disables debug mode
- `DJANGO_LOGLEVEL`: Sets logging verbosity
- `DJANGO_ALLOWED_HOSTS`: Comma-separated list of allowed hosts

### Database Settings
- `DATABASE_ENGINE`: Database backend (postgresql/sqlite3)
- `DATABASE_NAME`: Database name
- `DATABASE_USERNAME`: Database user
- `DATABASE_PASSWORD`: Database password
- `DATABASE_HOST`: Database host (service name in Docker)
- `DATABASE_PORT`: Database port

## Building and Running

### Development Setup
```bash
# Build and start all services
docker compose up --build

# Run in background
docker compose up -d --build

# View logs
docker compose logs -f

# Stop services
docker compose down
```

### Production Commands
```bash
# Build for production
docker compose -f compose.yml up --build -d

# Apply migrations
docker compose exec django-web python manage.py migrate

# Create superuser
docker compose exec django-web python manage.py createsuperuser

# Collect static files
docker compose exec django-web python manage.py collectstatic
```

### Useful Commands
```bash
# Enter Django container shell
docker compose exec django-web bash

# Enter PostgreSQL shell
docker compose exec db psql -U myprojectuser -d polls

# View container status
docker compose ps

# Remove everything (including volumes)
docker compose down -v
```

## Troubleshooting

### Common Issues

#### 1. Port Already in Use
**Error**: `bind: address already in use`
**Solution**: Change port mapping or stop conflicting service
```yaml
ports:
  - "5433:5432"  # Changed from 5432 to 5433
```

#### 2. Database Connection Failed
**Error**: `could not connect to server`
**Solutions**:
- Check database service is running: `docker compose ps`
- Verify environment variables in `.env`
- Ensure `DATABASE_HOST=db` (service name)

#### 3. Secret Key Not Set
**Error**: `The SECRET_KEY setting must not be empty`
**Solution**: Check `.env` file and variable names
```properties
DJANGO_SECRET_KEY=your-secret-key
SECRET_KEY=your-secret-key  # Fallback
```

#### 4. Permission Denied
**Error**: `Permission denied`
**Solution**: Check file ownership and Docker user
```dockerfile
USER appuser  # Non-root user in Dockerfile
```

### Debug Commands
```bash
# Check environment variables
docker compose exec django-web env

# Check Django configuration
docker compose exec django-web python manage.py check

# Test database connection
docker compose exec django-web python manage.py dbshell

# View detailed logs
docker compose logs django-web
```

## Best Practices

### Security
1. **Never commit secrets**: Use `.env` files, add to `.gitignore`
2. **Use non-root users**: Defined in Dockerfile
3. **Limit exposed ports**: Only expose necessary ports
4. **Regular updates**: Keep base images and dependencies updated

### Performance
1. **Multi-stage builds**: Smaller production images
2. **Layer caching**: Order Dockerfile commands for best caching
3. **Health checks**: Add health checks for better orchestration
4. **Resource limits**: Set memory and CPU limits

### Development
1. **Volume mounts**: Mount source code for live reloading
2. **Override files**: Use `compose.override.yml` for dev settings
3. **Environment separation**: Different `.env` files per environment
4. **Database initialization**: Use init scripts for test data

### Production
1. **External databases**: Use managed database services
2. **Secrets management**: Use Docker secrets or external systems
3. **Reverse proxy**: Use nginx for static files and load balancing
4. **Monitoring**: Add logging and monitoring containers

## Next Steps

1. **Add nginx**: Reverse proxy for static files and load balancing
2. **Add Redis**: Caching and session storage
3. **Add Celery**: Background task processing
4. **Add monitoring**: Prometheus, Grafana for observability
5. **CI/CD pipeline**: Automated testing and deployment

This setup provides a solid foundation for Django development and deployment with Docker Compose, ensuring consistency across environments and easy scalability.
