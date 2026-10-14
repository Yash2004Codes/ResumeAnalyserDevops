"""Resume analysis route."""

import hashlib
import logging
from fastapi import APIRouter, File, HTTPException, Request, UploadFile

from app.cache import get_cached, is_rate_limited, set_cached
from app.db import save_analysis
from app.storage import upload_resume
from app.utils.pdf_parser import extract_text
from app.services.groq_service import analyze_resume

logger = logging.getLogger(__name__)

router = APIRouter()


def _client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


@router.post("/analyze")
async def analyze(request: Request, file: UploadFile = File(...)):
    """
    Analyze an uploaded PDF resume.

    Accepts a PDF file, extracts text, sends it to Groq AI for analysis,
    and returns extracted skills, ATS score, and improvement suggestions.
    Results are cached in Redis by file hash, stored in S3, and recorded in Postgres
    when those backends are configured.
    """
    if is_rate_limited(_client_ip(request)):
        raise HTTPException(
            status_code=429, detail="Too many requests. Please try again in a minute."
        )

    # Validate file type
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(
            status_code=400,
            detail="Only PDF files are accepted. Please upload a .pdf file.",
        )

    if file.content_type and file.content_type != "application/pdf":
        raise HTTPException(
            status_code=400,
            detail="Invalid content type. Expected application/pdf.",
        )

    try:
        # Read file bytes
        file_bytes = await file.read()

        if len(file_bytes) == 0:
            raise HTTPException(
                status_code=400,
                detail="The uploaded file is empty.",
            )

        file_hash = hashlib.sha256(file_bytes).hexdigest()
        cached = get_cached(file_hash)
        if cached is not None:
            logger.info("Cache hit for %s", file_hash[:12])
            return cached

        # Extract text from PDF
        resume_text = extract_text(file_bytes)
        logger.info(
            "Extracted %d characters from %s", len(resume_text), file.filename
        )

        # Analyze with Groq AI
        result = analyze_resume(resume_text)
        logger.info(
            "Analysis complete for %s — ATS score: %d",
            file.filename,
            result["ats_score"],
        )

        s3_key = upload_resume(file_bytes, file_hash)
        save_analysis(file_hash, file.filename, result, s3_key)
        set_cached(file_hash, result)

        return result

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        logger.error("Analysis failed: %s", str(e))
        raise HTTPException(status_code=502, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Unexpected error during analysis")
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred while analyzing the resume.",
        )
