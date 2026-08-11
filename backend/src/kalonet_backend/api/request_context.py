from fastapi import Request


def get_request_id(request: Request) -> str:
    """Return the correlation ID created by middleware."""

    request_id = getattr(
        request.state,
        "request_id",
        None,
    )

    if not isinstance(request_id, str) or not request_id:
        return "unknown"

    return request_id
