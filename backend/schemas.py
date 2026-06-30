# Validation Layer: Pydantic models define the shape of every request / response
# Incoming JSON is parsed into these models before any business logic, and if the data doesn't match, the request is rejected with a clear error message
from pydantic import BaseModel, Field


# ==============================================================================
# Request schemas
# ==============================================================================

class UpdateUsernameRequest(BaseModel):
    username: str = Field(..., min_length=1, max_length=20)

class SearchFoodRequest(BaseModel):
    food_name: str = Field(..., min_length=1)

class GetFoodDetailRequest(BaseModel):
    food_id: str = Field(..., min_length=1)

class NearbyPOIRequest(BaseModel):
    # Sent by Flutter when the user opens the Explore screen and needs nearby points of interest
    lat: float = Field(..., ge=-90, le=90, description="User's latitude")    # ge/le constrain to valid coordinate range
    lng: float = Field(..., ge=-180, le=180, description="User's longitude")  # same for longitude

class CheckInPOIRequest(BaseModel):
    # Sent by Flutter when the user taps the Check In button near a POI
    poi_name: str = Field(..., min_length=1)          # name of the POI the user wants to check into
    poi_category: str = Field(..., min_length=1)      # category of the POI (e.g. 'restaurant', 'park')
    poi_lat: float = Field(..., ge=-90, le=90)        # latitude of the POI
    poi_lng: float = Field(..., ge=-180, le=180)      # longitude of the POI
    user_lat: float = Field(..., ge=-90, le=90)       # user's current latitude (verified server-side)
    user_lng: float = Field(..., ge=-180, le=180)     # user's current longitude

class UpdatePfpRequest(BaseModel):
    pfp_base64: str = Field(..., min_length=1)

class UpdateAppColorRequest(BaseModel):
    app_color: int  # stored as ARGB bigint, matching Flutter's Color.toARGB32()

class UpdateNotificationsRequest(BaseModel):
    enabled: bool

class UpdateUnitsRequest(BaseModel):
    units: str

class AddFcmTokenRequest(BaseModel):
    token: str = Field(..., min_length=1)

class RemoveFcmTokenRequest(BaseModel):
    token: str = Field(..., min_length=1)

class UpsertFoodLogRequest(BaseModel):
    date: str = Field(..., min_length=1)  # e.g. "2025-04-13"
    breakfast: list = Field(default_factory=list)
    lunch: list = Field(default_factory=list)
    dinner: list = Field(default_factory=list)
    snack: list = Field(default_factory=list)

class UpsertFoodLogV2Request(BaseModel):
    date: str = Field(..., min_length=1)
    items: list = Field(default_factory=list)  # list of food item dicts with meal, macros, etc.

class UpsertWaterLogRequest(BaseModel):
    date: str = Field(..., min_length=1)
    entries_ml: list = Field(default_factory=list)  # list of {amount_ml: int}

class UpsertWeightLogRequest(BaseModel):
    date: str = Field(..., min_length=1)
    weight_kg: float

class DeleteWeightLogRequest(BaseModel):
    date: str = Field(..., min_length=1)

class SetReminderRequest(BaseModel):
    message: str = Field(..., min_length=1)
    scheduled_at: str = Field(..., min_length=1)
    notification_id: int

class DeleteReminderRequest(BaseModel):
    reminder_id: str = Field(..., min_length=1)

class ClaimAchievementRequest(BaseModel):
    achievement_id: str = Field(..., min_length=1)
    tier: int

class ClaimTrivialAchievementRequest(BaseModel):
    achievement_id: str = Field(..., min_length=1)

class UpdateUtcOffsetRequest(BaseModel):
    utc_offset: int

class UpdateGoalsRequest(BaseModel):
    # TODO: remove after update goes live
    calories_goal: int | None = None
    protein_goal: int | None = None
    carbs_goal: int | None = None
    fat_goal: int | None = None
    weekly_workouts_goal: int | None = None
    weight_goal_type: str | None = Field(default=None, description="lose | gain | maintain")

class UpdateNutritionGoalsRequest(BaseModel):
    calories_goal: int | None = None
    protein_goal: int | None = None
    carbs_goal: int | None = None
    fat_goal: int | None = None

class UpdateWeightGoalRequest(BaseModel):
    weight_goal_type: str | None = Field(default=None, description="lose | gain | maintain")
    weight_kg_goal: float | None = None

class UpdateWaterGoalRequest(BaseModel):
    water_ml_goal: int | None = None

class UpdateWeeklyWorkoutsGoalRequest(BaseModel):
    weekly_workouts_goal: int | None = None

# ==============================================================================
# Shared / nested models  (defined before any response that references them)
# ==============================================================================

