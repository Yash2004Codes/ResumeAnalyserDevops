"""Analysis history route."""

from fastapi import APIRouter

from app.db import list_analyses

router = APIRouter()


@router.get("/history")
def history(limit: int = 20):
    """Return the most recent analyses (empty when no database is configured)."""
    return list_analyses(min(max(limit, 1), 100))
