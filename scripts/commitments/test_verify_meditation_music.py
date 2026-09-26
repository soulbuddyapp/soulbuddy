"""Regression checks for the curated recording verifier."""
import copy
import unittest
from unittest.mock import patch

import numpy as np

import verify_meditation_music as music


class MusicVerificationTests(unittest.TestCase):
    def test_rejects_silence_and_simple_tone_placeholders(self):
        rate = 8000
        t = np.arange(rate * 4) / rate
        for signal in [np.zeros_like(t), np.sin(2 * np.pi * 220 * t) * 0.03]:
            with self.assertRaises(ValueError):
                music.signal_metrics(np.column_stack([signal, signal]), rate)

    def test_detects_broken_repeat_boundary(self):
        rng = np.random.default_rng(4)
        signal = rng.normal(0, 0.015, (32000, 2))
        signal[0] = 0.1
        signal[-1] = -0.1
        with self.assertRaisesRegex(ValueError, 'seam'):
            music.signal_metrics(signal, 8000)

    def test_metadata_requires_official_license_credit_and_distinct_sources(self):
        rows = music.load_manifest()
        music.validate_manifest(rows)
        for field, value in [('license', 'royalty free'), ('artist', 'SoulBuddy'), ('source_url', 'https://example.com/unverified.mp3'), ('changes', '')]:
            changed = copy.deepcopy(rows)
            changed[0][field] = value
            with self.assertRaises(ValueError):
                music.validate_manifest(changed)
        changed = copy.deepcopy(rows)
        changed[1]['source_sha256'] = changed[0]['source_sha256']
        with self.assertRaisesRegex(ValueError, 'distinct'):
            music.validate_manifest(changed)

    def test_every_packaged_recording_matches_provenance_and_audio_checks(self):
        reports = music.verify()
        self.assertEqual(len(reports), 5)
        for report in reports:
            self.assertGreaterEqual(report['duration_seconds'], 90)
            self.assertLessEqual(report['duration_seconds'], 120)
            self.assertGreaterEqual(report['integrated_lufs'], -21)
            self.assertLessEqual(report['integrated_lufs'], -19)

    def test_replacement_without_updated_provenance_is_rejected(self):
        rows = music.load_manifest()
        rows[0]['sha256'] = '0' * 64
        with patch.object(music, 'load_manifest', return_value=rows):
            with self.assertRaisesRegex(ValueError, 'checksum/provenance'):
                music.verify()

    def test_nature_generator_cannot_overwrite_licensed_recordings(self):
        generator = (music.ROOT / 'scripts/generate_meditation_soundscapes.py').read_text()
        for filename in music.RECORDINGS:
            self.assertNotIn(filename.removesuffix('.mp3'), generator)


if __name__ == '__main__':
    unittest.main()
