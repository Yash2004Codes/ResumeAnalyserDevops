"""Redis result cache and rate limiting. Fails open if Redis is unset or down."""

import json
import logging
import os

import redis

logger = logging.getLogger(__name__)

CACHE_TTL_SECONDS = 24 * 3600
RATE_LIMIT_PER_MINUTE = int(os.getenv("RATE_LIMIT_PER_MINUTE", "10"))

_client = None


def _get_client():
    global _client
    url = os.getenv("REDIS_URL")
    if not url:
        return None
    if _client is None:
        _client = redis.Redis.from_url(url, socket_timeout=1, socket_connect_timeout=1)
    return _client


def get_cached(file_hash: str) -> dict | None:
    client = _get_client()
    if client is None:
        return None
    try:
        raw = client.get(f"analysis:{file_hash}")
        return json.loads(raw) if raw else None
    except Exception:
        logger.warning("Redis cache read failed", exc_info=True)
        return None


def set_cached(file_hash: str, result: dict) -> None:
    client = _get_client()
    if client is None:
        return
    try:
        client.setex(f"analysis:{file_hash}", CACHE_TTL_SECONDS, json.dumps(result))
    except Exception:
        logger.warning("Redis cache write failed", exc_info=True)


def is_rate_limited(client_ip: str) -> bool:
    """Fixed-window limit: RATE_LIMIT_PER_MINUTE requests per IP per minute."""
    client = _get_client()
    if client is None:
        return False
    try:
        key = f"ratelimit:{client_ip}"
        count = client.incr(key)
        if count == 1:
            client.expire(key, 60)
        return count > RATE_LIMIT_PER_MINUTE
    except Exception:
        logger.warning("Redis rate-limit check failed", exc_info=True)
        return False
