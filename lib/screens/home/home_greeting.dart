import 'dart:math';

// Builds a greeting based on time of day plus a random variant from that pool.
// Returns the greeting text (with trailing comma) and whether it's phrased as
// a question, so the caller can pick the right trailing punctuation.
({String greeting, bool isQuestion}) buildGreeting() {
  final hour = DateTime.now().hour;
  final rng = Random();

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
  final (base, isQ) = pool[rng.nextInt(pool.length)];
  return (greeting: "$base,", isQuestion: isQ);
}
