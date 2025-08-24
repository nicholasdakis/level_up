import os
from dotenv import load_dotenv
from datetime import datetime, timedelta

load_dotenv()
MAX_TOKENS = int(os.getenv("MAX_TOKENS", 5000))

class TokenManager:
    def __init__(self):
        self.current_tokens = MAX_TOKENS
        self.last_refill = datetime.now()

    def refill(self):
        # refill logic based on time
        if datetime.now() - self.last_refill >= timedelta(days=1):
            self.current_tokens = MAX_TOKENS
            self.last_refill = datetime.now()

    def consume(self, amount=1):
        self.refill()
        if self.current_tokens >= amount:
            self.current_tokens -= amount
            return True
        return False