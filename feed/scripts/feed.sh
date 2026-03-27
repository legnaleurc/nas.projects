#! /bin/sh

exec uvx \
  --quiet \
  --isolated \
  --from "wcpan-drive-feed[inotify]" \
  -- \
  wcpan.drive.feed serve\
    --config=/mnt/feed.yaml
