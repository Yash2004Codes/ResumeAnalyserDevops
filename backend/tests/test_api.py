import io

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.routes import analyze as analyze_module

client = TestClient(app)

FAKE_RESULT = {"ats_score": 80, "skills": ["python"], "suggestions": []}


def _pdf():
    return {"file": ("cv.pdf", io.BytesIO(b"%PDF-1.4 fake"), "application/pdf")}


def test_health():
    assert client.get("/health").json() == {"status": "healthy"}


def test_history_empty_without_database():
    assert client.get("/history").json() == []


def test_rejects_non_pdf():
    r = client.post("/analyze", files={"file": ("cv.txt", io.BytesIO(b"x"), "text/plain")})
    assert r.status_code == 400


def test_rejects_empty_file():
    r = client.post("/analyze", files={"file": ("cv.pdf", io.BytesIO(b""), "application/pdf")})
    assert r.status_code == 400


def test_analyze_success(monkeypatch):
    monkeypatch.setattr(analyze_module, "extract_text", lambda b: "resume text")
    monkeypatch.setattr(analyze_module, "analyze_resume", lambda t: FAKE_RESULT)
    r = client.post("/analyze", files=_pdf())
    assert r.status_code == 200
    assert r.json()["ats_score"] == 80


def test_cache_hit_skips_groq(monkeypatch):
    monkeypatch.setattr(analyze_module, "get_cached", lambda h: FAKE_RESULT)

    def boom(_):
        raise AssertionError("Groq must not be called on a cache hit")

    monkeypatch.setattr(analyze_module, "analyze_resume", boom)
    assert client.post("/analyze", files=_pdf()).json() == FAKE_RESULT


def test_rate_limited(monkeypatch):
    monkeypatch.setattr(analyze_module, "is_rate_limited", lambda ip: True)
    assert client.post("/analyze", files=_pdf()).status_code == 429
