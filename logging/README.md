# Container Logs to Files on Synology NAS

Writes the logs of the compose projects in this repo to one file per container under a folder, and rotates them with logrotate.

## How It Works

```
container --(journald driver, tag=<project>-<service>)--> journald
journald --(syslog-ng systemd-journal source)--> syslog-ng
syslog-ng --(docker-logs.conf filter)--> $LOG_DIR/<project>-<service>.log
logrotate (daily task) --> rotates $LOG_DIR/*.log
```

Each compose service sets:

```yaml
logging:
  driver: journald
  options:
    tag: <project>-<service>
```

`scripts/install.sh` renders `templates/*.in` from `.env` into `generated/` and installs the syslog-ng rule as a regular file at `/usr/local/etc/syslog-ng/patterndb.d/docker-logs.conf`, where DSM packages keep theirs. It is a copy rather than a symlink because syslog-ng starts before `/volume1` is mounted.

The install step checks the full syslog-ng config with `syslog-ng --syntax-only` and restores the previous rule if it fails. It only reloads syslog-ng when the rule changed.

## Setup

### 1. Configure

```bash
cp .env.example .env
```

Edit `.env`:
- `LOG_PROJECTS`: projects whose tags start with `<project>-`
- `LOG_DIR`: absolute folder for the log files
- `LOG_ROTATE_PERIOD`: `daily`, `weekly`, `monthly` or `yearly`
- `LOG_ROTATE_KEEP`: number of rotated files to keep, in `LOG_ROTATE_PERIOD` units
- `SYSLOG_UNIT`: syslog-ng unit name, check with `systemctl list-units --all | grep -i syslog`

The real `.env` and `generated/` are local-only.

### 2. Install (as root)

Preview the generated config and its diff against what is installed (no root needed):

```bash
./scripts/install.sh --dry-run
```

Then install:

```bash
sudo ./scripts/install.sh
```

Test before recreating real containers (the tag must start with a listed project):

```bash
docker run --rm --log-driver journald --log-opt tag=dns-test alpine echo hello-pipeline
cat "$LOG_DIR/dns-test.log"
grep -r hello-pipeline /var/log/ 2>/dev/null   # should print nothing
```

Then recreate each project's containers so they pick up the logging driver:

```bash
docker compose up -d --force-recreate
```

### 3. DSM Task Scheduler

Control Panel → Task Scheduler → Create, user `root`:

- **Triggered Task → Boot-up**, restores the rule if a DSM update removed it:
  ```bash
  /volume1/path/to/nas.projects/logging/scripts/install.sh
  ```
- **Scheduled Task → Daily**, rotates the logs (keep it daily for any `LOG_ROTATE_PERIOD`; logrotate tracks when each file was last rotated and skips it until the period has passed):
  ```bash
  /volume1/path/to/nas.projects/logging/scripts/rotate.sh
  ```

Dry run of the rotation:

```bash
sudo ./scripts/rotate.sh -d
```

## Adding a Project

1. Add the `logging:` block with tag `<project>-<service>` to its `compose.yaml`.
2. Add the project to `LOG_PROJECTS` in `.env`.
3. Run `sudo ./scripts/install.sh`, then recreate the project's containers.

## Notes

- Container Manager's log tab stays empty for these containers; `docker logs` still works through Docker's dual logging cache.
- syslog-ng object names are global. DSM's `ContainerManager.conf` already defines `d_docker` and `f_docker`, so the rule here uses `d_docker_logs` and `f_docker_logs`; keep new names unique.
- `ContainerManager.conf` has no `flags(final)` and only matches program names containing `docker` or messages containing `Docker:`, so it does not take container output away from this rule. Avoid `docker` in tags.
