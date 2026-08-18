#! /bin/sh

exec uvx \
  --quiet \
  --isolated \
  --refresh \
  --from "wcpan-drive-synology[server]>=4.1.0,<5.0.0" \
  -- \
  wcpan.drive.synology \
    --log-level=DEBUG \
    --config=/mnt/drive.yaml \
    "$@"
