# Android Sync Receiver

Local computer-side receiver for the Android Sync app.

## Start

```bash
./receiver/start.sh
```

The service listens on port `8765` and prints the LAN upload URL, for example:

```text
http://192.168.1.10:8765/uploads/
```

Use that URL as the Android app sync target.

## Endpoints

- `GET /health` returns `{"status": "ok"}`.
- `GET /` returns basic receiver status and the upload URL.
- `PUT /uploads/<filename>` stores one uploaded file.

## Storage

Uploads are saved under:

```text
receiver/received/photos/YYYY-MM/
receiver/received/videos/YYYY-MM/
receiver/received/files/YYYY-MM/
```

Each upload is logged to:

```text
receiver/received/uploads.jsonl
```

## Notes

- Keep the computer and Android phone on the same Wi-Fi/LAN.
- Allow incoming connections for Terminal/Python if macOS firewall asks.
- The receiver only accepts safe filenames and rejects path traversal names like `../secret.txt`.
