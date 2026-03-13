"""Tests for scripts/train_model.py – model training pipeline."""
import os
import sys
import importlib
import tempfile
import pytest
import joblib
import numpy as np


@pytest.fixture()
def run_training(tmp_path, monkeypatch):
    """Execute the training script inside a temp directory and return the
    path where the model was saved."""
    monkeypatch.chdir(tmp_path)
    # Remove cached module so the script body re-executes on each import.
    if "train_model" in sys.modules:
        del sys.modules["train_model"]
    # Add scripts/ to path so we can import the module.
    scripts_dir = os.path.join(
        os.path.dirname(__file__), "..", "scripts"
    )
    monkeypatch.syspath_prepend(scripts_dir)
    import train_model  # noqa: F401 – side-effect: runs training
    return tmp_path / "local_models" / "model.pkl"


class TestTrainModel:
    def test_output_directory_is_created(self, run_training):
        assert run_training.parent.is_dir()

    def test_model_file_is_created(self, run_training):
        assert run_training.exists()

    def test_saved_file_is_a_valid_sklearn_model(self, run_training):
        model = joblib.load(run_training)
        assert hasattr(model, "predict")

    def test_model_accepts_iris_shaped_input(self, run_training):
        """Model should accept a (1, 4) shaped input without raising."""
        model = joblib.load(run_training)
        sample = np.array([[5.1, 3.5, 1.4, 0.2]])
        prediction = model.predict(sample)
        assert len(prediction) == 1

    def test_model_prediction_is_valid_iris_class(self, run_training):
        model = joblib.load(run_training)
        sample = np.array([[5.1, 3.5, 1.4, 0.2]])
        prediction = model.predict(sample)
        assert int(prediction[0]) in (0, 1, 2)

    def test_model_is_reproducible(self, run_training):
        """Same input should always yield the same output (random_state=42)."""
        model = joblib.load(run_training)
        sample = np.array([[6.3, 3.3, 6.0, 2.5]])
        first = model.predict(sample)
        second = model.predict(sample)
        assert int(first[0]) == int(second[0])

    def test_model_has_correct_number_of_estimators(self, run_training):
        model = joblib.load(run_training)
        assert model.n_estimators == 10

    def test_model_trained_on_all_iris_classes(self, run_training):
        """Model should be able to predict all three Iris classes."""
        from sklearn.datasets import load_iris
        model = joblib.load(run_training)
        X, y = load_iris(return_X_y=True)
        predictions = set(model.predict(X).tolist())
        assert predictions == {0, 1, 2}
