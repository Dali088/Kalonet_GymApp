# syntax=docker/dockerfile:1.7

# The builder uses the same Python minor version required by Kalonet.
FROM python:3.12-slim AS builder

# Copy the pinned uv binaries from the official uv image; uv is needed only
# while building the artifact and will not be copied into the runtime image.
COPY --from=ghcr.io/astral-sh/uv:0.12.1 /uv /uvx /bin/

# Keep the build commands and project files under one predictable directory.
WORKDIR /app

# Compile bytecode for faster startup and copy files instead of linking them
# so the virtual environment can move safely into the runtime stage.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

# Copy only dependency metadata first. Docker can reuse this layer when source
# code changes but the dependency declarations and lockfile do not.
COPY pyproject.toml uv.lock README.md ./

# Install exactly the locked production dependencies. Development tools such as
# pytest, Ruff, and mypy are intentionally excluded from the runtime artifact.
RUN uv sync --locked --no-dev --no-install-project

# Copy application source only after the dependency layer has been created.
COPY src ./src

# Install Kalonet itself as a normal, non-editable package for runtime use.
RUN uv sync --locked --no-dev --no-editable


# Start a clean runtime stage so build tools, caches, and source build metadata
# do not unnecessarily increase the final artifact.
FROM python:3.12-slim AS runtime

# This is the working directory used by the application process.
WORKDIR /app

# Put the built virtual environment first on PATH and make Python logs visible
# immediately while avoiding generated .pyc files in the container filesystem.
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Run the application as a dedicated unprivileged user instead of root.
RUN useradd --create-home --uid 10001 kalonet

# Move only the ready-to-run environment and migration files into the runtime
# image. The source package is already installed non-editably in .venv.
COPY --from=builder --chown=kalonet:kalonet /app/.venv /app/.venv
COPY --chown=kalonet:kalonet alembic.ini ./alembic.ini
COPY --chown=kalonet:kalonet migrations ./migrations

# Apply the least-privilege user to the process that starts below.
USER kalonet

# Document the port the FastAPI process listens on inside the container.
EXPOSE 8000

# Bind to all container interfaces so a caller can publish port 8000 from the
# host. This starts the application without development reload behavior.
CMD ["uvicorn", "kalonet_backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
