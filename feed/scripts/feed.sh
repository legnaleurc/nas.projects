#! /bin/sh

exec uvx \
  --quiet \
  --isolated \
  --from "wcpan-drive-feed[inotify]" \
  -- \
  wcpan.drive.feed \
    --config=/mnt/feed.yaml \
    "$@"
