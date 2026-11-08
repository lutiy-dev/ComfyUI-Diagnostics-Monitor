import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from contextlib import closing

from merge_to_sqlite import merge


class EvidenceSQLiteTest(unittest.TestCase):
    def test_snapshot_idempotence_and_machine(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            snapshot = home / "evidence_HOME_test.json"
            snapshot.write_text(json.dumps({
                "schema": 2, "machine": "HOME", "kind": "evidence_snapshot",
                "created_utc": "2026-11-09T00:00:00Z", "sources": {"gpu": {"status": "UNAVAILABLE"}}
            }), encoding="utf-8")
            db = home / "test.sqlite"
            a, d, i, total = merge(str(db), [str(snapshot)])
            self.assertEqual((1, 0, 0, 1), (a, d, i, total))
            a, d, i, total = merge(str(db), [str(snapshot)])
            self.assertEqual((0, 1, 0, 1), (a, d, i, total))
            with closing(sqlite3.connect(db)) as conn:
                self.assertEqual(("evidence", "HOME", "2026-11-09T00:00:00Z"),
                                 conn.execute("SELECT kind,machine,timestamp_utc FROM records").fetchone())

    def test_unrelated_json_not_imported(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            (folder / "config.json").write_text('{"machine":"HOME"}', encoding="utf-8")
            self.assertEqual((0, 0, 0, 0), merge(str(folder / "test.sqlite"), [str(folder / "*.json")]))


if __name__ == "__main__":
    unittest.main()
