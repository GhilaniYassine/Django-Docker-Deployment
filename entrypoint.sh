#!/bin/bash

# Exit on any error
set -e

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Running database migrations..."
python manage.py migrate

echo "Starting Django server..."
if [ "$DJANGO_ENV" = "production" ]; then
    gunicorn --bind 0.0.0.0:8000 --workers 3 dockerdj.wsgi:application
else
    python manage.py runserver 0.0.0.0:8000
fi
