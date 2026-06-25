-- Migration script: food_logs (JSONB per day) -> food_logs_v2 (one row per food item)

INSERT INTO food_logs_v2 (
    uid, date, meal,
    food_name, brand_name, food_description,
    calories, protein, carbs, fat,
    serving_size, logged_at
)
SELECT
    fl.uid,
    fl.date,
    meals.meal_name,
    (item->>'food_name')::TEXT,
    (item->>'brand_name')::TEXT,
    (item->>'food_description')::TEXT,
    (item->>'calories')::INTEGER,
    (regexp_match(item->>'food_description', 'Protein:\s*([\d.]+)'))[1]::NUMERIC,
    (regexp_match(item->>'food_description', 'Carbs:\s*([\d.]+)'))[1]::NUMERIC,
    (regexp_match(item->>'food_description', 'Fat:\s*([\d.]+)'))[1]::NUMERIC,
    (regexp_match(item->>'food_description', 'Per\s+(.+?)\s*-'))[1]::TEXT,
    (fl.date::TIMESTAMPTZ + INTERVAL '12 hours')
FROM food_logs fl
CROSS JOIN LATERAL (
    VALUES
        ('breakfast', fl.breakfast),
        ('lunch',     fl.lunch),
        ('dinner',    fl.dinner),
        ('snacks',    fl.snack)
) AS meals(meal_name, items)
CROSS JOIN LATERAL unnest(meals.items) AS item
WHERE item IS NOT NULL
  AND (item->>'food_name') IS NOT NULL;
