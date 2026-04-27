#! /bin/sh

exec uvx \
  --quiet \
  --isolated \
  --refresh \
  --from "wcpan-drive-synology[server]==3.1.0" \
  -- \
  wcpan.drive.synology \
    --log-level=DEBUG \
    --config=/mnt/drive.yaml \
    "$@"
