import unittest

from check_audio_projection import ManualReview, check


# Synthetic export, not a deployable configuration.
BASE = """bucket_definitions:
  fixture_account:
    parameters: SELECT id AS account_key FROM users WHERE public_id = request.user_id()
    data:
      - SELECT id, prayer_id, body FROM personal_prayer_revisions WHERE user_id = bucket.account_key
      - SELECT id, encounter_id, body FROM memory_reflections WHERE user_id = bucket.account_key
  fixture_public:
    data:
      - SELECT id, title FROM public_catalog
"""
AFTER = BASE.replace("body FROM personal_", "body, content_format FROM personal_").replace(
    "body FROM memory_", "body, audio_encounter_id FROM memory_"
)


class ProjectionDeltaTest(unittest.TestCase):
    def test_only_two_appended_fields_pass(self):
        check(BASE, AFTER)

    def test_reject_incomplete_or_wider_changes(self):
        for candidate in (
            BASE,
            AFTER.replace(", content_format", ""),
            AFTER.replace(", content_format", ", content_format, user_id"),
            AFTER.replace("user_id = bucket.account_key", "1 = 1", 1),
            AFTER.replace("request.user_id()", "request.parameters()"),
            AFTER.replace("title FROM public_catalog", "* FROM public_catalog"),
            AFTER + "# unrelated change\n",
            AFTER + "  new_bucket:\n    data: []\n",
            AFTER.replace("      - SELECT id, title", "      - SELECT * FROM memory_reflections\n      - SELECT id, title"),
        ):
            with self.subTest(candidate=candidate), self.assertRaises(ManualReview):
                check(BASE, candidate)

    def test_ambiguous_baselines_need_manual_review(self):
        for baseline in (
            BASE.replace("id, prayer_id, body", "*"),
            BASE.replace("WHERE user_id = bucket.account_key", "WHERE user_id = bucket.account_key OR 1 = 1", 1),
            BASE.replace("bucket_definitions:", "streams: {}\nbucket_definitions:"),
            BASE.replace("public_catalog", '"public"."memory_%"'),
            BASE.replace("      - SELECT id, title", "      - SELECT id FROM memory_reflections WHERE user_id = bucket.account_key\n      - SELECT id, title"),
            BASE.replace("  fixture_account:", "  fixture_account: {}\n  fixture_account:"),
            BASE.replace("    parameters:", "    old: &v dummy\n    other: *v\n    parameters:"),
        ):
            with self.subTest(baseline=baseline), self.assertRaises(ManualReview):
                check(baseline, AFTER)


if __name__ == "__main__":
    unittest.main()
