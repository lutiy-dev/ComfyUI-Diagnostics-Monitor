import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from merge_to_sqlite import merge


class ImportTests(unittest.TestCase):
    def test_deduplication_and_two_machine_aliases(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / "telemetry_HOME_20261108.jsonl"
            archive.write_text(
                json.dumps({"machine": "HOME", "timestamp_utc": "2026-11-08T16:35:22Z"}) + "\n"
                + json.dumps({"machine": "WORK", "timestamp_utc": "2026-11-08T16:36:22Z"}) + "\n"
                + "not json\n", encoding="utf-8")
            db = root / "test.sqlite"
            self.assertEqual(merge(db, [str(archive)]), (2, 0, 1, 2))
            self.assertEqual(merge(db, [str(archive)]), (0, 2, 1, 2))
            with sqlite3.connect(db) as con:
                self.assertEqual(con.execute("SELECT COUNT(DISTINCT machine) FROM records").fetchone()[0], 2)

    def test_invalid_payload_not_imported(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "invalid.jsonl"
            source.write_text("{}\n[]\n", encoding="utf-8")
            self.assertEqual(merge(root / "test.sqlite", [str(source)]), (0, 0, 2, 0))


if __name__ == "__main__":
    unittest.main()
