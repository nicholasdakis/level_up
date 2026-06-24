"""
One-time script to backfill created_at on all users from Firebase Auth metadata.
Run after adding the created_at column in Supabase:
  ALTER TABLE users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ;

Usage:
  SUPABASE_URL=... SUPABASE_KEY=... FIREBASE_SERVICE_ACCOUNT=... python backfill_created_at.py
"""

import json
import os
import firebase_admin
from firebase_admin import credentials, auth
from supabase import create_client

supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])

if not firebase_admin._apps:
    cred = credentials.Certificate(json.loads(os.environ["FIREBASE_SERVICE_ACCOUNT"]))
    firebase_admin.initialize_app(cred)

# fetch all UIDs from Supabase in pages
page_size = 1000
offset = 0
all_uids = []

while True:
    result = supabase.table("users").select("uid").range(offset, offset + page_size - 1).execute()
    rows = result.data or []
    all_uids.extend(r["uid"] for r in rows)
    if len(rows) < page_size:
        break
    offset += page_size

print(f"Found {len(all_uids)} users")

updated = 0
skipped = 0
failed = 0

for uid in all_uids:
    try:
        user = auth.get_user(uid)
        created_at = user.user_metadata.creation_timestamp  # milliseconds since epoch
        if created_at is None:
            skipped += 1
            continue
        # convert ms to ISO timestamp
        from datetime import datetime, timezone
        dt = datetime.fromtimestamp(created_at / 1000, tz=timezone.utc).isoformat()
        supabase.table("users").update({"created_at": dt}).eq("uid", uid).execute()
        updated += 1
        print(f"  {uid} -> {dt}")
    except Exception as e:
        print(f"  FAILED {uid}: {e}")
        failed += 1

print(f"\nDone. Updated: {updated}, Skipped: {skipped}, Failed: {failed}")
