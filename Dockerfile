# ----------------------
# Base Image
# ----------------------
FROM python:3.11-slim

# ----------------------
# Set working directory
# ----------------------
WORKDIR /app

# ----------------------
# Install dependencies
# ----------------------
# Install gcc & build-essential in case some packages need compilation
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ----------------------
# Copy app source
# ----------------------
COPY . .

# ----------------------
# Environment
# ----------------------
ENV PYTHONUNBUFFERED=1 \
    FLASK_APP=app.py

# ----------------------
# Expose port
# ----------------------
EXPOSE 5000

# ----------------------
# Entrypoint
# ----------------------
CMD ["python", "app.py"]
