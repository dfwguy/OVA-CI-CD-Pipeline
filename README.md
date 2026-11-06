# NVIS-OVA CI/CD Hub

Published as **OVA-CI/CD-Pipeline** in the `nvis-ova/OVA-CI-CD-Pipeline`
GitLab project. This package contains the application and web sources verified
against the service running on port 8787, together with its container build,
deployment definitions, tests, and GitLab validation pipeline. See the
[package and deployment notes](docs/package-deployment.md) for first-time setup.

This host service is the control plane for a human-gated NVFTP/GitLab software
exchange. It combines a Slack command agent, authenticated web portal, live GitLab
inventory, NVFTP staging, policy gates, and tamper-evident audit. Slack accepts
typed `/nvis` commands plus constrained natural-language mentions and direct
messages over outbound-only Socket Mode. It resolves the NVFTP source through an
operator-reviewed routing catalog, verifies that the named artifact set exists,
and presents an approval button to an allowlisted approver other than the requester.
The worker then:

1. downloads the exact manifest, checksum, Git bundle, and tarball set;
2. validates checksums, provenance/classification, archive safety, passive secret
   patterns, malware, and the bundle;
3. resolves an exact project directly below `nvis-ova`;
4. creates a project or pushes a deterministic `nvftp/<date>-<sha>` branch;
5. opens an MR for an existing project and posts the review URL to Slack.

For flattened, unrelated snapshot bundles, it creates a new commit on top of the
destination's current protected default branch. It never joins unrelated Git
histories. It never approves or merges. Free-form Slack text is never passed to a
shell or coding agent.

Every job transition is recorded in a tamper-evident, hash-chained SQLite audit
ledger. See [the Hub operator guide](docs/nvis-ova-hub.md),
[architecture](docs/architecture.md), [artifact contract](docs/artifact-contract.md),
and [bootstrap runbook](docs/bootstrap-runbook.md).

Michelle Ramirez's original GitLab-to-NVFTP container-transfer proof of concept is
preserved under `examples/gitlab-to-nvftp/`. It is reference material rather than
the production pipeline; the staging hub uses pinned SSH host keys and never prints
private-key material.

The deployed staging portal is explicitly bound to port 8787 on the NVIDIA-internal
`nvisova` VM. Public or cross-network deployments must use an SSH tunnel or an
authenticated TLS reverse proxy. The Slack service remains inactive until its
bot/app credentials and immutable user/channel allowlists are installed. Never put
tokens in this repository or a Slack message.

## Container deployment

`Dockerfile` runs the portal with Gunicorn as an unprivileged user. `compose.yaml`
adds a read-only root filesystem, dropped capabilities, resource limits, bounded
logs, a health check, and an automatic restart policy. Runtime data and credentials
remain bind-mounted so image upgrades preserve state.

For Docker Compose, set `NVIS_RUNTIME`, `NVIS_SSH_KEY`, `NVIS_KNOWN_HOSTS`,
`APP_UID`, and `APP_GID` in the deployment environment, then run
`docker compose up --build -d`. Keep
`NVIS_INSECURE_HTTP=true` only while the portal is restricted to a trusted internal
network; terminate TLS in front of the service and set it to `false` for any broader
deployment.

The Quadlet under `deploy/` runs the same OCI image under rootless Podman on hosts
where Docker Engine is unavailable. Enable lingering for the service user so its
user systemd manager starts at boot and survives logout.
