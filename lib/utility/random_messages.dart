import 'dart:math';

final _rng = Random();

String _pick(List<String> list) => list[_rng.nextInt(list.length)];

({String greeting, bool isQuestion}) generateHomeGreeting() {
  final hour = DateTime.now().hour;

  const universal = [
    ("BACK FOR MORE", true),
    ("WHAT'S ON TODAY'S AGENDA", true),
    ("MAKING MOVES", false),
    ("LET'S GET IT", false),
    ("HOW'S EVERYTHING GOING", true),
    ("READY TO LEVEL UP", true),
    ("WELCOME BACK", false),
    ("STAYING CONSISTENT", true),
    ("ON A ROLL", false),
    ("KEEP PUSHING", false),
    ("WHAT ARE WE WORKING ON", true),
    ("GOOD TO HAVE YOU BACK", false),
    ("GOOD TO SEE YOU", false),
    ("CRUSHING IT", false),
    ("LET'S SEE WHAT YOU'VE GOT", true),
  ];

  final timeSlot = <(String, bool)>[];
  if (hour < 5) {
    timeSlot.addAll([
      ("STILL UP", true),
      ("LATE NIGHT GRIND", false),
      ("UP LATE", true),
      ("CAN'T SLEEP", true),
      ("STILL AWAKE", true),
      ("NIGHT MODE ACTIVATED", false),
    ]);
  } else if (hour < 12) {
    timeSlot.addAll([
      ("GOOD MORNING", false),
      ("RISE & SHINE", false),
      ("MORNING", false),
      ("HOW'S IT GOING", true),
      ("UP EARLY", true),
      ("GOOD TO SEE YOU", false),
      ("STARTING STRONG", false),
      ("EARLY BIRD", false),
      ("FRESH START", false),
      ("MORNING GRIND", false),
    ]);
  } else if (hour < 17) {
    timeSlot.addAll([
      ("GOOD AFTERNOON", false),
      ("AFTERNOON", false),
      ("KEEP IT UP", false),
      ("HOW'S THE DAY GOING", true),
      ("STAYING FOCUSED", true),
      ("HALFWAY THROUGH", false),
      ("STILL GOING STRONG", false),
      ("POWERING THROUGH", false),
    ]);
  } else if (hour < 21) {
    timeSlot.addAll([
      ("GOOD EVENING", false),
      ("EVENING", false),
      ("WINDING DOWN", true),
      ("HOW WAS YOUR DAY", true),
      ("GOOD TO SEE YOU", false),
    ]);
  } else {
    timeSlot.addAll([
      ("UP LATE", true),
      ("NIGHT OWL", false),
      ("STILL GOING", true),
      ("CAN'T SLEEP", true),
      ("LATE NIGHT HUSTLE", false),
    ]);
  }

  final pool = [...timeSlot, ...universal];
  final (base, isQ) = pool[_rng.nextInt(pool.length)];
  return (greeting: '$base,', isQuestion: isQ);
}

String generateWorkoutEmptyHeadlineMessage() => _pick([
  'Add an Exercise',
  'Build Your Workout',
  'Start Something',
  'What Are We Training?',
  'Ready When You Are',
  'Pick Your First Move',
  'Let\'s Get to Work',
]);

String generateWorkoutEmptySubtitleMessage() => _pick([
  'Tap the button below to add your first exercise.',
  'Search or browse exercises to get started.',
  'Add exercises to start tracking your session.',
  'No exercises yet. Build your session below.',
  'Every great workout starts with one exercise.',
]);

String generateMealEmptyMessage() => _pick([
  'Nothing logged yet',
  'No foods here yet',
  'This meal is empty',
  'Looks empty here',
  'Nothing here yet',
]);

String generateRecentFoodsEmptyMessage() => _pick([
  'Nothing logged recently',
  'No recent foods yet',
  'Start logging to build your history',
  'Your recent foods will show up here',
  'Log a food to see it here',
]);

String generateSuggestedFoodsEmptyMessage() => _pick([
  'Nothing suggested yet. Try logging more foods first.',
  'Log more foods to unlock suggestions.',
  'No suggestions yet. Keep logging to see patterns.',
  'Suggestions appear after a few days of logging.',
  'Keep logging and suggestions will show up here.',
]);

String generateRemindersEmptyHeadlineMessage() => _pick([
  'No upcoming reminders',
  'Nothing scheduled yet',
  'All clear',
  'No reminders set',
  'Your schedule is open',
]);

String generateRemindersEmptySubtitleMessage() => _pick([
  'Type a message above and tap the time row to set one.',
  'Set a reminder above to see it here.',
  'Add your first reminder to stay on track.',
  'Reminders you set will appear here.',
  'Nothing scheduled. Add one above.',
]);

String generateDailyRewardReadyMessage() => _pick([
  'Daily reward ready!',
  'Your XP is waiting!',
  'Claim your reward!',
  'Free XP available!',
  'Today\'s reward is here!',
  'Don\'t miss your reward!',
  'Tap to claim your XP!',
]);

String generateDailyRewardClaimedMessage() => _pick([
  'Daily reward claimed!',
  'XP collected for today!',
  'Come back tomorrow!',
  'See you tomorrow!',
  'Reward claimed. Great job!',
  'All done for today!',
]);

// Generates a random reminder placeholder message using grammar rules to make them more natural and less repetitive
String generateReminderPlaceholderMessage() {
  final now = DateTime.now();
  // Get the user's time for more personalized messages (e.g. "before 8 PM" instead of "soon")
  final nextHour = (now.hour + 1) % 24;
  final displayHour = nextHour > 12
      ? nextHour - 12
      : (nextHour == 0 ? 12 : nextHour);
  final amPm = nextHour >= 12 ? 'PM' : 'AM';
  final dynamicTime = 'before $displayHour $amPm';

  const tasks = [
    'Go for a walk',
    'Drink water',
    'Log a snack',
    'Stay hydrated',
    'Go to the gym',
    'Train chest',
    'Train legs',
    'Train back',
    'Train shoulders',
    'Hit the gym',
    'Do some cardio',
    'Go for a run',
    'Start a workout',
    'Log a workout',
    'Stretch for 10 minutes',
    'Study for my exam',
    'Finish a task',
    'Meditate for a few minutes',
    'Go outside for some fresh air',
    'Walk the dog',
    'Share Level Up! with my friends',
    'Use the Explore tab to get some steps in',
    'Log my meals for the day',
    'Hit my protein goal',
    'Hit my calorie goal',
    'Log my water intake',
    'Weigh myself',
    'Claim my daily reward',
    'Check my progress on the leaderboards',
    'Take a rest day and recover',
    'Prep my meals for tomorrow',
  ];

  final timeOptions = [
    dynamicTime,
    'before midnight',
    'today',
    'soon',
    'now',
    '',
  ];
  const extras = [
    'to stay on track',
    'like a pro',
    'before it gets too late',
    'and keep the streak alive',
    'to hit my goals',
    '',
  ];
  const punctuation = [
    '.',
    '!',
    '. 🙂',
    '! 💪',
    '! ⚡️',
    '. ✅',
    '! 🚀',
    '. ✨',
    '! 💯',
    '. 🎯',
    '! 🔥',
    ' 🌊',
    ' 🙌',
    '',
  ];

  // randomly construct the message
  final task = _pick(tasks);
  final time = _pick(timeOptions);
  final extra = _pick(extras);
  final punct = _pick(punctuation);

  final parts = [task];
  if (time.isNotEmpty) parts.add(time);
  if (extra.isNotEmpty) parts.add(extra);
  return parts.join(' ') + punct;
}
