# JDownloader on Synology

Runs the community-maintained [jlesage/jdownloader-2](https://github.com/jlesage/docker-jdownloader-2) image on the DS925+ through Container Manager. Java is included in the image.

## Setup

From this project directory on the NAS:

```bash
cp .env.example .env
id your_username
```

Edit `.env`: set the NAS LAN IP, the numeric uid and gid reported by `id`, and absolute paths for configuration and downloads. The selected DSM user needs read/write access to both folders. Create the folders in File Station and grant access before starting the container. `.env` is ignored by Git.

Validate and start over SSH:

```bash
docker compose config --quiet
docker compose up -d
docker compose logs -f jdownloader
```

Alternatively, create a Container Manager project using this directory and `compose.yaml`, keeping the configured `.env` alongside it.

Open `http://NAS-LAN-IP:5800` (or your configured port). Initial startup may take several minutes while JDownloader updates. In JDownloader, set the default download directory to `/output`; this maps to `JDOWNLOADER_DOWNLOAD_PATH` on the NAS. Settings and download lists persist in `JDOWNLOADER_CONFIG_PATH`.

The browser interface has no authentication by default. Use it on your trusted LAN; do not forward this port to the internet. For remote access, use your VPN or configure HTTPS and authentication as described in the image documentation.

## Maintenance

Update the image and recreate the container:

```bash
docker compose pull
docker compose up -d
```

Stop it:

```bash
docker compose down
```

The mapped configuration and download folders remain after the container is removed. Back up the configuration folder with the container stopped. If downloads fail with a permission error, check the configured UID/GID and DSM folder permissions.
