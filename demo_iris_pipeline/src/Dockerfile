FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .

# Install dependencies directly
RUN pip install -r requirements.txt

# Copy application files
COPY serve.py .
COPY model/ /model/

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV GIT_PYTHON_REFRESH=quiet

# Expose the port the app runs on
EXPOSE 9000

# Run the server
CMD ["python", "serve.py"]