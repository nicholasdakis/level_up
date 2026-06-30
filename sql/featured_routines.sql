INSERT INTO workout_templates (uid, name, is_public, estimated_duration_minutes) VALUES
(NULL, 'Bodyweight Foundations', true, 20),
(NULL, 'Beginner Full-Body Strength', true, 35),
(NULL, '15-Min Express Full Body', true, 15),
(NULL, 'Lower Body Focus', true, 40),
(NULL, 'Upper Body Push/Pull', true, 40),
(NULL, 'Full-Body Strength Circuit', true, 30),
(NULL, 'Advanced Compound Strength', true, 50),
(NULL, 'Advanced Hypertrophy Upper', true, 45),
(NULL, 'HIIT Fat Loss Circuit', true, 20);

WITH templates AS (
  SELECT template_id, name FROM workout_templates
  WHERE uid IS NULL AND is_public = true
  ORDER BY created_at DESC
  LIMIT 9
)

INSERT INTO workout_template_exercises (template_id, exercise_id, exercise_name, exercise_order)
SELECT t.template_id, 4460, 'Bodyweight Squat', 0 FROM templates t WHERE t.name = 'Bodyweight Foundations' UNION ALL
SELECT t.template_id, 4712, 'Incline Push-Up', 1 FROM templates t WHERE t.name = 'Bodyweight Foundations' UNION ALL
SELECT t.template_id, 4473, 'Butt Lift (Bridge)', 2 FROM templates t WHERE t.name = 'Bodyweight Foundations' UNION ALL
SELECT t.template_id, 4904, 'Plank', 3 FROM templates t WHERE t.name = 'Bodyweight Foundations' UNION ALL
SELECT t.template_id, 4461, 'Bodyweight Walking Lunge', 4 FROM templates t WHERE t.name = 'Bodyweight Foundations' UNION ALL

SELECT t.template_id, 4667, 'Goblet Squat', 0 FROM templates t WHERE t.name = 'Beginner Full-Body Strength' UNION ALL
SELECT t.template_id, 4587, 'Dumbbell Bench Press', 1 FROM templates t WHERE t.name = 'Beginner Full-Body Strength' UNION ALL
SELECT t.template_id, 4450, 'Bent Over Two-Dumbbell Row', 2 FROM templates t WHERE t.name = 'Beginner Full-Body Strength' UNION ALL
SELECT t.template_id, 4609, 'Dumbbell Shoulder Press', 3 FROM templates t WHERE t.name = 'Beginner Full-Body Strength' UNION ALL
SELECT t.template_id, 4904, 'Plank', 4 FROM templates t WHERE t.name = 'Beginner Full-Body Strength' UNION ALL

SELECT t.template_id, 4647, 'Freehand Jump Squat', 0 FROM templates t WHERE t.name = '15-Min Express Full Body' UNION ALL
SELECT t.template_id, 4933, 'Pushups', 1 FROM templates t WHERE t.name = '15-Min Express Full Body' UNION ALL
SELECT t.template_id, 4595, 'Dumbbell Lunges', 2 FROM templates t WHERE t.name = '15-Min Express Full Body' UNION ALL
SELECT t.template_id, 4833, 'Mountain Climbers', 3 FROM templates t WHERE t.name = '15-Min Express Full Body' UNION ALL
SELECT t.template_id, 4904, 'Plank', 4 FROM templates t WHERE t.name = '15-Min Express Full Body' UNION ALL

SELECT t.template_id, 4429, 'Barbell Squat', 0 FROM templates t WHERE t.name = 'Lower Body Focus' UNION ALL
SELECT t.template_id, 4969, 'Romanian Deadlift', 1 FROM templates t WHERE t.name = 'Lower Body Focus' UNION ALL
SELECT t.template_id, 4432, 'Barbell Walking Lunge', 2 FROM templates t WHERE t.name = 'Lower Body Focus' UNION ALL
SELECT t.template_id, 4417, 'Barbell Hip Thrust', 3 FROM templates t WHERE t.name = 'Lower Body Focus' UNION ALL
SELECT t.template_id, 5117, 'Standing Calf Raises', 4 FROM templates t WHERE t.name = 'Lower Body Focus' UNION ALL

