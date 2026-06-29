from backend.repository import WorkoutRepository


class WorkoutService:
    def __init__(self, repo: WorkoutRepository):
        self._repo = repo

    def search_exercises(self, q: str, equipment: list[str], muscle: list[str], level: list[str]) -> list[dict]:
        return self._repo.search_exercises(q=q, equipment=equipment, muscle=muscle, level=level)
