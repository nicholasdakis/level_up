# Validation Layer: Pydantic models define the shape of every request / response
# Incoming JSON is parsed into these models before any business logic, and if the data doesn't match, the request is rejected with a clear error message
from typing import Optional
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

class UpsertFoodLogV2Request(BaseModel):
    date: str = Field(..., pattern=r'^\d{4}-\d{2}-\d{2}$')
    items: list = Field(default_factory=list)  # list of food item dicts with meal, macros, etc.

class AddFoodLogRequest(BaseModel):
    date: str = Field(..., pattern=r'^\d{4}-\d{2}-\d{2}$')
    item: dict  # single food item dict with meal, macros, etc.

class UpsertWaterLogRequest(BaseModel):
    date: str = Field(..., pattern=r'^\d{4}-\d{2}-\d{2}$')
    entries_ml: list = Field(default_factory=list)  # list of {amount_ml: int}

class UpsertWeightLogRequest(BaseModel):
    date: str = Field(..., pattern=r'^\d{4}-\d{2}-\d{2}$')
    weight_kg: float

class DeleteWeightLogRequest(BaseModel):
    date: str = Field(..., min_length=1)

class DeleteFoodLogRequest(BaseModel):
    id: str = Field(..., min_length=1)

class MoveFoodLogRequest(BaseModel):
    id: str = Field(..., min_length=1)
    meal: str = Field(..., min_length=1)

class EditFoodLogRequest(BaseModel):
    id: str = Field(..., min_length=1)
    food_description: Optional[str] = None
    calories: Optional[int] = None
    protein: Optional[float] = None
    carbs: Optional[float] = None
    fat: Optional[float] = None
    fiber: Optional[float] = None
    sugar: Optional[float] = None
    sodium: Optional[float] = None
    serving_size: Optional[str] = None

class BulkAddFoodLogItem(BaseModel):
    date: str = Field(..., min_length=1)
    meal: str = Field(..., min_length=1)
    food_name: str = Field(..., min_length=1)
    brand_name: Optional[str] = None
    food_description: Optional[str] = None
    food_id: Optional[str] = None
    calories: Optional[int] = None
    protein: Optional[float] = None
    carbs: Optional[float] = None
    fat: Optional[float] = None
    fiber: Optional[float] = None
    sugar: Optional[float] = None
    sodium: Optional[float] = None
    serving_size: Optional[str] = None

class BulkAddFoodLogsRequest(BaseModel):
    items: list[BulkAddFoodLogItem] = Field(..., min_length=1)

class SetReminderRequest(BaseModel):
    message: str = Field(..., min_length=1)
    scheduled_at: str = Field(..., min_length=1)
    notification_id: int
    source: str = Field(default="user", pattern="^(user|system)$")

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
    # ge/le bounds only apply when the value is not None, so None is still valid and means "don't change this field"
    calories_goal: int | None = Field(default=None, ge=0, le=99999)
    protein_goal: int | None = Field(default=None, ge=0, le=9999)
    carbs_goal: int | None = Field(default=None, ge=0, le=9999)
    fat_goal: int | None = Field(default=None, ge=0, le=9999)
    fiber_goal: int | None = Field(default=None, ge=0, le=9999)
    sugar_goal: int | None = Field(default=None, ge=0, le=9999)
    sodium_goal: int | None = Field(default=None, ge=0, le=99999)
    weekly_workouts_goal: int | None = Field(default=None, ge=1, le=7)
    weight_goal_type: str | None = Field(default=None, description="lose | gain | maintain")

class UpdateNutritionGoalsRequest(BaseModel):
    # ge/le bounds only apply when the value is not None, so None is still valid and means "don't change this field"
    calories_goal: int | None = Field(default=None, ge=0, le=99999)
    protein_goal: int | None = Field(default=None, ge=0, le=9999)
    carbs_goal: int | None = Field(default=None, ge=0, le=9999)
    fat_goal: int | None = Field(default=None, ge=0, le=9999)
    fiber_goal: int | None = Field(default=None, ge=0, le=9999)
    sugar_goal: int | None = Field(default=None, ge=0, le=9999)
    sodium_goal: int | None = Field(default=None, ge=0, le=99999)

class UpdateWeightGoalRequest(BaseModel):
    weight_goal_type: str | None = Field(default=None, description="lose | gain | maintain")
    weight_kg_goal: float | None = Field(default=None, ge=0, le=999)

class UpdateWaterGoalRequest(BaseModel):
    water_ml_goal: int | None = Field(default=None, ge=0, le=99999)

class UpdateWeeklyWorkoutsGoalRequest(BaseModel):
    weekly_workouts_goal: int | None = Field(default=None, ge=1, le=7)

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
    is_premium: bool = False
    count: int | None = None # for count-based leaderboard requests

class ReminderItem(BaseModel):
    id: str
    message: str
    scheduled_at: str
    notification_id: int

