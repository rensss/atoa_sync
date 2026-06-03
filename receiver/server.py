#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import posixpath
import socket
from dataclasses import dataclass
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Callable
from urllib.parse import unquote, urlparse


PHOTO_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".gif"}
VIDEO_EXTENSIONS = {".mp4", ".mov", ".m4v", ".3gp", ".webm", ".avi", ".mkv"}


@dataclass(frozen=True)
class ReceiverConfig:
    output_dir: Path
    log_path: Path
    now: Callable[[], datetime] = datetime.now


def safe_filename(raw_path: str) -> str:
    decoded = unquote(raw_path).replace("\\", "/")
    if decoded.startswith("/") or decoded.strip() == "":
        raise ValueError("empty or absolute upload name is not allowed")

    parts = [part for part in decoded.split("/") if part not in ("", ".")]
    if not parts or any(part == ".." for part in parts):
        raise ValueError("path traversal is not allowed")

    name = parts[-1].strip()
    if name in ("", ".", ".."):
        raise ValueError("invalid upload filename")
    return name


def classify_file(filename: str, content_type: str | None = None) -> str:
    extension = Path(filename).suffix.lower()
    if extension in PHOTO_EXTENSIONS:
        return "photos"
    if extension in VIDEO_EXTENSIONS:
        return "videos"
    if content_type:
        if content_type.startswith("image/"):
            return "photos"
        if content_type.startswith("video/"):
            return "videos"
    return "files"


def local_ip() -> str:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        sock.close()


def create_server(host: str, port: int, config: ReceiverConfig) -> ThreadingHTTPServer:
    class AndroidSyncReceiverHandler(BaseHTTPRequestHandler):
        server_version = "AndroidSyncReceiver/0.1"

        def do_GET(self) -> None:
            parsed = urlparse(self.path)
            if parsed.path == "/health":
                self.write_json(200, {"status": "ok"})
                return
            if parsed.path == "/manifest.json":
                uploads = read_upload_manifest(config.log_path)
                self.write_json(200, {"count": len(uploads), "uploads": uploads})
                return
            if parsed.path == "/":
                self.write_json(
                    200,
                    {
                        "service": "Android Sync Receiver",
                        "status": "ok",
                        "upload_url": f"http://{local_ip()}:{self.server.server_address[1]}/uploads/",
                        "output_dir": str(config.output_dir),
                    },
                )
                return
            self.write_json(404, {"error": "not found"})

        def do_PUT(self) -> None:
            parsed = urlparse(self.path)
            normalized_path = posixpath.normpath(parsed.path)
            if not parsed.path.startswith("/uploads/") or normalized_path == "/uploads":
                self.write_json(404, {"error": "use PUT /uploads/<filename>"})
                return

            raw_name = parsed.path[len("/uploads/") :]
            try:
                filename = safe_filename(raw_name)
            except ValueError as error:
                self.write_json(400, {"error": str(error)})
                return

            content_length = self.headers.get("Content-Length")
            if content_length is None:
                self.write_json(411, {"error": "Content-Length is required"})
                return
            try:
                remaining = int(content_length)
            except ValueError:
                self.write_json(400, {"error": "invalid Content-Length"})
                return
            if remaining < 0:
                self.write_json(400, {"error": "invalid Content-Length"})
                return

            content_type = self.headers.get("Content-Type")
            stable_id = self.headers.get("X-Android-Sync-Id")
            date_modified_millis = parse_int_header(self.headers.get("X-Android-Sync-Date-Modified"))
            date_taken_millis = parse_int_header(self.headers.get("X-Android-Sync-Date-Taken"))
            date_added_millis = parse_int_header(self.headers.get("X-Android-Sync-Date-Added"))
            kind = classify_file(filename, content_type)
            month = config.now().strftime("%Y-%m")
            target_dir = config.output_dir / kind / month
            target_dir.mkdir(parents=True, exist_ok=True)
            target_path = unique_path(target_dir / filename)

            bytes_written = 0
            try:
                with target_path.open("wb") as output:
                    while remaining > 0:
                        chunk = self.rfile.read(min(1024 * 1024, remaining))
                        if not chunk:
                            raise ConnectionError("client closed connection before upload completed")
                        output.write(chunk)
                        bytes_written += len(chunk)
                        remaining -= len(chunk)
            except Exception as error:
                if target_path.exists():
                    target_path.unlink()
                self.append_log(filename, kind, bytes_written, "failed", str(error), stable_id, date_modified_millis, date_taken_millis, date_added_millis, None)
                self.write_json(500, {"error": str(error)})
                return

            if date_modified_millis is not None:
                modified_seconds = date_modified_millis / 1000
                os_utime(target_path, modified_seconds)

            metadata_path = write_metadata_sidecar(
                target_path,
                filename,
                kind,
                bytes_written,
                stable_id,
                date_modified_millis,
                date_taken_millis,
                date_added_millis,
                content_type,
            )
            self.append_log(filename, kind, bytes_written, "stored", None, stable_id, date_modified_millis, date_taken_millis, date_added_millis, str(target_path))
            self.write_json(
                201,
                {
                    "status": "stored",
                    "filename": filename,
                    "kind": kind,
                    "size_bytes": bytes_written,
                    "path": str(target_path),
                    "metadata_path": str(metadata_path),
                },
            )

        def append_log(
            self,
            filename: str,
            kind: str,
            size_bytes: int,
            status: str,
            error: str | None,
            stable_id: str | None,
            date_modified_millis: int | None,
            date_taken_millis: int | None,
            date_added_millis: int | None,
            path: str | None,
        ) -> None:
            config.log_path.parent.mkdir(parents=True, exist_ok=True)
            entry = {
                "time": config.now().isoformat(timespec="seconds"),
                "client_ip": self.client_address[0],
                "filename": filename,
                "kind": kind,
                "size_bytes": size_bytes,
                "status": status,
            }
            if stable_id:
                entry["stable_id"] = stable_id
            if date_modified_millis is not None:
                entry["date_modified_millis"] = date_modified_millis
            if date_taken_millis is not None:
                entry["date_taken_millis"] = date_taken_millis
            if date_added_millis is not None:
                entry["date_added_millis"] = date_added_millis
            if path:
                entry["path"] = path
            if error:
                entry["error"] = error
            with config.log_path.open("a", encoding="utf-8") as log_file:
                log_file.write(json.dumps(entry, ensure_ascii=False) + "\n")

        def write_json(self, status: int, payload: dict) -> None:
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: object) -> None:
            message = "%s - %s" % (self.address_string(), format % args)
            print(message)

    return ThreadingHTTPServer((host, port), AndroidSyncReceiverHandler)


