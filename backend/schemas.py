# Validation Layer: Pydantic models define the shape of every request / response
# Incoming JSON is parsed into these models before any business logic, and if the data doesn't match, the request is rejected with a clear error message
from pydantic import BaseModel, Field

# Request schemas

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

# Response schemas

class DailyRewardResponse(BaseModel):
    # What is returned when the user tries to claim a daily reward
    claimed: bool # true if successfully claimed
    xp_gained: int = 0
    new_level: int = 1
    new_exp: int = 0
    seconds_remaining: int = 0


class ProgressResponse(BaseModel):
    # What is returned when Flutter requests the user's current progress (level, XP, and reward status)
    # Read by the client to display the XP bar, level, and whether the daily reward button should be enabled, without giving direct Firestore read access to sensitive fields
    level: int = 1
    exp_points: int = 0
    exp_needed: int = 100
    can_claim_daily_reward: bool = True

class UpdateExpResponse(BaseModel):
    new_level: int | None = None
    new_exp: int | None = None
    error: str | None = None
