## scripts/train_model.py
from sklearn.datasets import load_iris
from sklearn.linear_model import LogisticRegression
import joblib
import os

X, y = load_iris(return_X_y=True)
clf = LogisticRegression(max_iter=200)
clf.fit(X, y)

os.makedirs("local_models", exist_ok=True)
joblib.dump(clf, "local_models/model.pkl")
print("Model trained and saved to local_models/model.pkl")
