from upstash_redis import Redis
import os

# Constants
FOOD_CACHE_TTL = 2592000  # 30 days in seconds

redis = Redis(
    url=os.environ.get("REDIS_URL"),
    token=os.environ.get("REDIS_TOKEN")
)