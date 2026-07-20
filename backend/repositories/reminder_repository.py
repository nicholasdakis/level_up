import random
from supabase import Client


class ReminderRepository:
    # Repository class to handle all Postgres operations related to reminders

    def __init__(self, supabase: Client):
        self._supabase = supabase

    def set_reminder(self, uid: str, message: str, scheduled_at: str, notification_id: int, source: str = "user"):
        # Insert reminder into Postgres via Supabase
        result = (
            self._supabase
            .table("reminders")
            .insert({
                "uid": uid,
                "message": message,
                "scheduled_at": scheduled_at,
                "notification_id": notification_id,
                "source": source,
            })
            .execute()
        )
        return result.data

    def get_reminders(self, uid: str):
        # Fetches all of a user's user-made reminders
        result = self._supabase.table("reminders").select("*").eq("uid", uid).eq("source", "user").order("scheduled_at", desc=False).execute()
        return result.data

    def get_due_reminders(self, now_iso: str):
        # Fetches all reminders where the scheduled time has passed
        return self._supabase.table("reminders").select("*").lte("scheduled_at", now_iso).execute().data

    def delete_reminder(self, reminder_id: str, uid: str | None = None):
        # uid=None is used by the FCM dispatcher so multiple server instances don't double-send the same reminder
        # uid=uid is used by user-facing deletes to enforce ownership at the DB level in the same query
        query = self._supabase.table("reminders").delete().eq("id", reminder_id)
        if uid:
            query = query.eq("uid", uid)
        result = query.execute()
        return bool(result.data)

    def upsert_streak_warning(self, uid: str, scheduled_at: str, streak: int):
        # Delete before insert so each claim reschedules the warning from the new claim time,
        # and so a user who claims early doesn't end up with two pending warnings
        if streak == 1:
            source = "streak_warning_day_one"
            message = "Come back and claim your daily reward to keep your streak going!"
        else:
            source = "streak_warning"
            message = f"Your {streak} day streak is at risk! Claim your daily reward before it resets."
        notification_id = random.randint(1, 2**31 - 1)
        self._supabase.table("reminders").delete().eq("uid", uid).in_("source", ["streak_warning", "streak_warning_day_one"]).execute()
        self._supabase.table("reminders").insert({
            "uid": uid,
            "message": message,
            "scheduled_at": scheduled_at,
            "notification_id": notification_id,
            "source": source,
        }).execute()
