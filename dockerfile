# Use the official Python runtime image
FROM python:3.13  
 
# Create the app directory
RUN mkdir /app
 
# Set the working directory inside the container
WORKDIR /app
 
# Set environment variables 
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1 
 
# Upgrade pip
RUN pip install --upgrade pip 
 
# Copy requirements first for better caching
COPY requirements.txt /app/
 
# Install dependencies 
RUN pip install --no-cache-dir -r requirements.txt
 
# Copy the entire Django project to the container
COPY . /app/

# Copy and make entrypoint script executable
COPY entrypoint.sh /app/
RUN chmod +x /app/entrypoint.sh
 
# Expose the Django port
EXPOSE 8000
 
# Use the entrypoint script
CMD ["./entrypoint.sh"]
