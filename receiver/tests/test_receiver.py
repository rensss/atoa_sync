import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

from receiver.server import ReceiverConfig, create_server, safe_filename


class ReceiverServerTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        config = ReceiverConfig(
            output_dir=self.root / "received",
            log_path=self.root / "uploads.jsonl",
            now=lambda: datetime(2026, 6, 3, 10, 30, 0),
        )
        self.httpd = create_server("127.0.0.1", 0, config)
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()
        self.base_url = f"http://127.0.0.1:{self.httpd.server_address[1]}"

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=3)
        self.tempdir.cleanup()

    def test_health_endpoint_reports_ok(self):
        with urllib.request.urlopen(self.base_url + "/health", timeout=5) as response:
            payload = json.loads(response.read().decode("utf-8"))

        self.assertEqual(200, response.status)
        self.assertEqual("ok", payload["status"])

    def test_put_upload_saves_photo_by_month_and_logs_metadata(self):
        request = urllib.request.Request(
            self.base_url + "/uploads/IMG_0001.jpg",
            data=b"photo bytes",
            method="PUT",
            headers={
                "Content-Type": "image/jpeg",
                "X-Android-Sync-Id": "image:42",
                "X-Android-Sync-Date-Modified": "1780482600000",
                "X-Android-Sync-Date-Taken": "1780479000000",
                "X-Android-Sync-Date-Added": "1780478000000",
            },
        )

        with urllib.request.urlopen(request, timeout=5) as response:
            payload = json.loads(response.read().decode("utf-8"))

        saved = self.root / "received" / "photos" / "2026-06" / "IMG_0001.jpg"
        self.assertEqual(201, response.status)
        self.assertEqual(str(saved), payload["path"])
        self.assertEqual(b"photo bytes", saved.read_bytes())

        entries = [json.loads(line) for line in (self.root / "uploads.jsonl").read_text().splitlines()]
        self.assertEqual(1, len(entries))
        self.assertEqual("IMG_0001.jpg", entries[0]["filename"])
        self.assertEqual(11, entries[0]["size_bytes"])
        self.assertEqual("photos", entries[0]["kind"])
        self.assertEqual("stored", entries[0]["status"])
        self.assertEqual("image:42", entries[0]["stable_id"])
        self.assertEqual(1780482600000, entries[0]["date_modified_millis"])

        sidecar = saved.with_suffix(saved.suffix + ".metadata.json")
        metadata = json.loads(sidecar.read_text())
        self.assertEqual("image:42", metadata["stable_id"])
        self.assertEqual("IMG_0001.jpg", metadata["filename"])
        self.assertEqual(1780479000000, metadata["date_taken_millis"])
        self.assertEqual(1780478000000, metadata["date_added_millis"])
        self.assertEqual(1780482600, int(os.path.getmtime(saved)))

    def test_put_upload_saves_video_by_month(self):
        request = urllib.request.Request(
            self.base_url + "/uploads/DCIM/Clip.mov",
            data=b"video bytes",
            method="PUT",
            headers={"Content-Type": "video/quicktime"},
        )

        with urllib.request.urlopen(request, timeout=5) as response:
            payload = json.loads(response.read().decode("utf-8"))

        saved = self.root / "received" / "videos" / "2026-06" / "Clip.mov"
        self.assertEqual(201, response.status)
        self.assertEqual(str(saved), payload["path"])
        self.assertEqual(b"video bytes", saved.read_bytes())

    def test_rejects_path_traversal_upload_names(self):
        request = urllib.request.Request(
            self.base_url + "/uploads/../../secret.txt",
            data=b"nope",
            method="PUT",
        )

        with self.assertRaises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(request, timeout=5)

        self.assertEqual(400, error.exception.code)
        self.assertFalse((self.root / "secret.txt").exists())

    def test_manifest_lists_stored_upload_records(self):
        request = urllib.request.Request(
            self.base_url + "/uploads/IMG_0002.jpg",
            data=b"abc",
            method="PUT",
            headers={
                "Content-Type": "image/jpeg",
                "X-Android-Sync-Id": "image:99",
                "X-Android-Sync-Date-Modified": "1780482600000",
            },
        )
        with urllib.request.urlopen(request, timeout=5):
            pass

        with urllib.request.urlopen(self.base_url + "/manifest.json", timeout=5) as response:
            payload = json.loads(response.read().decode("utf-8"))

        self.assertEqual(200, response.status)
        self.assertEqual(1, payload["count"])
        self.assertEqual("image:99", payload["uploads"][0]["stable_id"])
        self.assertEqual("IMG_0002.jpg", payload["uploads"][0]["filename"])

    def test_safe_filename_rejects_empty_or_dangerous_values(self):
        self.assertEqual("IMG_0001.jpg", safe_filename("DCIM/Camera/IMG_0001.jpg"))
        with self.assertRaises(ValueError):
            safe_filename("../IMG_0001.jpg")
        with self.assertRaises(ValueError):
            safe_filename("")


if __name__ == "__main__":
    unittest.main()
