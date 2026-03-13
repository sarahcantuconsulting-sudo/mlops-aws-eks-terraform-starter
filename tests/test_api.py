"""Tests for app/main.py – FastAPI endpoints."""
import pytest


# ---------------------------------------------------------------------------
# /health
# ---------------------------------------------------------------------------

class TestHealthEndpoint:
    def test_health_returns_200(self, app_client):
        response = app_client.get("/health")
        assert response.status_code == 200

    def test_health_returns_ok_status(self, app_client):
        response = app_client.get("/health")
        assert response.json() == {"status": "ok"}

    def test_health_works_even_when_model_missing(self, app_client_no_model):
        """Health check must remain reachable regardless of model state."""
        response = app_client_no_model.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}


# ---------------------------------------------------------------------------
# /predict – happy path
# ---------------------------------------------------------------------------

class TestPredictEndpoint:
    # Iris feature vector for a setosa sample
    SETOSA_FEATURES = [5.1, 3.5, 1.4, 0.2]

    def test_predict_returns_200_for_valid_input(self, app_client):
        response = app_client.post("/predict", json={"features": self.SETOSA_FEATURES})
        assert response.status_code == 200

    def test_predict_response_has_prediction_key(self, app_client):
        response = app_client.post("/predict", json={"features": self.SETOSA_FEATURES})
        assert "prediction" in response.json()

    def test_predict_returns_integer_prediction(self, app_client):
        prediction = app_client.post(
            "/predict", json={"features": self.SETOSA_FEATURES}
        ).json()["prediction"]
        assert isinstance(prediction, int)

    def test_predict_iris_class_in_valid_range(self, app_client):
        """Iris has 3 classes (0, 1, 2); prediction must be one of them."""
        prediction = app_client.post(
            "/predict", json={"features": self.SETOSA_FEATURES}
        ).json()["prediction"]
        assert prediction in (0, 1, 2)

    def test_predict_setosa_sample(self, app_client):
        """Well-known setosa sample should be classified as class 0."""
        prediction = app_client.post(
            "/predict", json={"features": self.SETOSA_FEATURES}
        ).json()["prediction"]
        assert prediction == 0

    def test_predict_virginica_sample(self, app_client):
        """Well-known virginica sample should be classified as class 2."""
        prediction = app_client.post(
            "/predict", json={"features": [6.3, 3.3, 6.0, 2.5]}
        ).json()["prediction"]
        assert prediction == 2

    def test_predict_accepts_float_features(self, app_client):
        response = app_client.post(
            "/predict", json={"features": [5.0, 3.0, 1.5, 0.3]}
        )
        assert response.status_code == 200

    def test_predict_accepts_integer_features_coerced_to_float(self, app_client):
        """Pydantic should coerce ints to floats for list[float]."""
        response = app_client.post("/predict", json={"features": [5, 3, 1, 0]})
        assert response.status_code == 200


# ---------------------------------------------------------------------------
# /predict – error scenarios
# ---------------------------------------------------------------------------

class TestPredictErrors:
    def test_predict_500_when_model_not_loaded(self, app_client_no_model):
        response = app_client_no_model.post(
            "/predict", json={"features": [5.1, 3.5, 1.4, 0.2]}
        )
        assert response.status_code == 500

    def test_predict_500_detail_mentions_model(self, app_client_no_model):
        detail = app_client_no_model.post(
            "/predict", json={"features": [5.1, 3.5, 1.4, 0.2]}
        ).json()["detail"]
        assert "Model not loaded" in detail

    def test_predict_422_when_features_missing(self, app_client):
        """Pydantic validation error: 'features' field is required."""
        response = app_client.post("/predict", json={})
        assert response.status_code == 422

    def test_predict_422_when_features_is_not_a_list(self, app_client):
        response = app_client.post("/predict", json={"features": "bad"})
        assert response.status_code == 422

    def test_predict_422_when_features_contains_non_numeric(self, app_client):
        response = app_client.post("/predict", json={"features": ["a", "b", "c", "d"]})
        assert response.status_code == 422

    def test_predict_400_when_feature_count_wrong(self, app_client):
        """RandomForest trained on 4 features; sending 2 should cause a 400."""
        response = app_client.post("/predict", json={"features": [1.0, 2.0]})
        assert response.status_code == 400

    def test_predict_400_detail_mentions_prediction_failed(self, app_client):
        detail = app_client.post(
            "/predict", json={"features": [1.0, 2.0]}
        ).json()["detail"]
        assert "Prediction failed" in detail

    def test_predict_400_for_empty_features_list(self, app_client):
        response = app_client.post("/predict", json={"features": []})
        assert response.status_code == 400
