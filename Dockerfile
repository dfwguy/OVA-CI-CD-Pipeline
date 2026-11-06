# syntax=docker/dockerfile:1.7
FROM docker.io/library/python:3.13-slim-bookworm@sha256:2f2e5a876c71a6757f55ec57f2add0225ddaf01c802a33fcc29073943f94d907 AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1
WORKDIR /build
COPY pyproject.toml README.md ./
COPY src ./src
RUN python -m pip wheel --wheel-dir /wheels '.[production]'

FROM docker.io/library/python:3.13-slim-bookworm@sha256:2f2e5a876c71a6757f55ec57f2add0225ddaf01c802a33fcc29073943f94d907 AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    NVIS_CONFIG=/config/config.toml \
    NVIS_WEB_ROOT=/app/web \
    NVIS_AUTH_RECORDS=/run/secrets/portal-auth.json \
    NVIS_SESSION_SECRET=/run/secrets/session-secret \
    NVIS_CREDENTIAL_ROOT=/run/secrets

RUN dpkg-statoverride --add root root 0755 /usr/bin/ssh-agent \
    && apt-get -o APT::Sandbox::User=root update \
    && apt-get -o APT::Sandbox::User=root install --no-install-recommends -y ca-certificates openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 nvis \
    && useradd --uid 10001 --gid nvis --no-create-home --home-dir /nonexistent nvis

COPY --from=builder /wheels /wheels
RUN python -m pip install /wheels/* && rm -rf /wheels

WORKDIR /app
COPY web ./web

USER 10001:10001
EXPOSE 8787
STOPSIGNAL SIGTERM
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["python", "-m", "nvis_integration.container_health"]

CMD ["gunicorn", "nvis_integration.wsgi:create_app()", "--bind=0.0.0.0:8787", "--worker-class=gthread", "--workers=1", "--threads=8", "--timeout=60", "--graceful-timeout=30", "--keep-alive=5", "--max-requests=5000", "--max-requests-jitter=500", "--access-logfile=-", "--error-logfile=-", "--capture-output"]
