## Dockerfile
FROM python:3.11-slim

# Create non-root user
RUN useradd -m appuser

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app

# Copy pre-trained model (generate first: python scripts/train_model.py)
COPY local_models/model.pkl /local_models/model.pkl

USER appuser

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]