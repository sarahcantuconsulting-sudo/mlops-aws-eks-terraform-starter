"""Shared pytest fixtures for the test suite."""
import os
import tempfile
import pytest
import joblib
from sklearn.datasets import load_iris
from sklearn.ensemble import RandomForestClassifier


@pytest.fixture(scope="session")
def trained_model_path():
    """Train a real model once per test session and return its path."""
    X, y = load_iris(return_X_y=True)
    model = RandomForestClassifier(n_estimators=5, random_state=42)
    model.fit(X, y)

    with tempfile.NamedTemporaryFile(suffix=".pkl", delete=False) as f:
        joblib.dump(model, f.name)
        yield f.name

    os.unlink(f.name)


@pytest.fixture()
def app_client(trained_model_path, monkeypatch):
    """Return a TestClient with a real model loaded."""
    monkeypatch.setenv("MODEL_PATH", trained_model_path)

    # Re-import app so it picks up the patched env var and reloads the model.
    import importlib
    import app.config as cfg
    importlib.reload(cfg)

    import app.main as main_module
    importlib.reload(main_module)

    from fastapi.testclient import TestClient
    return TestClient(main_module.app)


@pytest.fixture()
def app_client_no_model(tmp_path, monkeypatch):
    """Return a TestClient where the model file does not exist."""
    monkeypatch.setenv("MODEL_PATH", str(tmp_path / "missing_model.pkl"))

    import importlib
    import app.config as cfg
    importlib.reload(cfg)

    import app.main as main_module
    importlib.reload(main_module)

    from fastapi.testclient import TestClient
    return TestClient(main_module.app)
