from redis import Redis
import os

# Constants
FOOD_CACHE_TTL = 2592000  # 30 days in seconds

redis = Redis(
    host=os.environ.get("REDIS_URL"),
    port=6379,
    password=os.environ.get("REDIS_TOKEN"),
    ssl=True # Upstash requires encrypted connections
)