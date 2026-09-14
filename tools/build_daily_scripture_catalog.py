"""Build the shared daily selection from SoulBuddy's existing scripture source."""
import json
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
READINGS = [
    ('1 Cor', 10, 13, 13), ('Phil', 2, 13, 13), ('1 Tim', 4, 7, 8),
    ('Luke', 16, 10, 10), ('Phil', 2, 3, 4), ('Eph', 4, 32, 32), ('Gal', 6, 9, 10),
    ('Matt', 26, 41, 41), ('2 Cor', 12, 9, 9), ('1 Cor', 9, 24, 25),
    ('Col', 3, 23, 24), ('James', 4, 10, 10), ('Col', 3, 13, 14), ('John', 15, 4, 5),
    ('Rom', 13, 14, 14), ('Heb', 4, 16, 16), ('Heb', 12, 1, 2),
    ('Matt', 6, 34, 34), ('Mic', 6, 8, 8), ('Luke', 6, 36, 36), ('Gal', 5, 22, 23),
    ('James', 4, 7, 8), ('Eph', 2, 8, 10), ('2 Pet', 1, 5, 7),
    ('Gal', 6, 2, 2), ('John', 13, 14, 15), ('Rom', 12, 21, 21), ('Matt', 5, 16, 16),
]
THEMES = [
    ('Guard the gate', 'What access makes temptation easier, and what boundary can I strengthen today?',
     'Lord, give me courage to close the gate to what harms my soul and choose what is good. Amen.',
     'Remove one easy path to a temptation today.', 'guard-the-gate'),
    ('Cooperate with grace', 'Where is God inviting my willing effort today?',
     'Lord, I receive your grace. Strengthen my willingness to act with love. Amen.',
     'Pause for prayer before one difficult decision.', 'strength-for-today'),
    ('Train in faithfulness', 'Which small discipline would make my love more dependable?',
     'Lord, train my heart in faithfulness, with patience for steady growth. Amen.',
     'Give five undistracted minutes to prayer.', 'strength-for-today'),
    ('Strength for today', 'What responsibility can I carry faithfully with the strength I have today?',
     'Lord, give me a task I can carry today, and the grace to give it my best. Amen.',
     'Finish one manageable act of care or duty today.', 'strength-for-today'),
    ('Walk humbly', 'Where can I listen before seeking my own way?',
     'Jesus, form a humble and teachable heart in me. Amen.',
     'Listen to someone without interrupting or seeking credit.', 'strength-for-today'),
    ('Practice mercy', 'What response would make room for mercy today?',
     'Father, help me receive your mercy and respond to others with kindness. Amen.',
     'Choose one kind response where resentment would be easier.', 'strength-for-today'),
    ('Bear good fruit', 'Who needs a practical expression of love from me today?',
     'Holy Spirit, let your love bear good fruit through my ordinary choices. Amen.',
     'Offer one practical act of help without seeking recognition.', 'strength-for-today'),
]

db = sqlite3.connect(f'file:{(ROOT / "apps/soulbuddy/assets/scripture/rsvce.db").as_posix()}?mode=ro', uri=True)
catalog = []
for index, (book, chapter, first, last) in enumerate(READINGS):
    found = db.execute('SELECT _id,text FROM books WHERE lower(shortname)=lower(?)', (book,)).fetchone()
    if not found:
        raise ValueError(f'Unknown book: {book}')
    verses = db.execute('SELECT verse_id,text FROM verses WHERE book_id=? AND chapter_id=? AND verse_id BETWEEN ? AND ? ORDER BY verse_id', (found[0], chapter, first, last)).fetchall()
    assert len(verses) == last - first + 1, (book, chapter, first, last)
    theme, reflection, prayer, practice, precept = THEMES[index % len(THEMES)]
    catalog.append(dict(id=f'daily-{index+1:02}', book=book, chapter=chapter,
                        first_verse=first, last_verse=last,
                        reference=f'{found[1].strip()} {chapter}:{first}' + (f'–{last}' if last != first else ''),
                        text=' '.join(v[1].strip() for v in verses), translation='RSVCE',
                        theme=theme, reflection=reflection, prayer=prayer, practice=practice, precept=precept))
db.close()
encoded = json.dumps(catalog, ensure_ascii=False, indent=2) + '\n'
for target in ['services/api/resources/scripture/daily_scriptures.json', 'apps/soulbuddy/assets/content/daily_scriptures.json']:
    path = ROOT / target
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(encoded, encoding='utf-8')
print(f'Built {len(catalog)} verified scripture selections.')
