# Retry Container Starts on Boot

Starts containers that Docker tried to start when the NAS booted but failed to.

## Why

Every compose service here uses `restart: unless-stopped`, so Docker brings it back on boot unless it was stopped by hand (`docker compose stop`) or removed (`docker compose down`). If that start itself fails, Docker logs the error and never tries again; restart policies only cover containers that exit after starting. At boot this happens when:

- a port is bound to a LAN IP that is not assigned yet (`cannot assign requested address`)
- a `network_mode: service:<x>` container starts before `<x>` is running (`portal`)

## How It Works

`scripts/retry-start.sh` waits for the Docker daemon, then looks for stopped containers with an `always` or `unless-stopped` policy and a non-empty `State.Error`. Docker records the error when a start fails and clears it when a start succeeds, so a container you stopped by hand has no error and is left alone. Those containers are started again every `RETRY_INTERVAL` seconds (default 30), up to `RETRY_ROUNDS` times (default 10). The script exits non-zero if any are still down at the end, so DSM can notify you.

List what it would start, without starting anything:

```bash
sudo ./scripts/retry-start.sh --dry-run
```

## Setup

Control Panel → Task Scheduler → Create → Triggered Task → User-defined script, user `root`, event **Boot-up**:

```bash
/volume1/path/to/nas.projects/autostart/scripts/retry-start.sh
```

Turn on "Send run details by email" → "only when the script terminates abnormally" to hear about containers that are still down.

After changing a service's `restart:` policy, recreate its containers so the change takes effect:

```bash
docker compose up -d
```
