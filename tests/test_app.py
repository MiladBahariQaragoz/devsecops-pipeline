"""Smoke tests for the Flask app.

Uses Flask's built-in test client — no Docker required.
"""

import os
import uuid

import pytest

# Set the required env var BEFORE importing create_app so the factory does not raise.
os.environ.setdefault("FLASK_SECRET_KEY", "test-secret-key-not-for-production")

from app import create_app  # noqa: E402 — import after env var is set


@pytest.fixture()
def client():
    # Each test gets a unique in-memory DB name so data cannot leak between tests.
    # file:<name>?mode=memory&cache=shared keeps all connections within one test
    # on the same in-memory DB while preventing any other test from seeing that data.
    db_uri = f"file:test_{uuid.uuid4().hex}?mode=memory&cache=shared"
    app = create_app(test_config={"DATABASE": db_uri, "TESTING": True})
    with app.test_client() as c:
        yield c


def test_health_returns_200(client):
    """GET /health must return 200 and {"status": "ok"}."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data == {"status": "ok"}


def test_items_returns_200(client):
    """GET /items must return 200 with an items list."""
    response = client.get("/items")
    assert response.status_code == 200
    data = response.get_json()
    assert "items" in data
    assert isinstance(data["items"], list)


def test_create_item_returns_201(client):
    """POST /items with a valid name must return 201 and the new item."""
    response = client.post("/items", json={"name": "widget"})
    assert response.status_code == 201
    data = response.get_json()
    assert data["name"] == "widget"
    assert "id" in data


def test_create_item_missing_name_returns_400(client):
    """POST /items with no name must return 400."""
    response = client.post("/items", json={})
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data


def test_create_item_empty_name_returns_400(client):
    """POST /items with an empty name must return 400."""
    response = client.post("/items", json={"name": "   "})
    assert response.status_code == 400


def test_create_item_integer_name_returns_400(client):
    """POST /items with an integer name must return 400 (not str(42) == '42')."""
    response = client.post("/items", json={"name": 42})
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data


def test_create_item_null_name_returns_400(client):
    """POST /items with a JSON null name must return 400 (not str(None) == 'None')."""
    response = client.post("/items", json={"name": None})
    assert response.status_code == 400
    data = response.get_json()
    assert "error" in data
