## scripts/train_model.py
import os
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier
import joblib

# Create output directory
os.makedirs("local_models", exist_ok=True)

# Train simple model
X, y = load_iris(return_X_y=True)
model = RandomForestClassifier(n_estimators=10, random_state=42)
model.fit(X, y)

# Save model
joblib.dump(model, "local_models/model.pkl")
print("✅ Model trained and saved to local_models/model.pkl")