SELECT t.template_id, 4587, 'Dumbbell Bench Press', 0 FROM templates t WHERE t.name = 'Upper Body Push/Pull' UNION ALL
SELECT t.template_id, 4450, 'Bent Over Two-Dumbbell Row', 1 FROM templates t WHERE t.name = 'Upper Body Push/Pull' UNION ALL
SELECT t.template_id, 4609, 'Dumbbell Shoulder Press', 2 FROM templates t WHERE t.name = 'Upper Body Push/Pull' UNION ALL
SELECT t.template_id, 5223, 'Wide-Grip Lat Pulldown', 3 FROM templates t WHERE t.name = 'Upper Body Push/Pull' UNION ALL
SELECT t.template_id, 4589, 'Dumbbell Bicep Curl', 4 FROM templates t WHERE t.name = 'Upper Body Push/Pull' UNION ALL
SELECT t.template_id, 5190, 'Triceps Pushdown', 5 FROM templates t WHERE t.name = 'Upper Body Push/Pull' UNION ALL

SELECT t.template_id, 4412, 'Barbell Deadlift', 0 FROM templates t WHERE t.name = 'Full-Body Strength Circuit' UNION ALL
SELECT t.template_id, 4933, 'Pushups', 1 FROM templates t WHERE t.name = 'Full-Body Strength Circuit' UNION ALL
SELECT t.template_id, 4667, 'Goblet Squat', 2 FROM templates t WHERE t.name = 'Full-Body Strength Circuit' UNION ALL
SELECT t.template_id, 4848, 'One-Arm Dumbbell Row', 3 FROM templates t WHERE t.name = 'Full-Body Strength Circuit' UNION ALL
SELECT t.template_id, 4932, 'Push Up to Side Plank', 4 FROM templates t WHERE t.name = 'Full-Body Strength Circuit' UNION ALL

SELECT t.template_id, 4429, 'Barbell Squat', 0 FROM templates t WHERE t.name = 'Advanced Compound Strength' UNION ALL
SELECT t.template_id, 4409, 'Barbell Bench Press - Medium Grip', 1 FROM templates t WHERE t.name = 'Advanced Compound Strength' UNION ALL
SELECT t.template_id, 4445, 'Bent Over Barbell Row', 2 FROM templates t WHERE t.name = 'Advanced Compound Strength' UNION ALL
SELECT t.template_id, 4424, 'Barbell Shoulder Press', 3 FROM templates t WHERE t.name = 'Advanced Compound Strength' UNION ALL
SELECT t.template_id, 4969, 'Romanian Deadlift', 4 FROM templates t WHERE t.name = 'Advanced Compound Strength' UNION ALL
SELECT t.template_id, 4525, 'Chin-Up', 5 FROM templates t WHERE t.name = 'Advanced Compound Strength' UNION ALL

SELECT t.template_id, 4709, 'Incline Dumbbell Press', 0 FROM templates t WHERE t.name = 'Advanced Hypertrophy Upper' UNION ALL
SELECT t.template_id, 4925, 'Pullups', 1 FROM templates t WHERE t.name = 'Advanced Hypertrophy Upper' UNION ALL
SELECT t.template_id, 4991, 'Seated Cable Rows', 2 FROM templates t WHERE t.name = 'Advanced Hypertrophy Upper' UNION ALL
SELECT t.template_id, 4391, 'Arnold Dumbbell Press', 3 FROM templates t WHERE t.name = 'Advanced Hypertrophy Upper' UNION ALL
SELECT t.template_id, 5030, 'Side Lateral Raise', 4 FROM templates t WHERE t.name = 'Advanced Hypertrophy Upper' UNION ALL
SELECT t.template_id, 4589, 'Dumbbell Bicep Curl', 5 FROM templates t WHERE t.name = 'Advanced Hypertrophy Upper' UNION ALL
SELECT t.template_id, 5190, 'Triceps Pushdown', 6 FROM templates t WHERE t.name = 'Advanced Hypertrophy Upper' UNION ALL

SELECT t.template_id, 4647, 'Freehand Jump Squat', 0 FROM templates t WHERE t.name = 'HIIT Fat Loss Circuit' UNION ALL
SELECT t.template_id, 4933, 'Pushups', 1 FROM templates t WHERE t.name = 'HIIT Fat Loss Circuit' UNION ALL
SELECT t.template_id, 4833, 'Mountain Climbers', 2 FROM templates t WHERE t.name = 'HIIT Fat Loss Circuit' UNION ALL
SELECT t.template_id, 4595, 'Dumbbell Lunges', 3 FROM templates t WHERE t.name = 'HIIT Fat Loss Circuit' UNION ALL
SELECT t.template_id, 4904, 'Plank', 4 FROM templates t WHERE t.name = 'HIIT Fat Loss Circuit';
