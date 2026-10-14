"""S3 storage for uploaded resumes (disabled when S3_BUCKET is unset)."""

import logging
import os
import uuid

logger = logging.getLogger(__name__)


def upload_resume(file_bytes: bytes, file_hash: str) -> str | None:
    bucket = os.getenv("S3_BUCKET")
    if not bucket:
        return None
    key = f"resumes/{file_hash[:16]}-{uuid.uuid4().hex[:8]}.pdf"
    try:
        import boto3

        boto3.client("s3").put_object(
            Bucket=bucket,
            Key=key,
            Body=file_bytes,
            ContentType="application/pdf",
            ServerSideEncryption="AES256",
        )
        return key
    except Exception:
        logger.exception("Failed to upload resume to S3")
        return None
