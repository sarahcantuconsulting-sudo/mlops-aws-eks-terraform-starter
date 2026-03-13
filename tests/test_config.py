"""Tests for app/config.py."""
import importlib
import os


def test_model_path_default(monkeypatch):
    """Without an env var the default path should be used."""
    monkeypatch.delenv("MODEL_PATH", raising=False)
    import app.config as cfg
    importlib.reload(cfg)
    assert cfg.MODEL_PATH == "/local_models/model.pkl"


def test_model_path_from_env(monkeypatch):
    """MODEL_PATH env var should override the default."""
    monkeypatch.setenv("MODEL_PATH", "/custom/path/model.pkl")
    import app.config as cfg
    importlib.reload(cfg)
    assert cfg.MODEL_PATH == "/custom/path/model.pkl"


def test_model_path_is_string(monkeypatch):
    monkeypatch.delenv("MODEL_PATH", raising=False)
    import app.config as cfg
    importlib.reload(cfg)
    assert isinstance(cfg.MODEL_PATH, str)