class FoodLogItem(BaseModel):
    id: str | None = None
    date: str
    meal: str
    food_name: str
    brand_name: str | None = None
    food_description: str | None = None
    food_id: str | None = None
    calories: float | None = None
    protein: float | None = None
    carbs: float | None = None
    fat: float | None = None
    fiber: float | None = None
    sugar: float | None = None
    sodium: float | None = None
    serving_size: str | None = None
    logged_at: str | None = None

class GetFoodLogsV2Response(BaseModel):
    food_logs_v2: list[FoodLogItem] = []

class WaterLogItem(BaseModel):
    date: str
    entries_ml: list[dict]

class GetWaterLogsResponse(BaseModel):
    water_logs: list[WaterLogItem] = []

class WeightLogItem(BaseModel):
    date: str
    weight_kg: float

class GetWeightLogsResponse(BaseModel):
    weight_logs: list[WeightLogItem] = []

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
    last_date: str | None = None

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
    bonus_xp: int = 0
    new_level: int = 1
    new_exp: int = 0
    seconds_remaining: int = 0
    daily_streak: int = 0
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
    fiber_goal: int | None = None
    sugar_goal: int | None = None
    sodium_goal: int | None = None
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
    goals: GoalsResponse | None = None
    referral_code: str | None = None
    referral_count: int = 0
    referral_used: bool = False
    units: str = 'metric'
    created_at: str | None = None
    is_premium: bool = False
    premium_expires_at: str | None = None

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

class DeleteWorkoutRequest(BaseModel):
    workout_id: str = Field(..., min_length=1)

class LogWorkoutRequest(BaseModel):
    name: str | None = None                             # null for empty sessions not started from a routine
    date: str = Field(..., min_length=1)                # "YYYY-MM-DD"
    duration_seconds: int = Field(..., ge=0)
    exercises: list[LoggedExerciseRequest] = Field(..., min_length=1)  # must have at least one exercise
    workout_id: str | None = None                       # client-generated UUID for idempotency

class LogWorkoutResponse(BaseModel):
    workout_id: str
    xp_gained: int = 0
    new_level: int = 1
    new_exp: int = 0
    new_streak: int = 0
    best_streak: int = 0
    streak_last_date: str | None = None

class RecentWorkoutItem(BaseModel):
    workout_id: str
    name: str | None = None
    date: str
    duration_seconds: int | None = None
    created_at: str

class GetRecentWorkoutsResponse(BaseModel):
    workouts: list[RecentWorkoutItem]

class WorkoutHistoryItem(BaseModel):
    workout_id: str
    name: str | None = None
    date: str
    duration_seconds: int
    volume_kg: float
    exercise_count: int

class GetWorkoutHistoryResponse(BaseModel):
    workouts: list[WorkoutHistoryItem]

class WorkoutPrSummaryResponse(BaseModel):
    weight: int = 0
    reps: int = 0
    volume: int = 0

class WorkoutAnalyticsItem(BaseModel):
    workout_id: str
    name: str | None = None
    date: str
    duration_seconds: int
    volume_kg: float

class WorkoutAnalyticsResponse(BaseModel):
    workouts: list[WorkoutAnalyticsItem]
    primary_muscles: dict[str, int]
    secondary_muscles: dict[str, int]
    pr_counts: WorkoutPrSummaryResponse

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
    default_sets: int = 3

class CreateRoutineRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    exercises: list[RoutineExerciseItem] = Field(default_factory=list)
    estimated_duration_minutes: int | None = None

class CreateRoutineResponse(BaseModel):
    template_id: str

class GetEveryPrevSetRequest(BaseModel):
    exercise_names: list[str]

class PrevSetItem(BaseModel):
    exercise_name: str
    set_number: int
    weight_kg: float | None = None
    reps: int | None = None

class GetEveryPrevSetResponse(BaseModel):
    sets: list[PrevSetItem]

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
    exercise_id: int | None = None
    exercise_name: str
    exercise_order: int
    primary_muscle: str = ''
    secondary_muscles: list[str] = []

class MyRoutineItem(BaseModel):
    template_id: str
    name: str | None = None
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
    download_count: int = 0
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

class VerifyPurchaseRequest(BaseModel):
    purchase_token: str = Field(..., min_length=1)
    product_id: str = Field(..., min_length=1)      # e.g. "level_up_premium"
    subscription_id: str = Field(..., min_length=1) # e.g. "level_up_premium"

class PremiumStatusResponse(BaseModel):
    is_premium: bool
    premium_expires_at: str | None = None  # ISO 8601 string or null

class PremiumPerksResponse(BaseModel):
    shield_count: int
    shields_reset_at: str  # ISO 8601

class UseShieldResponse(BaseModel):
    shield_count: int       # remaining shields after use
    restored_streak: int    # the daily streak value after restoration

