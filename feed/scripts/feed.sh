#! /bin/sh

exec uvx \
  --quiet \
  --isolated \
  --from "wcpan-drive-feed[inotify] @ git+https://github.com/legnaleurc/wcpan.drive.feed@_backlog" \
  -- \
  wcpan.drive.feed \
    --config=/mnt/feed.yaml
