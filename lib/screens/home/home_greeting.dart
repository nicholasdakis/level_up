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
  ];

  final timeSlot = <(String, bool)>[];
  if (hour < 5) {
    timeSlot.addAll([
      ("STILL UP", true),
      ("LATE NIGHT GRIND", false),
      ("UP LATE", true),
      ("CAN'T SLEEP", true),
      ("STILL AWAKE", true),
    ]);
  } else if (hour < 12) {
    timeSlot.addAll([
      ("GOOD MORNING", false),
      ("RISE & SHINE", false),
      ("MORNING", false),
      ("HOW'S IT GOING", true),
      ("UP EARLY", true),
      ("GOOD TO SEE YOU", false),
    ]);
  } else if (hour < 17) {
    timeSlot.addAll([
      ("GOOD AFTERNOON", false),
      ("AFTERNOON", false),
      ("KEEP IT UP", false),
      ("HOW'S THE DAY GOING", true),
      ("STAYING FOCUSED", true),
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
    ]);
  }

  final pool = [...timeSlot, ...universal];
  final (base, isQ) = pool[rng.nextInt(pool.length)];
  return (greeting: "$base,", isQuestion: isQ);
}
