"""Check the immersive-audio delta against an existing private Sync Rules export."""

import argparse
import re
import sys
from pathlib import Path

import yaml


FIELDS = {
    "personal_prayer_revisions": "content_format",
    "memory_reflections": "audio_encounter_id",
}
IDENT = r"[a-zA-Z_][a-zA-Z0-9_]*"
ITEM = rf"{IDENT}(?:\s+AS\s+{IDENT})?"
SELECT = re.compile(
    rf"\s*SELECT\s+(?P<columns>{ITEM}(?:\s*,\s*{ITEM})*)"
    rf"\s+FROM\s+(?P<table>{'|'.join(FIELDS)})"
    rf"\s+WHERE\s+(?:user_id|owner_id)\s*=\s*bucket\.{IDENT}\s*;?\s*",
    re.IGNORECASE | re.ASCII,
)


class ManualReview(ValueError):
    pass


class StrictLoader(yaml.SafeLoader):
    def compose_node(self, parent, index):
        if self.check_event(yaml.AliasEvent):
            raise ManualReview("YAML aliases require manual review")
        return super().compose_node(parent, index)

    def construct_mapping(self, node, deep=False):
        keys = set()
        for key, _ in node.value:
            if key.tag != "tag:yaml.org,2002:str" or key.value in keys:
                raise ManualReview("ambiguous mapping key")
            keys.add(key.value)
        return super().construct_mapping(node, deep)


def check(before, after):
    original = yaml.load(before, Loader=StrictLoader)
    candidate = yaml.load(after, Loader=StrictLoader)
    if not isinstance(original, dict) or "streams" in original:
        raise ManualReview("supply a complete legacy Sync Rules export")
    buckets = original.get("bucket_definitions")
    if not isinstance(buckets, dict):
        raise ManualReview("missing bucket_definitions")

    found = set()
    for bucket in buckets.values():
        if not isinstance(bucket, dict) or not isinstance(bucket.get("data", []), list):
            raise ManualReview("unsupported bucket layout")
        for index, sql in enumerate(bucket.get("data", [])):
            if not isinstance(sql, str):
                raise ManualReview("unsupported data query")
            if "%" in sql:
                raise ManualReview("SQL wildcard/pattern; verify source-table coverage")
            if not any(re.search(rf"\b{t}\b", sql, re.I) for t in FIELDS):
                continue
            query = SELECT.fullmatch(sql)
            if not query or not bucket.get("parameters"):
                raise ManualReview("target must have explicit columns and an existing owner parameter/filter")
            table = query["table"].lower()
            field = FIELDS[table]
            if table in found:
                raise ManualReview(f"multiple baseline projections of {table}")
            found.add(table)
            columns = query["columns"]
            if re.search(rf"\b{field}\b", columns, re.I):
                raise ManualReview(f"{table}.{field} already occurs in the baseline")
            at = query.end("columns")
            bucket["data"][index] = sql[:at] + ", " + field + sql[at:]
    if found != set(FIELDS):
        raise ManualReview("both existing target projections are required")
    # Require exact export text as well as matching parsed queries: different
    # YAML parsers can coerce unrelated scalar spellings in different ways.
    restored = after
    for table, field in FIELDS.items():
        restored, count = re.subn(rf", {field}(?=\s+FROM\s+{table}\b)", "", restored, flags=re.I)
        if count != 1:
            raise ManualReview(f"expected one literal {table}.{field} addition")
    if restored != before or yaml.safe_dump(original) != yaml.safe_dump(candidate):
        raise ManualReview("candidate differs from the two permitted SELECT-list additions")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    try:
        check(args.baseline.read_text(encoding="utf-8"), args.candidate.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, yaml.YAMLError):
        print("NOT VERIFIED: could not read two unambiguous YAML files", file=sys.stderr)
        return 1
    except ManualReview as error:
        print(f"NOT VERIFIED: {error}", file=sys.stderr)
        return 1
    print("MATCH: only content_format and audio_encounter_id were added. "
          "Validate the baseline's authorization and test staging separately.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
