from redis import Redis
import os

# Constants
FOOD_CACHE_TTL = 2592000  # 30 days in seconds

redis = Redis.from_url(
    os.environ.get("REDIS_URL"),
    password=os.environ.get("REDIS_TOKEN"),
    ssl=True # Upstash requires encrypted connections
)