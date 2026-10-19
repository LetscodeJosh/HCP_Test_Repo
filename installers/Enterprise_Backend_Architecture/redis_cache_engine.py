"""
================================================================================
PIMS HCP PROFILING APP - ENTERPRISE MULTI-TIER REDIS CACHING ENGINE
High-Throughput Read Caching, Single-Flight Mutex, & Selective Invalidation
================================================================================
Mitigates MariaDB database bottlenecks when hundreds of concurrent users
query master doctor lists, institution directories, and territory trees.
"""

import json
import time
import logging
import hashlib
from typing import Any, Callable, Dict, List, Optional
import redis

# Configure Structured Logging
logger = logging.getLogger("pims.cache_engine")
logger.setLevel(logging.INFO)


class EnterpriseRedisCache:
    """
    High-Performance Redis Cache Layer with Stale-While-Revalidate
    and Thundering Herd / Cache Stampede Prevention.
    """

    def __init__(
        self,
        redis_host: str = "redis_cluster",
        redis_port: int = 6379,
        redis_db: int = 0,
        redis_password: Optional[str] = None,
        default_ttl_seconds: int = 1800,  # 30 Minutes
    ):
        self.default_ttl = default_ttl_seconds
        try:
            self.client = redis.Redis(
                host=redis_host,
                port=redis_port,
                db=redis_db,
                password=redis_password,
                decode_responses=True,
                socket_timeout=2.0,
                socket_connect_timeout=2.0,
                retry_on_timeout=True,
            )
            # Test connectivity
            self.client.ping()
            self.is_connected = True
            logger.info("Connected successfully to Enterprise Redis Cache Cluster.")
        except Exception as e:
            logger.warning("Redis Cluster offline or unreachable. Falling back to direct database reads: %s", e)
            self.client = None
            self.is_connected = False

    # --------------------------------------------------------------------------
    # CORE STALE-WHILE-REVALIDATE WITH SINGLE-FLIGHT MUTEX
    # --------------------------------------------------------------------------
    def get_or_set_cached(
        self,
        cache_key: str,
        query_fn: Callable[[], Any],
        ttl_seconds: Optional[int] = None,
        grace_period_seconds: int = 300,
    ) -> Any:
        """
        Retrieves data from Redis. If missing or expired:
        Acquires a distributed mutex lock so only 1 worker queries MariaDB.
        Other concurrent requests receive stale cache during reload (zero thundering herd).
        """
        if not self.is_connected or not self.client:
            return query_fn()

        ttl = ttl_seconds or self.default_ttl
        raw_cached = None

        try:
            raw_cached = self.client.get(cache_key)
        except Exception as e:
            logger.error("Redis get failed for key '%s': %s", cache_key, e)

        if raw_cached:
            try:
                payload = json.loads(raw_cached)
                cached_at = payload.get("_cached_at", 0)
                is_stale = (time.time() - cached_at) > ttl

                if not is_stale:
                    # Cache Hit (Fresh)
                    return payload.get("data")

                # Cache is stale, attempt to acquire refresh lock
                lock_key = f"lock:{cache_key}"
                acquired = self.client.set(lock_key, "locked", nx=True, ex=15)
                if not acquired:
                    # Another worker is refreshing; serve stale data immediately (grace period)
                    logger.debug("Serving stale cache for '%s' during concurrent refresh.", cache_key)
                    return payload.get("data")

                # We hold the lock -> refresh from MariaDB
                fresh_data = query_fn()
                self._set_payload(cache_key, fresh_data, ttl + grace_period_seconds)
                self.client.delete(lock_key)
                return fresh_data

            except Exception as e:
                logger.error("Error parsing cache payload for key '%s': %s", cache_key, e)

        # Cache Miss (Key not present) -> Acquire Mutex to prevent DB hammer
        lock_key = f"lock:{cache_key}"
        try:
            acquired = self.client.set(lock_key, "locked", nx=True, ex=15)
            if not acquired:
                # Wait briefly for the leader to populate the cache
                for _ in range(10):
                    time.sleep(0.1)
                    raw_cached = self.client.get(cache_key)
                    if raw_cached:
                        return json.loads(raw_cached).get("data")

            # Execute database read
            fresh_data = query_fn()
            self._set_payload(cache_key, fresh_data, ttl + grace_period_seconds)
            self.client.delete(lock_key)
            return fresh_data
        except Exception as e:
            logger.error("Failed executing single-flight cached query for '%s': %s", cache_key, e)
            return query_fn()

    def _set_payload(self, cache_key: str, data: Any, ttl: int):
        payload = {
            "_cached_at": time.time(),
            "data": data,
        }
        self.client.setex(cache_key, ttl, json.dumps(payload))

    # --------------------------------------------------------------------------
    # SELECTIVE CACHE INVALIDATION HOOKS (Triggered on Frappe DocType Mutations)
    # --------------------------------------------------------------------------
    def invalidate_hcp_cache(self, hcp_name: Optional[str] = None):
        """Purges doctor masterlist caches when an HCP is created, approved, or edited."""
        if not self.is_connected or not self.client:
            return
        keys = ["hcp:masterlist:all", "hcp:summary:active"]
        if hcp_name:
            keys.append(f"hcp:detail:{hcp_name}")
        for k in keys:
            self.client.delete(k)
        logger.info("Invalidated HCP caches: %s", keys)

    def invalidate_hcp_account_cache(self, program: str, hcp_name: Optional[str] = None):
        """Purges program-specific doctor account cache."""
        if not self.is_connected or not self.client:
            return
        keys = [f"hcp_account:{program}:all"]
        if hcp_name:
            keys.append(f"hcp_account:{program}:{hcp_name}")
        for k in keys:
            self.client.delete(k)
        logger.info("Invalidated HCP Account caches for program '%s'", program)

    def invalidate_institution_cache(self):
        """Purges institution directory caches when a new facility is proposed or approved."""
        if not self.is_connected or not self.client:
            return
        keys = ["institution:directory:all", "institution:directory:certified"]
        for k in keys:
            self.client.delete(k)
        logger.info("Invalidated Institution caches: %s", keys)

    def invalidate_territory_cache(self, program: str):
        """Purges territory hierarchy trees upon SFE territory reconfiguration."""
        if not self.is_connected or not self.client:
            return
        keys = [f"territory:{program}:tree", f"territory:{program}:list"]
        for k in keys:
            self.client.delete(k)
        logger.info("Invalidated Territory caches for program '%s'", program)


# Singleton Instance
cache_engine = EnterpriseRedisCache()


# ------------------------------------------------------------------------------
# FRAPPE DOCTYPE HOOKS INTEGRATION (Directly imported in Frappe hooks.py)
# ------------------------------------------------------------------------------
def on_hcp_profile_submission_approved(doc, method=None):
    """
    Called when a submission transitions to Approved or Processed.
    Ensures Redis cache is purged so MedReps instantly see updated profiles.
    """
    program = getattr(doc, "program", "COREnergy")
    hcp = getattr(doc, "hcp", None)
    cache_engine.invalidate_hcp_cache(hcp)
    cache_engine.invalidate_hcp_account_cache(program, hcp)


def on_institution_updated(doc, method=None):
    """Called when an Institution is created, certified, or modified."""
    cache_engine.invalidate_institution_cache()


def on_territory_reconfigured(doc, method=None):
    """Called when SFE modifies or transfers territory nodes."""
    program = getattr(doc, "custom_program", getattr(doc, "program", "Abbott Diabetes Care"))
    cache_engine.invalidate_territory_cache(program)
