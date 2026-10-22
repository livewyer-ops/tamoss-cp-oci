FROM python:3.14.7-slim-bookworm@sha256:82bc3c539b8813ada9d68c63b40158fa002f7f33de9bf3312a3dfdc0620dff56
COPY --from=ghcr.io/astral-sh/uv:0.9.25@sha256:13e233d08517abdafac4ead26c16d881cd77504a2c40c38c905cf3a0d70131a6 /uv /bin/uv
WORKDIR /tamoss
COPY source/ ./
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/playwright UV_NO_CACHE=1 UV_PYTHON_DOWNLOADS=never
RUN uv sync --project src --locked --all-extras --dev
RUN uv run --project src playwright install --with-deps chromium
ENV PATH=/tamoss/src/.venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1
ENTRYPOINT ["pytest", "-c", "src/pyproject.toml", "-p", "no:cacheprovider"]
