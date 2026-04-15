# Server-protected achievements that are only tracked internally as side effects of validated actions.
# _track_achievement validates against this set so our own code can't write junk IDs to the DB.
SERVER_ACHIEVEMENT_IDS = {
    "level", "daily_claims", "daily_claim_streak", "poi_visits", "food_logs",
    "food_streak", "set_reminder", "delete_reminder", "set_username",
    "set_pfp", "change_app_color", "color_indecisive", "change_username",
    "total_achievements",
}

# Low-stakes achievements the client can trigger directly via /claim_trivial_achievement.
# Gaming these doesn't matter, so they don't need server-side validation of the action.
TRIVIAL_ACHIEVEMENT_IDS = {
    "poi_categories", "poi_regular",
    "open_food_logging", "open_explore", "open_reminders", "open_badges", "open_leaderboard",
    "food_recent", "food_full_day", "food_manual", "food_barcode",
    "food_search", "calorie_calculator",
    "future_reminder", "active_reminders",
    "send_feedback", "switch_imperial",
}

# Union of both sets, used anywhere that needs to check if an ID is valid at all
VALID_ACHIEVEMENT_IDS = SERVER_ACHIEVEMENT_IDS | TRIVIAL_ACHIEVEMENT_IDS
