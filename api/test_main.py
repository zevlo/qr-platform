from unittest.mock import patch

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_generate_qr():
    with patch("main.s3") as mock_s3:
        mock_s3.put_object.return_value = {}
        response = client.post("/generate-qr/?url=http://example.com")
        assert response.status_code == 200
        assert "qr_code_url" in response.json()
        mock_s3.put_object.assert_called_once()


def test_generate_qr_missing_url():
    response = client.post("/generate-qr/")
    assert response.status_code == 422
