import 'package:flutter/foundation.dart';

@immutable
class FormationReading {
  const FormationReading({
    required this.id,
    required this.theme,
    required this.book,
    required this.chapter,
    required this.firstVerse,
    required this.lastVerse,
    required this.reference,
    required this.supportingReferences,
    required this.meditation,
    required this.prayer,
    required this.practice,
  });

  final String id;
  final String theme;
  final String book;
  final int chapter;
  final int firstVerse;
  final int lastVerse;
  final String reference;
  final List<String> supportingReferences;
  final String meditation;
  final String prayer;
  final String practice;
}

const formationReadings = <FormationReading>[
  FormationReading(
    id: 'effects-of-sin',
    theme: 'Effects of sin and denouncing sin',
    book: 'Rom',
    chapter: 6,
    firstVerse: 12,
    lastVerse: 14,
    reference: 'Romans 6:12–14',
    supportingReferences: ['Psalm 51:1–12', 'Mark 7:20–23'],
    meditation:
        'Where have I left an opening for sin, and what can I remove today?',
    prayer:
        'Jesus, give me courage to name what harms me and grace to turn away from it.',
    practice: 'Name and remove one opening for sin.',
  ),
  FormationReading(
    id: 'overcoming-sin',
    theme: 'Overcoming sin in Christ',
    book: 'Rom',
    chapter: 8,
    firstVerse: 1,
    lastVerse: 14,
    reference: 'Romans 8:1–14',
    supportingReferences: ['1 Corinthians 10:12–13', '1 John 1:5–9'],
    meditation: 'What hopeful next step can I take after a fall?',
    prayer: 'Jesus, teach me to rise in your mercy and walk by your Spirit.',
    practice: 'Choose one hopeful next step after a fall.',
  ),
  FormationReading(
    id: 'holy-spirit',
    theme: 'Holy Spirit and kingdom righteousness',
    book: 'Gal',
    chapter: 5,
    firstVerse: 16,
    lastVerse: 25,
    reference: 'Galatians 5:16–25',
    supportingReferences: ['John 14:15–27', 'Matthew 6:31–34'],
    meditation: 'Which fruit of the Spirit needs room to grow in me?',
    prayer: 'Holy Spirit, quiet my noise and guide my next decision.',
    practice: 'Pause, pray, and listen before one decision.',
  ),
  FormationReading(
    id: 'gods-purpose',
    theme: 'God’s purpose in our lives',
    book: 'Eph',
    chapter: 2,
    firstVerse: 8,
    lastVerse: 10,
    reference: 'Ephesians 2:8–10',
    supportingReferences: ['Jeremiah 1:4–8', 'Romans 12:1–8'],
    meditation: 'What gift has God placed in my hands for someone else?',
    prayer: 'Father, show me the good work you have prepared for me today.',
    practice: 'Use one entrusted gift in service.',
  ),
  FormationReading(
    id: 'discipline',
    theme: 'Practicing discipline',
    book: '1 Cor',
    chapter: 9,
    firstVerse: 24,
    lastVerse: 27,
    reference: '1 Corinthians 9:24–27',
    supportingReferences: ['Proverbs 4:20–27', 'Hebrews 12:1–11'],
    meditation: 'Which small practice would make my love more dependable?',
    prayer: 'Lord, strengthen me to keep choosing what is good.',
    practice: 'Keep one small faithful practice today.',
  ),
  FormationReading(
    id: 'understanding-humility',
    theme: 'Understanding humility',
    book: 'Phil',
    chapter: 2,
    firstVerse: 3,
    lastVerse: 11,
    reference: 'Philippians 2:3–11',
    supportingReferences: ['Luke 14:7–14', 'Romans 12:3–5'],
    meditation: 'Can I receive my gifts with gratitude and without comparison?',
    prayer: 'Jesus, form your humble heart in me.',
    practice: 'Give thanks for a gift without self-display.',
  ),
  FormationReading(
    id: 'practicing-humility',
    theme: 'Practicing humility',
    book: 'John',
    chapter: 13,
    firstVerse: 1,
    lastVerse: 17,
    reference: 'John 13:1–17',
    supportingReferences: ['Micah 6:6–8', '1 Peter 5:5–7'],
    meditation: 'Whose burden can I quietly make lighter?',
    prayer: 'Jesus, teach me to serve as you served.',
    practice: 'Do one useful act of service quietly.',
  ),
  FormationReading(
    id: 'forgiveness',
    theme: 'Forgiveness',
    book: 'Matt',
    chapter: 18,
    firstVerse: 21,
    lastVerse: 35,
    reference: 'Matthew 18:21–35',
    supportingReferences: ['Luke 15:11–32', 'Colossians 3:12–15'],
    meditation: 'What resentment needs honest prayer and a safe next step?',
    prayer:
        'Merciful God, heal what is wounded and lead me toward wise repair.',
    practice: 'Pray honestly and choose a safe act of repair.',
  ),
  FormationReading(
    id: 'charity',
    theme: 'Charity',
    book: '1 Cor',
    chapter: 13,
    firstVerse: 1,
    lastVerse: 13,
    reference: '1 Corinthians 13:1–13',
    supportingReferences: ['Luke 10:25–37', '1 John 4:7–12'],
    meditation: 'Who needs love from me in a concrete form today?',
    prayer:
        'God of love, make my words and actions patient, truthful, and kind.',
    practice: 'Meet one concrete need with love.',
  ),
  FormationReading(
    id: 'justice',
    theme: 'Justice',
    book: 'Isa',
    chapter: 58,
    firstVerse: 6,
    lastVerse: 12,
    reference: 'Isaiah 58:6–12',
    supportingReferences: ['Amos 5:21–24', 'Matthew 25:31–40'],
    meditation: 'What unfairness is close enough for me to address?',
    prayer:
        'God of justice, open my eyes and steady my hands for what is right.',
    practice: 'Correct one unfairness within reach.',
  ),
  FormationReading(
    id: 'faith',
    theme: 'Faith',
    book: 'Heb',
    chapter: 11,
    firstVerse: 1,
    lastVerse: 16,
    reference: 'Hebrews 11:1–16',
    supportingReferences: ['Mark 9:14–29', 'James 2:14–26'],
    meditation: 'What truth is asking for my trust in action?',
    prayer:
        'Faithful God, help me take the next step even before I see the whole road.',
    practice: 'Act on one truth entrusted to you.',
  ),
  FormationReading(
    id: 'bearing-fruit',
    theme: 'Bearing fruit',
    book: 'John',
    chapter: 15,
    firstVerse: 1,
    lastVerse: 17,
    reference: 'John 15:1–17',
    supportingReferences: ['Galatians 5:22–25', 'Matthew 7:15–20'],
    meditation: 'What good seed can I plant and faithfully tend?',
    prayer:
        'Jesus, keep me close to you so that love can grow through my life.',
    practice: 'Plant something good in the garden today.',
  ),
  FormationReading(
    id: 'helping-others',
    theme: 'Helping others spiritually',
    book: '2 Tim',
    chapter: 2,
    firstVerse: 1,
    lastVerse: 7,
    reference: '2 Timothy 2:1–7',
    supportingReferences: ['Matthew 28:16–20', 'James 5:19–20'],
    meditation: 'Who can I encourage without pressure or pride?',
    prayer:
        'Lord, make me patient, faithful, and useful in another person’s journey.',
    practice: 'Encourage one person toward a faithful next step.',
  ),
];
