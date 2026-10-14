"""PostgreSQL persistence for analysis history (disabled when DATABASE_URL is unset)."""

import logging
import os
from datetime import datetime, timezone

from sqlalchemy import JSON, DateTime, Integer, String, create_engine, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, sessionmaker

logger = logging.getLogger(__name__)


class Base(DeclarativeBase):
    pass


class Analysis(Base):
    __tablename__ = "analyses"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    file_hash: Mapped[str] = mapped_column(String(64), index=True)
    filename: Mapped[str] = mapped_column(String(255))
    ats_score: Mapped[int] = mapped_column(Integer)
    result: Mapped[dict] = mapped_column(JSON)
    s3_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )


_session_factory = None


def _get_session_factory():
    global _session_factory
    url = os.getenv("DATABASE_URL")
    if not url:
        return None
    if _session_factory is None:
        engine = create_engine(url, pool_pre_ping=True, pool_size=3, max_overflow=2)
        _session_factory = sessionmaker(engine, expire_on_commit=False)
    return _session_factory


def save_analysis(file_hash: str, filename: str, result: dict, s3_key: str | None) -> None:
    factory = _get_session_factory()
    if factory is None:
        return
    try:
        with factory() as session:
            session.add(
                Analysis(
                    file_hash=file_hash,
                    filename=filename[:255],
                    ats_score=int(result.get("ats_score", 0)),
                    result=result,
                    s3_key=s3_key,
                )
            )
            session.commit()
    except Exception:
        logger.exception("Failed to save analysis history")


def list_analyses(limit: int = 20) -> list[dict]:
    factory = _get_session_factory()
    if factory is None:
        return []
    with factory() as session:
        rows = session.scalars(
            select(Analysis).order_by(Analysis.created_at.desc()).limit(limit)
        ).all()
        return [
            {
                "id": r.id,
                "filename": r.filename,
                "ats_score": r.ats_score,
                "created_at": r.created_at.isoformat(),
            }
            for r in rows
        ]
