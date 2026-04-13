# Validation Layer: Pydantic models define the shape of every request / response
# Incoming JSON is parsed into these models before any business logic, and if the data doesn't match, the request is rejected with a clear error message
from pydantic import BaseModel, Field

# Request schemas --------------

class ClaimDailyRewardRequest(BaseModel):
    # Sent by Flutter when the user tries to claim their daily reward
    id_token: str = Field(
        ...,  # ... means the token is required
        min_length=1, # token can't be empty
        description="Firebase Auth ID token for verifying the user's identity",
    )

class GetProgressRequest(BaseModel):
    # Sent by Flutter when it wants to fetch the user's current XP, level, and reward status (on app startup)
    id_token: str = Field(
        ..., # required
        min_length=1, # non-empty
        description="Firebase Auth ID token for verifying the user's identity",
    )

class UpdateExpRequest(BaseModel):
    id_token: str = Field(..., min_length=1)
    event: str = Field(..., min_length=1)
    event_id: str = Field(..., min_length=1)

class UpdateUsernameRequest(BaseModel):
    id_token: str = Field(..., min_length=1)
    username: str = Field(..., min_length=1, max_length=20)

class SearchFoodRequest(BaseModel):
    id_token: str = Field(..., min_length=1)
    food_name: str = Field(..., min_length=1)

class NearbyPOIRequest(BaseModel):
    # Sent by Flutter when the user opens the Explore screen and needs nearby points of interest
    id_token: str = Field(..., min_length=1)
    lat: float = Field(..., ge=-90, le=90, description="User's latitude") # ge/le constrain to valid coordinate range
    lng: float = Field(..., ge=-180, le=180, description="User's longitude") # same for longitude

class CheckInPOIRequest(BaseModel):
    # Sent by Flutter when the user taps the Check In button near a POI
    id_token: str = Field(..., min_length=1)
    poi_name: str = Field(..., min_length=1) # name of the POI the user wants to check into
    poi_lat: float = Field(..., ge=-90, le=90) # latitude of the POI
    poi_lng: float = Field(..., ge=-180, le=180) # longitude of the POI
    user_lat: float = Field(..., ge=-90, le=90) # user's current latitude (verified server-side)
    user_lng: float = Field(..., ge=-180, le=180) # user's current longitude

class GetUserDataRequest(BaseModel):
    id_token: str = Field(..., min_length=1)

class UpdatePfpRequest(BaseModel):
    id_token: str = Field(..., min_length=1)
    pfp_base64: str = Field(..., min_length=1)

class UpdateAppColorRequest(BaseModel):
    id_token: str = Field(..., min_length=1)
    app_color: int  # stored as ARGB bigint, matching Flutter's Color.toARGB32()

class UpdateNotificationsRequest(BaseModel):
    id_token: str = Field(..., min_length=1)
    enabled: bool

class AddFcmTokenRequest(BaseModel):
    id_token: str = Field(..., min_length=1)
    token: str = Field(..., min_length=1)

class RemoveFcmTokenRequest(BaseModel):
    id_token: str = Field(..., min_length=1)
    token: str = Field(..., min_length=1)

class UpsertFoodLogRequest(BaseModel):
    id_token: str = Field(..., min_length=1)
    date: str = Field(..., min_length=1)  # e.g. "2025-04-13"
    breakfast: list = []
    lunch: list = []
    dinner: list = []
    snack: list = []

# Response schemas --------------------

class DailyRewardResponse(BaseModel):
    # What is returned when the user tries to claim a daily reward
    claimed: bool # true if successfully claimed
    xp_gained: int = 0
    new_level: int = 1
    new_exp: int = 0
    seconds_remaining: int = 0


class ProgressResponse(BaseModel):
    # What is returned when Flutter requests the user's current progress (level, XP, and reward status)
    # Read by the client to display the XP bar, level, and whether the daily reward button should be enabled, without giving direct Postgres read access to sensitive fields
    level: int = 1
    exp_points: int = 0
    exp_needed: int = 100
    can_claim_daily_reward: bool = True

class UpdateExpResponse(BaseModel):
    new_level: int | None = None
    new_exp: int | None = None
    error: str | None = None

class UpdateUsernameResponse(BaseModel):
    success: bool
    error: str | None = None

class POIItem(BaseModel):
    # A single point of interest returned from Overpass
    name: str # display name of the place (e.g. "Starbucks")
    lat: float # latitude of the POI
    lng: float # longitude of the POI
    category: str # the OSM tag category (e.g. "cafe", "park", "gym")

class NearbyPOIResponse(BaseModel):
    # The full response containing a list of nearby POIs
    pois: list[POIItem] = [] # list of POI items, empty by default if none found

class CheckInPOIResponse(BaseModel):
    # What is returned after a check-in attempt
    success: bool # true if the check-in went through
    xp_gained: int = 0 # how much XP was awarded
    new_level: int = 1 # user's level after XP is applied
    new_exp: int = 0 # user's XP after the award
    error: str | None = None # reason for failure if success is false

class GetUserDataResponse(BaseModel):
    level: int = 1
    exp_points: int = 0
    exp_needed: int = 100
    can_claim_daily_reward: bool = True
    pfp_base64: str | None = None
    username: str
    app_color: int | None = None
    fcm_tokens: list[str] = []
    notifications_enabled: bool = True
    last_daily_claim: str | None = None  # ISO string
    food_logs: list = []
    reminders: list = []

class SimpleSuccessResponse(BaseModel):
    # Reusable for routes that just need to confirm success
    success: bool
    error: str | None = None