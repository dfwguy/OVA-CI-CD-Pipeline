# Package and deployment

This repository is a clean source snapshot of the NVIS-OVA Hub serving port 8787
on the `nvisova` host. The Python application and web files were compared by
SHA-256 with the running `nvis-ova-hub` container when packaging; all 29 matched.
The snapshot includes previously uncommitted container deployment support from
the host. Its source baseline is commit
`5ac6655` on `feature/staging-hub-control-plane` in the original working tree.

Runtime databases, audit logs, imported artifacts, browser tools, credentials,
SSH keys, and the original repository history are excluded. Back up the runtime
directory separately when migrating an existing installation. The source snapshot
does not replace that backup.

## Local validation

```bash
python3 -m venv .venv
.venv/bin/python -m pip install '.[dev,production]'
.venv/bin/ruff check src tests
.venv/bin/pytest -q
.venv/bin/python -m compileall -q src
```

GitLab runs lint, tests, and compilation through `.gitlab-ci.yml`. Its jobs require
a Linux Docker runner tagged `type/docker` and `os/linux`. The pipeline validates
source; deployment is operated separately through Compose or Podman Quadlet.

## New Compose installation

1. Install Git, an OCI container runtime, and Docker Compose. Clone this project
   and install the Python package as above for the bootstrap CLI.
2. Choose an absolute host path for `NVIS_RUNTIME`. Create its `data` and `secrets`
   directories with permissions restricted to the service user. Copy
   `config.example.toml` to `$NVIS_RUNTIME/config.toml`.
3. Edit all `[paths]` entries to use `$NVIS_RUNTIME/data` and its `inbox`,
   `quarantine`, `work`, and `state` subdirectories. TOML needs the actual absolute
   paths; environment variables in TOML are not expanded.
4. Place the GitLab token in `$NVIS_RUNTIME/secrets/gitlab_token` with mode 0600.
   Set the TOML token paths to this secrets directory. Set the GitLab username,
   NVFTP username, SSH identity path, and known-hosts path for your installation.
   Install the SSH key and pinned known-hosts file outside this repository.
5. Create fresh portal credentials:

   ```bash
   .venv/bin/nvis-integration --config "$NVIS_RUNTIME/config.toml" \
     portal-bootstrap --runtime-root "$NVIS_RUNTIME"
   ```

   Login as `admin` using the generated
   `$NVIS_RUNTIME/secrets/bootstrap-admin-password` file. Bootstrap refuses to
   overwrite existing credentials.
6. Export `NVIS_RUNTIME`, `NVIS_SSH_KEY`, and `NVIS_KNOWN_HOSTS` with absolute paths
   matching the TOML configuration. Set `APP_UID` and `APP_GID` to the service
   account that owns the mounted data and secrets, then run:

   ```bash
   docker compose up --build -d
   docker compose ps
   ```

The portal listens on port 8787. Compose preserves runtime paths inside the
container, so paths in TOML must match the mounted paths. Use
`NVIS_INSECURE_HTTP=true` only on a trusted internal network; set it to `false`
behind a TLS reverse proxy. Slack is a separate process and requires credentials
and allowlists described in [the operator guide](nvis-ova-hub.md).

## Existing host and Podman

`deploy/nvis-ova-hub-container.container` records the deployed host's Quadlet,
including its `~/cicd-hub/runtime` and SSH mounts. Adapt those paths for another
host. Build the image with `podman build -t localhost/nvis-ova-hub:local .`, install
the Quadlet in `~/.config/containers/systemd/`, and reload the user systemd manager
before starting `nvis-ova-hub-container.service`.

The supplied Quadlet uses UID 0 inside a rootless container so it can access the
host user's restricted bind mounts. The Dockerfile defaults to UID 10001; Compose
can use the owning service account's UID/GID. The live service was left running
while this package was prepared.