class POIItem(BaseModel):
    # A single point of interest returned from Overpass
    name: str      # display name of the place (e.g. "Starbucks")
    lat: float     # latitude of the POI
    lng: float     # longitude of the POI
    category: str  # the OSM tag category (e.g. "cafe", "park", "gym")

class LeaderboardUserEntry(BaseModel):
    # A single user entry in the leaderboard response
    uid: str
    username: str | None = None
    level: int = 1
    exp_points: int = 0
    pfp_base64: str | None = None

class ReminderItem(BaseModel):
    id: str
    message: str
    scheduled_at: str
    notification_id: int

class AchievementProgressEntry(BaseModel):
    # A single achievement's progress for the user
    achievement_id: str
    progress: int

class AchievementClaimEntry(BaseModel):
    # A single claimed tier for an achievement
    achievement_id: str
    tier: int
    claimed_at: str

class UseReferralRequest(BaseModel):
    referral_code: str

class UseReferralResponse(BaseModel):
    new_level: int
    new_exp: int
    xp_awarded: int

class PendingReferralReward(BaseModel):
    referee_uid: str
    referee_username: str

class ClaimReferralRewardRequest(BaseModel):
    referee_uid: str

class ClaimReferralRewardResponse(BaseModel):
    new_level: int
    new_exp: int
    xp_awarded: int

class StreakEntry(BaseModel):
    streak_type: str
    streak: int
    highest_streak: int

# ==============================================================================
# Response schemas
# ==============================================================================

class AchievementDefItem(BaseModel):
    id: str
    name: str
    description: str
    tiers: list[int]
    unit: str
    section: str

class DailyRewardResponse(BaseModel):
    # What is returned when the user tries to claim a daily reward
    claimed: bool  # true if successfully claimed
    xp_gained: int = 0
    base_xp: int = 0
    new_level: int = 1
    new_exp: int = 0
    seconds_remaining: int = 0
    daily_streak: int = 1
    streak_multiplier: float = 1.0

class ProgressResponse(BaseModel):
    # What is returned when Flutter requests the user's current progress (level, XP, and reward status)
    # Read by the client to display the XP bar, level, and whether the daily reward button should be enabled,
    # without giving direct Postgres read access to sensitive fields
    level: int = 1
    exp_points: int = 0
    exp_needed: int = 100
    can_claim_daily_reward: bool = True  # computed from last_daily_claim, not stored in DB


class UpdateUsernameResponse(BaseModel):
    success: bool
    error: str | None = None

class NearbyPOIResponse(BaseModel):
    # The full response containing a list of nearby POIs
    pois: list[POIItem] = []  # list of POI items, empty by default if none found

class CheckInPOIResponse(BaseModel):
    # What is returned after a check-in attempt
    success: bool       # true if the check-in went through
    xp_gained: int = 0  # how much XP was awarded
    new_level: int = 1  # user's level after XP is applied
    new_exp: int = 0    # user's XP after the award
    error: str | None = None  # reason for failure if success is false

class GoalsResponse(BaseModel):
    calories_goal: int | None = None
    protein_goal: int | None = None
    carbs_goal: int | None = None
    fat_goal: int | None = None
    weight_goal_type: str | None = None
    water_ml_goal: int | None = None
    weight_kg_goal: float | None = None
    weekly_workouts_goal: int | None = None

class GetUserDataResponse(BaseModel):
    level: int = 1
    exp_points: int = 0
    exp_needed: int = 100

    pfp_base64: str | None = None
    username: str
    app_color: int | None = None
    fcm_tokens: list[str] = []
    notifications_enabled: bool = True
    last_daily_claim: str | None = None  # ISO string
    can_claim_daily_reward: bool = True  # computed from last_daily_claim, not stored in DB
    daily_streak: int = 1
    food_logs: list = Field(default_factory=list)
    food_logs_v2: list = Field(default_factory=list)
    reminders: list[ReminderItem] = Field(default_factory=list)
    goals: GoalsResponse | None = None
    referral_code: str | None = None
    referral_count: int = 0
    referral_used: bool = False
    units: str = 'metric'
    water_logs: list = Field(default_factory=list)
    weight_logs: list = Field(default_factory=list)
    created_at: str | None = None

class SimpleSuccessResponse(BaseModel):
    # Reusable for routes that just need to confirm success
    success: bool
    error: str | None = None

class GetLeaderboardResponse(BaseModel):
    # The full leaderboard response containing a list of user entries sorted by level and XP
    users: list[LeaderboardUserEntry] = []

class GetRemindersResponse(BaseModel):
    reminders: list[ReminderItem] = []

class GetAchievementsResponse(BaseModel):
    # Both progress and claims returned together so the badges screen has everything in one call
    progress: list[AchievementProgressEntry] = []
    claims: list[AchievementClaimEntry] = []

class GetStreaksResponse(BaseModel):
    streaks: list[StreakEntry] = []

