# /// script
# requires-python = ">=3.13"
# dependencies = [
#   "PyYAML>=6.0.1",
#   "httpx>=0.28.0",
# ]
# ///

import argparse
import sqlite3
import sys

import httpx
import yaml

SUPER_ROOT_ID = "00000000-0000-0000-0000-000000000000"


def load_config(path: str) -> dict:
    with open(path) as f:
        return yaml.safe_load(f)


def find_empty_hash_nodes(conn: sqlite3.Connection) -> list[str]:
    rows = conn.execute(
        "SELECT node_id FROM nodes WHERE is_directory = 0 AND hash = ''"
    ).fetchall()
    return [row[0] for row in rows]


def resolve_path(conn: sqlite3.Connection, node_id: str) -> list[str]:
    """Return path components ordered from watch label down to the file."""
    rows = conn.execute(
        """
        WITH RECURSIVE chain AS (
            SELECT node_id, parent_id, name, 0 AS depth
            FROM nodes WHERE node_id = ?
            UNION ALL
            SELECT n.node_id, n.parent_id, n.name, c.depth + 1
            FROM nodes n JOIN chain c ON n.node_id = c.parent_id
            WHERE c.parent_id != ?
        )
        SELECT name FROM chain ORDER BY depth DESC
        """,
        (node_id, SUPER_ROOT_ID),
    ).fetchall()
    return [row[0] for row in rows]


def build_synology_path(parts: list[str], path_map: dict[str, str]) -> str | None:
    """Map [watch_label, subdir..., filename] to a Synology Drive API path."""
    if not parts:
        return None
    watch_label = parts[0]
    base = path_map.get(watch_label)
    if base is None:
        return None
    nas_path = base.rstrip("/") + "/" + "/".join(parts[1:])
    # Synology Drive API path format for NAS absolute paths: /volumes{nas_path}
    return "/volumes" + nas_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Backfill empty hashes in feed DB from Synology Drive API"
    )
    parser.add_argument("--feed-config", required=True, help="Path to feed.yaml")
    parser.add_argument("--synology-config", required=True, help="Path to synology.yaml")
    parser.add_argument("--dry-run", action="store_true", help="Do not write to database")
    args = parser.parse_args()

    feed_cfg = load_config(args.feed_config)
    syn_cfg = load_config(args.synology_config)

    db_url: str = feed_cfg["database_url"]
    host: str = syn_cfg["host"].rstrip("/")
    account: str = syn_cfg["account"]
    passwd: str = syn_cfg["passwd"]
    path_map: dict[str, str] = syn_cfg["path_map"]

    conn = sqlite3.connect(db_url)

    node_ids = find_empty_hash_nodes(conn)
    if not node_ids:
        print("No nodes with empty hash found.")
        conn.close()
        return

    print(f"Found {len(node_ids)} node(s) with empty hash.")

    # NAS devices typically use self-signed certificates
    with httpx.Client(base_url=host, verify=False) as client:
        resp = client.post(
            "/api/SynologyDrive/default/v1/login",
            json={"format": "sid", "account": account, "passwd": passwd},
        )
        resp.raise_for_status()
        login_body = resp.json()
        if not login_body.get("success"):
            print(f"Login failed: {login_body}", file=sys.stderr)
            conn.close()
            sys.exit(1)
        sid = login_body["data"]["sid"]
        client.cookies.set("id", sid)

        updated = 0
        skipped = 0

        try:
            for node_id in node_ids:
                parts = resolve_path(conn, node_id)
                api_path = build_synology_path(parts, path_map)
                if api_path is None:
                    print(f"  skip {node_id}: cannot resolve path (parts={parts})")
                    skipped += 1
                    continue

                resp = client.get(
                    "/api/SynologyDrive/default/v1/files",
                    params={"path": api_path},
                )
                resp.raise_for_status()
                file_body = resp.json()
                if not file_body.get("success"):
                    print(f"  skip {api_path}: API error {file_body.get('error')}")
                    skipped += 1
                    continue

                hash_val: str = file_body["data"].get("hash", "")
                if not hash_val:
                    print(f"  skip {api_path}: API returned empty hash")
                    skipped += 1
                    continue

                if args.dry_run:
                    print(f"  [dry-run] {api_path} -> {hash_val}")
                else:
                    conn.execute(
                        "UPDATE nodes SET hash = ? WHERE node_id = ?",
                        (hash_val, node_id),
                    )
                    conn.commit()
                    print(f"  updated {api_path} -> {hash_val}")
                updated += 1

        finally:
            client.post(
                "/api/SynologyDrive/default/v1/logout",
                json={"_sid": sid},
            )

    conn.close()
    action = "would update" if args.dry_run else "updated"
    print(f"\nDone: {updated} {action}, {skipped} skipped.")


if __name__ == "__main__":
    main()