def unique_path(path: Path) -> Path:
    if not path.exists():
        return path
    stem = path.stem
    suffix = path.suffix
    parent = path.parent
    index = 2
    while True:
        candidate = parent / f"{stem}-{index}{suffix}"
        if not candidate.exists():
            return candidate
        index += 1


def parse_int_header(value: str | None) -> int | None:
    if value is None or value.strip() == "":
        return None
    try:
        return int(value)
    except ValueError:
        return None


def os_utime(path: Path, modified_seconds: float) -> None:
    import os

    os.utime(path, (modified_seconds, modified_seconds))


def write_metadata_sidecar(
    path: Path,
    filename: str,
    kind: str,
    size_bytes: int,
    stable_id: str | None,
    date_modified_millis: int | None,
    date_taken_millis: int | None,
    date_added_millis: int | None,
    content_type: str | None,
) -> Path:
    metadata = {
        "filename": filename,
        "kind": kind,
        "size_bytes": size_bytes,
        "path": str(path),
    }
    if stable_id:
        metadata["stable_id"] = stable_id
    if date_modified_millis is not None:
        metadata["date_modified_millis"] = date_modified_millis
    if date_taken_millis is not None:
        metadata["date_taken_millis"] = date_taken_millis
    if date_added_millis is not None:
        metadata["date_added_millis"] = date_added_millis
    if content_type:
        metadata["content_type"] = content_type

    metadata_path = path.with_suffix(path.suffix + ".metadata.json")
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return metadata_path


def read_upload_manifest(log_path: Path) -> list[dict]:
    if not log_path.exists():
        return []

    by_stable_id: dict[str, dict] = {}
    fallback: list[dict] = []
    for line in log_path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("status") != "stored":
            continue
        record = {
            "filename": entry.get("filename"),
            "kind": entry.get("kind"),
            "size_bytes": entry.get("size_bytes"),
            "path": entry.get("path"),
            "time": entry.get("time"),
        }
        for key in ("stable_id", "date_modified_millis", "date_taken_millis", "date_added_millis"):
            if key in entry:
                record[key] = entry[key]
        stable_id = entry.get("stable_id")
        if stable_id:
            by_stable_id[stable_id] = record
        else:
            fallback.append(record)
    return list(by_stable_id.values()) + fallback


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Receive Android Sync uploads over HTTP PUT.")
    parser.add_argument("--host", default="0.0.0.0", help="Host/IP to bind. Default: 0.0.0.0")
    parser.add_argument("--port", type=int, default=8765, help="Port to listen on. Default: 8765")
    parser.add_argument(
        "--output-dir",
        default="received",
        help="Directory where uploaded files are stored. Default: received",
    )
    parser.add_argument(
        "--log-path",
        default="received/uploads.jsonl",
        help="JSONL upload log path. Default: received/uploads.jsonl",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir).expanduser().resolve()
    log_path = Path(args.log_path).expanduser().resolve()
    config = ReceiverConfig(output_dir=output_dir, log_path=log_path)
    httpd = create_server(args.host, args.port, config)
    upload_url = f"http://{local_ip()}:{args.port}/uploads/"
    print("Android Sync receiver is running")
    print(f"Upload URL: {upload_url}")
    print(f"Output dir: {output_dir}")
    print("Press Ctrl+C to stop")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping receiver")
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
