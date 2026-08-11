from __future__ import annotations

from collections import defaultdict, deque
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from math import ceil
from threading import Lock

Clock = Callable[[], datetime]


@dataclass(frozen=True, slots=True)
class RateLimitDecision:
    """Outcome of one rate-limit check."""

    allowed: bool
    retry_after_seconds: int | None = None


def retry_after_headers(
    decision: RateLimitDecision,
) -> dict[str, str] | None:
    """Return the standard retry header when the retry time is known."""

    if decision.retry_after_seconds is None:
        return None

    return {"Retry-After": str(decision.retry_after_seconds)}


class SlidingWindowRateLimiter:
    """Thread-safe in-process sliding-window rate limiter."""

    def __init__(
        self,
        *,
        limit: int,
        window: timedelta,
        clock: Clock | None = None,
    ) -> None:
        if limit <= 0:
            raise ValueError("Rate-limit window must allow at least one request.")

        if window <= timedelta(0):
            raise ValueError("Rate-limit window must be positive.")

        self._limit = limit
        self._window = window
        self._clock = clock or (lambda: datetime.now(UTC))
        self._lock = Lock()
        self._events: dict[str, deque[datetime]] = defaultdict(deque)

    def allow(self, key: str) -> RateLimitDecision:
        """Record one attempt and report whether it is permitted."""

        if not key:
            raise ValueError("Rate-limit key must not be empty.")

        now = self._clock()

        if now.tzinfo is None:
            raise ValueError("The rate-limit clock must return timezone-aware datetimes.")

        with self._lock:
            events = self._events[key]
            self._trim_expired_events(events, now)

            if len(events) >= self._limit:
                return RateLimitDecision(
                    allowed=False,
                    retry_after_seconds=self._retry_after_seconds(events, now),
                )

            events.append(now)
            return RateLimitDecision(allowed=True)

    def reset(self) -> None:
        """Clear all tracked attempts."""

        with self._lock:
            self._events.clear()

    def _trim_expired_events(
        self,
        events: deque[datetime],
        now: datetime,
    ) -> None:
        window_start = now - self._window

        while events and events[0] <= window_start:
            events.popleft()

    def _retry_after_seconds(
        self,
        events: deque[datetime],
        now: datetime,
    ) -> int:
        oldest_event = events[0]
        retry_after = oldest_event + self._window - now

        return max(1, ceil(retry_after.total_seconds()))
