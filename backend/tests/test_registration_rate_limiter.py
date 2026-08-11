from datetime import UTC, datetime, timedelta

from kalonet_backend.api.rate_limit import SlidingWindowRateLimiter


class SequenceClock:
    """Return a fixed series of timestamps for deterministic tests."""

    def __init__(self, moments: list[datetime]) -> None:
        self._moments = iter(moments)

    def __call__(self) -> datetime:
        return next(self._moments)


def test_rate_limiter_blocks_after_five_attempts() -> None:
    start = datetime(2026, 8, 9, 12, 0, tzinfo=UTC)
    clock = SequenceClock([start] * 6)

    limiter = SlidingWindowRateLimiter(
        limit=5,
        window=timedelta(hours=1),
        clock=clock,
    )

    for _ in range(5):
        decision = limiter.allow("127.0.0.1")
        assert decision.allowed is True
        assert decision.retry_after_seconds is None

    decision = limiter.allow("127.0.0.1")

    assert decision.allowed is False
    assert decision.retry_after_seconds == 3600


def test_rate_limiter_resets_and_expires_old_attempts() -> None:
    start = datetime(2026, 8, 9, 12, 0, tzinfo=UTC)
    clock = SequenceClock(
        [
            start,
            start,
            start + timedelta(hours=1, seconds=1),
            start + timedelta(hours=1, seconds=1),
        ]
    )

    limiter = SlidingWindowRateLimiter(
        limit=1,
        window=timedelta(hours=1),
        clock=clock,
    )

    assert limiter.allow("127.0.0.1").allowed is True
    assert limiter.allow("127.0.0.1").allowed is False

    limiter.reset()

    assert limiter.allow("127.0.0.1").allowed is True