class ReferralCodeResponse(BaseModel):
    referral_code: str
class LoggedSetRequest(BaseModel):
    set_number: int = Field(..., ge=1)
    reps: int | None = Field(default=None, ge=0)        # null for timed/cardio exercises
    weight_kg: float | None = Field(default=None, ge=0) # null for bodyweight exercises

class LoggedExerciseRequest(BaseModel):
    exercise_id: int | None = None                      # null if the exercise was deleted from the library after the session started
    exercise_name: str = Field(..., min_length=1)
    sets: list[LoggedSetRequest]

class LogWorkoutRequest(BaseModel):
    name: str | None = None                             # null for empty sessions not started from a routine
    date: str = Field(..., min_length=1)                # "YYYY-MM-DD"
    duration_seconds: int = Field(..., ge=0)
    exercises: list[LoggedExerciseRequest] = Field(..., min_length=1)  # must have at least one exercise

class LogWorkoutResponse(BaseModel):
    workout_id: str

class RecentWorkoutItem(BaseModel):
    workout_id: str
    name: str | None = None
    date: str
    duration_seconds: int | None = None
    created_at: str

class GetRecentWorkoutsResponse(BaseModel):
    workouts: list[RecentWorkoutItem]

class GetWeeklyWorkoutCountResponse(BaseModel):
    count: int

class GetTodayOverviewResponse(BaseModel):
    volume_kg: float
    exercises: int
    sets: int
    reps: int
    duration_seconds: int
    primary_muscles: list[str]
    secondary_muscles: list[str]

class HeatmapDay(BaseModel):
    date: str
    count: int

class GetWorkoutHeatmapResponse(BaseModel):
    days: list[HeatmapDay]

class RecentExerciseItem(BaseModel):
    exercise_id: int | None = None
    exercise_name: str

class GetRecentExercisesResponse(BaseModel):
    exercises: list[RecentExerciseItem]

class SearchExercisesResponse(BaseModel):
    id: int
    name: str
    category: str | None = None
    force: str | None = None
    level: str | None = None
    mechanic: str | None = None
    equipment: str | None = None
    instructions: list[str] | None = Field(default_factory=list)
    primary_muscle: str | None = None
    secondary_muscles: list[str] | None = Field(default_factory=list)
    is_custom: bool = False

class CreateCustomExerciseRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    primary_muscle: str | None = None
    secondary_muscles: list[str] = Field(default_factory=list)
    equipment: str | None = None
    level: str | None = None

class CreateCustomExerciseResponse(BaseModel):
    exercise_id: int
    name: str

class EditCustomExerciseRequest(BaseModel):
    exercise_id: int
    name: str = Field(..., min_length=1, max_length=100)
    primary_muscle: str | None = None
    secondary_muscles: list[str] = Field(default_factory=list)
    equipment: str | None = None
    level: str | None = None

class DeleteCustomExerciseRequest(BaseModel):
    exercise_id: int

class RoutineExerciseItem(BaseModel):
    exercise_id: int | None = None
    exercise_name: str
    exercise_order: int

class CreateRoutineRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    exercises: list[RoutineExerciseItem] = Field(default_factory=list)

class CreateRoutineResponse(BaseModel):
    template_id: str

class ExerciseStatItem(BaseModel):
    exercise_name: str
    pr_weight_kg: float | None = None
    pr_reps: int | None = None
    pr_volume_kg: float | None = None
    estimated_1rm: float | None = None
    last_weight_kg: float | None = None
    last_reps: int | None = None
    total_sets: int = 0

class GetExerciseStatsResponse(BaseModel):
    stats: list[ExerciseStatItem]

class CopyRoutineRequest(BaseModel):
    template_id: str

class MyRoutineExerciseItem(BaseModel):
    exercise_name: str
    exercise_order: int

class MyRoutineItem(BaseModel):
    template_id: str
    name: str
    exercise_count: int
    exercises: list[MyRoutineExerciseItem]
    created_at: str
    source_template_id: str | None = None

class GetMyRoutinesResponse(BaseModel):
    routines: list[MyRoutineItem]

class BrowseRoutineItem(BaseModel):
    template_id: str
    name: str
    exercise_count: int
    exercises: list[MyRoutineExerciseItem]
    estimated_duration_minutes: int | None = None
    creator_username: str | None = None  # null for featured routines
    like_count: int = 0
    liked_by_me: bool = False

class GetBrowseRoutinesResponse(BaseModel):
    featured: list[BrowseRoutineItem]
    community: list[BrowseRoutineItem]

class DeleteRoutineRequest(BaseModel):
    template_id: str

class LikeRoutineRequest(BaseModel):
    template_id: str

class UnlikeRoutineRequest(BaseModel):
    template_id: str
