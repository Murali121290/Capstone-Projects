# ----------------------
# Base Image
# ----------------------
FROM python:3.11-slim

# ----------------------
# Set working directory
# ----------------------
WORKDIR /app

# ----------------------
# Install system dependencies
# ----------------------
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# ----------------------
# Install Python dependencies
# ----------------------
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir gunicorn

# ----------------------
# Copy app source
# ----------------------
COPY . .

# ----------------------
# Create non-root user
# ----------------------
RUN useradd -m appuser
USER appuser

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
# Entrypoint (Gunicorn)
# ----------------------
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app"]
