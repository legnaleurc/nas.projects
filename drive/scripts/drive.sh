#! /bin/sh

exec uvx \
  --quiet \
  --isolated \
  --refresh \
  --from "wcpan-drive-synology[server]==2.0.2" \
  -- \
  wcpan.drive.synology \
    --log-level=DEBUG \
    --config=/mnt/drive.yaml \
    "$@"
