import unittest
from analyze_evidence import inspect, compare_environment


def sample(system_events=None, comfy_signatures=None, unavailable=None):
    return {
        "schema": 2, "machine": "HOME", "created_utc": "2026-11-09T00:00:00Z",
        "sources": {
            "events_system": {"status": "OK", "data": system_events or []},
            "comfy_log_evidence": {"status": "OK", "data": {"signatures": comfy_signatures or []}},
            "gpu": {"status": unavailable or "OK", "data": []},
            "environment": {"status": "OK", "data": {"pytorch": "2.10.0"}},
        }
    }


class EvidenceScenarioTests(unittest.TestCase):
    def test_gpu_tdr_correlated_not_causal(self):
        got = inspect(sample([{"provider": "Display", "code": 4101}, {"provider": "Kernel-Power", "code": 41}]))
        self.assertIn("GPU_DISPLAY_RESET_4101", got["signals"])
        self.assertIn("UNEXPECTED_SHUTDOWN_41", got["signals"])
        self.assertEqual("NOT_CONFIRMED", got["root_cause"])

    def test_oom_and_python_error(self):
        got = inspect(sample(comfy_signatures=[{"code": "OOM"}, {"code": "EXCEPTION"}]))
        self.assertEqual(["COMFY_EXCEPTION", "COMFY_OOM"], got["signals"])

    def test_custom_node_import(self):
        self.assertIn("COMFY_IMPORT", inspect(sample(comfy_signatures=[{"code": "IMPORT"}]))["signals"])

    def test_reboot_marker_alone_not_root_cause(self):
        got = inspect(sample([{"provider": "Microsoft-Windows-Kernel-Power", "code": 41}]))
        self.assertEqual(["UNEXPECTED_SHUTDOWN_41"], got["signals"])
        self.assertEqual("NOT_CONFIRMED", got["root_cause"])

    def test_offline_gpu_is_missing(self):
        got = inspect(sample(unavailable="UNAVAILABLE"))
        self.assertIn("gpu", got["missing_sources"])

    def test_slow_job_requires_missing_timing_data(self):
        got = inspect(sample())
        self.assertNotIn("SLOW_RENDER_PROVEN", got["signals"])
        self.assertEqual("NOT_CONFIRMED", got["root_cause"])

    def test_environment_diff(self):
        old = sample()
        new = sample()
        new["sources"]["environment"]["data"]["pytorch"] = "2.11.0"
        self.assertEqual("2.11.0", compare_environment(old, new)["pytorch"]["after"])

    def test_invalid_schema_refused(self):
        with self.assertRaises(ValueError):
            inspect({"schema": 1, "sources": {}})

    def test_source_with_private_fields_not_echoed(self):
        item = sample()
        item["sources"]["events_system"]["data"].append({"code": 1000, "provider": "Application Error", "private_prompt": "SECRET"})
        result = inspect(item)
        self.assertNotIn("SECRET", str(result))


if __name__ == "__main__":
    unittest.main()
