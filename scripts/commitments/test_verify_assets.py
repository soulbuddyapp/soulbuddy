"""Regression checks for the bundled, public Commitment media contract."""
import copy
import json
from pathlib import Path
import unittest

from verify_assets import ROOT, verify_catalog


class CommitmentAssetVerificationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads((ROOT / 'apps/soulbuddy/assets/audio/commitments/catalog_v1.json').read_text(encoding='utf-8'))

    def test_committed_media_passes(self):
        result = verify_catalog(self.catalog, ROOT)
        self.assertEqual(result['errors'], [])
        self.assertEqual(len(result['assets']), 8)

    def test_missing_file_fails(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['assets'][0]['path'] = 'assets/audio/commitments/missing.wav'
        self.assertTrue(verify_catalog(catalog, ROOT)['errors'])

    def test_corrupt_checksum_fails(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['assets'][0]['sha256'] = '0' * 64
        self.assertIn('readiness_v1: checksum', verify_catalog(catalog, ROOT)['errors'])

    def test_overlapping_captions_fail(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['assets'][0]['captions'][1]['startMs'] = 0
        self.assertIn('readiness_v1: captions', verify_catalog(catalog, ROOT)['errors'])

    def test_changed_reviewed_text_fails(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['assets'][0]['transcript'] = 'Unreviewed substitute text.'
        self.assertIn('readiness_v1: approved text', verify_catalog(catalog, ROOT)['errors'])

    def test_wrong_excerpt_interval_fails(self):
        catalog = copy.deepcopy(self.catalog)
        music = next(a for a in catalog['assets'] if a['id'] == 'aphelion_excerpt_v1')
        music['provenance']['sourceIntervalSeconds'] = [104, 134]
        self.assertIn('aphelion_excerpt_v1: source interval', verify_catalog(catalog, ROOT)['errors'])

    def test_mismatched_notification_copy_fails(self):
        catalog = copy.deepcopy(self.catalog)
        voice = next(a for a in catalog['assets'] if a['id'] == 'spoken_invitation_v1')
        voice['platformCopies'][0] = 'apps/soulbuddy/assets/audio/commitments/readiness_v1.wav'
        self.assertIn('spoken_invitation_v1: platform identity', verify_catalog(catalog, ROOT)['errors'])

    def test_path_escape_fails_without_leaking_path(self):
        catalog = copy.deepcopy(self.catalog)
        catalog['assets'][0]['path'] = '../private-secret.wav'
        errors = verify_catalog(catalog, ROOT)['errors']
        self.assertIn('readiness_v1: path', errors)
        self.assertNotIn('private-secret', str(errors))


if __name__ == '__main__':
    unittest.main()
