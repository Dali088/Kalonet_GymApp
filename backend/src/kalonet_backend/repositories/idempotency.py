import hashlib
import json
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from kalonet_backend.models import IdempotencyRecord


class IdempotencyConflictError(Exception):
    """A key was reused with a different request payload."""


class IdempotencyInProgressError(Exception):
    """An equivalent request is currently being processed."""


class IdempotencyReplay:
    def __init__(self, status_code: int, body: dict[str, Any]) -> None:
        self.status_code = status_code
        self.body = body


def request_hash(payload: object) -> str:
    """Hash canonical JSON so equivalent JSON payloads have the same identity."""
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"), default=str).encode()
    return hashlib.sha256(encoded).hexdigest()


class IdempotencyRepository:
    """Reserve and complete retry records inside the caller-owned transaction."""

    def __init__(self, session: Session) -> None:
        self.session = session

    def reserve(
        self,
        *,
        user_id: UUID,
        key: str,
        route_pattern: str,
        payload_hash: str,
    ) -> IdempotencyRecord | IdempotencyReplay:
        expires_at = datetime.now(UTC) + timedelta(hours=24)
        statement = (
            insert(IdempotencyRecord)
            .values(
                user_id=user_id,
                idempotency_key=key,
                http_method="POST",
                route_pattern=route_pattern,
                request_hash=payload_hash,
                state="processing",
                expires_at=expires_at,
            )
            .on_conflict_do_nothing(
                index_elements=["user_id", "http_method", "route_pattern", "idempotency_key"]
            )
            .returning(IdempotencyRecord.id)
        )
        created_id = self.session.scalar(statement)
        if created_id is not None:
            created = self.session.get(IdempotencyRecord, created_id)
            if created is None:
                raise IdempotencyConflictError
            return created

        existing = self.session.scalar(
            select(IdempotencyRecord)
            .where(
                IdempotencyRecord.user_id == user_id,
                IdempotencyRecord.http_method == "POST",
                IdempotencyRecord.route_pattern == route_pattern,
                IdempotencyRecord.idempotency_key == key,
            )
            .with_for_update()
        )
        if existing is None or existing.expires_at <= datetime.now(UTC):
            if existing is not None:
                self.session.delete(existing)
                self.session.flush()
                return self.reserve(
                    user_id=user_id,
                    key=key,
                    route_pattern=route_pattern,
                    payload_hash=payload_hash,
                )
            raise IdempotencyConflictError
        if existing.request_hash != payload_hash:
            raise IdempotencyConflictError
        if existing.state == "processing":
            raise IdempotencyInProgressError
        if existing.response_status is None or existing.response_body is None:
            raise IdempotencyInProgressError
        return IdempotencyReplay(existing.response_status, existing.response_body)

    def complete(self, record: IdempotencyRecord, status_code: int, body: dict[str, Any]) -> None:
        record.state = "completed"
        record.response_status = status_code
        record.response_body = body
        self.session.flush()
