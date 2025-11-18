## Dockerfile - Multi-stage build with model training
FROM python:3.11-slim AS builder

# Install dependencies for training
WORKDIR /build
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Train model during build
COPY scripts/train_model.py ./scripts/
RUN python scripts/train_model.py

# Final runtime image
FROM python:3.11-slim

# Create non-root user
RUN useradd -m appuser

WORKDIR /app

# Install only runtime dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ./app

# Copy trained model from builder stage
COPY --from=builder /build/local_models/model.pkl /models/model.pkl

USER appuser

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]