import datetime as dt
import unittest
from types import SimpleNamespace

from func import decide


class RotationTests(unittest.TestCase):
    now = dt.datetime(2026, 9, 30, tzinfo=dt.timezone.utc)

    def backups(self, count):
        return [
            SimpleNamespace(
                id=str(i),
                lifecycle_state="AVAILABLE",
                time_created=self.now - dt.timedelta(days=42 - i * 7),
            )
            for i in range(count)
        ]

    def test_initial_or_underfull_creates(self):
        for count in (0, 1, 4):
            with self.subTest(count=count):
                self.assertEqual(
                    decide(self.backups(count), self.now, 5), ("create", None)
                )

    def test_full_deletes_only_oldest(self):
        self.assertEqual(decide(self.backups(5), self.now, 5), ("delete", "0"))

    def test_stopped_job_does_not_expire_window(self):
        self.assertEqual(
            decide(self.backups(5), self.now + dt.timedelta(days=1000), 5),
            ("delete", "0"),
        )

    def test_incomplete_or_unknown_stops_rotation(self):
        for state in ("CREATING", "FAULTY", "TERMINATING", "UNKNOWN"):
            with self.subTest(state=state):
                backups = self.backups(5)
                backups[-1].lifecycle_state = state
                self.assertEqual(decide(backups, self.now, 5), ("wait", None))

    def test_recent_success_prevents_duplicate(self):
        backups = self.backups(5)
        backups[-1].time_created = self.now - dt.timedelta(days=6)
        self.assertEqual(decide(backups, self.now, 5), ("current", None))

    def test_overfull_refuses_even_with_recent_backup(self):
        with self.assertRaises(RuntimeError):
            decide(self.backups(7), self.now, 5)

    def test_configured_limit_preserves_a_previous_backup(self):
        self.assertEqual(decide(self.backups(2), self.now, 2), ("delete", "0"))
        with self.assertRaises(ValueError):
            decide(self.backups(1), self.now, 1)


if __name__ == "__main__":
    unittest.main()
