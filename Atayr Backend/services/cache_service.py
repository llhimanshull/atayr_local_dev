import time
from typing import Any, Optional

class CacheService:
    """
    A lightweight, short-lived in-process cache.
    Designed so it can be swapped out for Redis later (e.g. using similar get/set/delete signatures).
    """
    _cache = {}

    @classmethod
    def get(cls, key: str) -> Optional[Any]:
        if key in cls._cache:
            val, expiry = cls._cache[key]
            if expiry > time.time():
                return val
            else:
                del cls._cache[key]
        return None

    @classmethod
    def set(cls, key: str, value: Any, ttl: int = 60):
        cls._cache[key] = (value, time.time() + ttl)

    @classmethod
    def delete(cls, key: str):
        if key in cls._cache:
            del cls._cache[key]

    @classmethod
    def clear_namespace(cls, namespace: str):
        """Clears all keys starting with a specific namespace."""
        keys_to_delete = [k for k in cls._cache.keys() if k.startswith(namespace)]
        for k in keys_to_delete:
            del cls._cache[k]
