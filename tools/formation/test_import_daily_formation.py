import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from import_daily_formation import build_catalog, write_outputs


ROOT = Path(__file__).resolve().parents[2]
BOOK = ROOT / "content" / "formation" / "SoulBuddy_Daily_Video_Progression_v3.xlsx"


class FormationImportTest(unittest.TestCase):
    def test_builds_complete_clean_catalog(self):
        catalog = build_catalog(BOOK)

        self.assertEqual(1, catalog["version"])
        self.assertEqual(45, len(catalog["videos"]))
        self.assertEqual(
            [
                {
                    "id": "R001",
                    "title": "Sexual integrity support",
                    "youtubeId": "aFyQT1bwacQ",
                },
                {
                    "id": "R002",
                    "title": "Renewal support",
                    "youtubeId": "zfQL-WIWKSU",
                },
            ],
            [
                {key: resource[key] for key in ("id", "title", "youtubeId")}
                for resource in catalog.get("resources", [])
            ],
        )
        self.assertEqual(10, len(catalog["packs"]))
        self.assertEqual(70, len(catalog["days"]))
        self.assertEqual("A Plentiful Harvest", catalog["packs"][0]["title"])
        self.assertIn(
            {
                "id": "V045",
                "title": "This Is Who Experiences the Good Life (According to Jesus) • Visual Commentary",
                "channel": "BibleProject",
                "youtubeId": "W9fR7sHw9Y8",
                "runtimeSeconds": 623,
            },
            [
                {
                    key: video[key]
                    for key in ("id", "title", "channel", "youtubeId", "runtimeSeconds")
                }
                for video in catalog["videos"]
            ],
        )
        encoded = json.dumps(catalog, ensure_ascii=False)
        self.assertNotIn("\ufffd", encoded)
        self.assertNotIn("must bear fruit", encoded.casefold())
        self.assertIsNone(re.search(r"garden.{0,24}empty", encoded.casefold()))
        self.assertTrue(all(video["runtimeSeconds"] <= 630 for video in catalog["videos"]))
        self.assertTrue(all(len(set(day["videoIds"])) == 3 for day in catalog["days"]))
        self.assertIn("V045", catalog["days"][56]["videoIds"])
        self.assertEqual(["R001"], catalog["days"][15]["resourceIds"])
        self.assertEqual(["R002"], catalog["days"][17]["resourceIds"])

    def test_writes_identical_api_and_mobile_snapshots(self):
        catalog = build_catalog(BOOK)
        with tempfile.TemporaryDirectory() as directory:
            left = Path(directory) / "api.json"
            right = Path(directory) / "app.json"

            write_outputs(catalog, [left, right])

            self.assertEqual(left.read_bytes(), right.read_bytes())


if __name__ == "__main__":
    unittest.main()
