import os
import json
from datetime import datetime, timezone
from supabase import create_client

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]

PAGE_SIZE = 1000  # Supabase max rows per request


def get_all_tables(client) -> list[str]:
    # Query information_schema to get all user-created tables in the public schema
    result = client.rpc("get_public_tables").execute()
    return [row["table_name"] for row in result.data]


def fetch_table(client, table: str) -> list:
    rows = []
    offset = 0
    while True:
        result = (
            client.table(table)
            .select("*")
            .range(offset, offset + PAGE_SIZE - 1)
            .execute()
        )
        batch = result.data or []
        rows.extend(batch)
        if len(batch) < PAGE_SIZE:
            break  # no more pages
        offset += PAGE_SIZE
    return rows


def main():
    client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    output_dir = os.path.join("backup-repo", timestamp)
    os.makedirs(output_dir, exist_ok=True)

    tables = get_all_tables(client)
    print(f"Found tables: {tables}")
    for table in tables:
        print(f"Backing up {table}...")
        rows = fetch_table(client, table)
        path = os.path.join(output_dir, f"{table}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(rows, f, indent=2, default=str)
        print(f"  {len(rows)} rows -> {path}")

    print("Backup complete.")


if __name__ == "__main__":
    main()
