## app/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import joblib
import numpy as np
from app.config import MODEL_PATH

app = FastAPI()

# Load model
try:
    model = joblib.load(MODEL_PATH)
except Exception as e:
    model = None
    print(f"Model failed to load from {MODEL_PATH}: {e}")

class PredictionRequest(BaseModel):
    features: list[float]

class PredictionResponse(BaseModel):
    prediction: int

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/predict", response_model=PredictionResponse)
def predict(req: PredictionRequest):
    if model is None:
        raise HTTPException(status_code=500, detail="Model not loaded")
    try:
        prediction = model.predict([req.features])
        return {"prediction": int(prediction[0])}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Prediction failed: {e}")