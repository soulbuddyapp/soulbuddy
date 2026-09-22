class GoalScriptureResponse {
  const GoalScriptureResponse({
    required this.key,
    required this.label,
    required this.reference,
    required this.book,
    required this.chapter,
    required this.practice,
  });

  final String key;
  final String label;
  final String reference;
  final String book;
  final int chapter;
  final String practice;
}

const goalScriptureResponses = <GoalScriptureResponse>[
  GoalScriptureResponse(
    key: 'sexual-temptation',
    label: 'Sexual temptation',
    reference: '1 Corinthians 6:18–20',
    book: 'I Corinthians',
    chapter: 6,
    practice: 'Honor God with your body; remove easy access to the trigger.',
  ),
  GoalScriptureResponse(
    key: 'anger',
    label: 'Anger',
    reference: 'James 1:19–20',
    book: 'James',
    chapter: 1,
    practice: 'Listen first; give your reply time to become gentle and true.',
  ),
  GoalScriptureResponse(
    key: 'fear',
    label: 'Fear',
    reference: '2 Timothy 1:7',
    book: 'II Timothy',
    chapter: 1,
    practice: 'Ask for courage, love, and sound judgment.',
  ),
  GoalScriptureResponse(
    key: 'pride',
    label: 'Pride',
    reference: 'Philippians 2:3–5',
    book: 'Philippians',
    chapter: 2,
    practice: 'Choose one humble act of service.',
  ),
  GoalScriptureResponse(
    key: 'discouragement',
    label: 'Discouragement',
    reference: 'Romans 8:1–2',
    book: 'Romans',
    chapter: 8,
    practice: 'Receive mercy and take the next faithful step.',
  ),
  GoalScriptureResponse(
    key: 'idleness',
    label: 'Idleness',
    reference: 'Colossians 3:23',
    book: 'Colossians',
    chapter: 3,
    practice: 'Begin one honest task with care.',
  ),
];

GoalScriptureResponse? goalScriptureResponseForKey(String? key) {
  for (final response in goalScriptureResponses) {
    if (response.key == key) return response;
  }
  return null;
}
