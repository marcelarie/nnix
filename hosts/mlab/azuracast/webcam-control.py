#!/usr/bin/env python3
import json
import secrets
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import parse_qs

PORT = int(sys.argv[1])
STATE_FILE = Path(sys.argv[2])
TOKEN_FILE = STATE_FILE.parent / "preview-token"
WHEP_PATH = "/webcam/whep"

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Webcam test</title>
<style>
body {{ font-family: sans-serif; background: #111; color: #eee; display: flex; flex-direction: column;
       align-items: center; justify-content: center; min-height: 100vh; margin: 0; gap: 1.5rem; padding: 1rem; }}
video {{ width: min(90vw, 640px); background: #000; border-radius: 0.5rem; }}
.badge {{ font-size: 1.25rem; padding: 0.4rem 1.2rem; border-radius: 2rem; }}
.live {{ background: #2e7d32; }}
.offline {{ background: #555; }}
button {{ font-size: 1.25rem; padding: 0.8rem 1.6rem; border-radius: 0.5rem; border: none; cursor: pointer; }}
</style></head>
<body>
<video id="v" autoplay muted playsinline controls></video>
<div class="badge {badge_class}">Public page: {status}</div>
<form method="post" action="/toggle"><button>{action}</button></form>
<script>
(async function () {{
  var pc = new RTCPeerConnection();
  pc.ontrack = function (e) {{ document.getElementById("v").srcObject = e.streams[0]; }};
  pc.addTransceiver("video", {{direction: "recvonly"}});
  var offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  var res = await fetch("{whep_url}", {{
    method: "POST",
    headers: {{"Content-Type": "application/sdp"}},
    body: offer.sdp,
  }});
  if (!res.ok) return;
  var answer = await res.text();
  await pc.setRemoteDescription({{type: "answer", sdp: answer}});
}})().catch(function () {{}});
</script>
</body></html>
"""


def is_live() -> bool:
    return STATE_FILE.exists()


def preview_token() -> str:
    if not TOKEN_FILE.exists():
        TOKEN_FILE.write_text(secrets.token_urlsafe(24))
    return TOKEN_FILE.read_text().strip()


class Handler(BaseHTTPRequestHandler):
    def render(self):
        live = is_live()
        whep_url = f"https://radio.marcel.cool{WHEP_PATH}?preview={preview_token()}"
        html = PAGE.format(
            badge_class="live" if live else "offline",
            status="LIVE" if live else "hidden",
            action="Stop showing on public page" if live else "Show on public page",
            whep_url=whep_url,
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode())

    def do_GET(self):
        if self.path == "/status":
            body = json.dumps({"live": is_live()}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)
            return
        self.render()

    def do_POST(self):
        if self.path == "/toggle":
            if is_live():
                STATE_FILE.unlink(missing_ok=True)
            else:
                STATE_FILE.touch()
            self.send_response(303)
            self.send_header("Location", "/")
            self.end_headers()
            return

        if self.path == "/authcheck":
            length = int(self.headers.get("Content-Length", 0))
            try:
                req = json.loads(self.rfile.read(length) or b"{}")
            except ValueError:
                req = {}
            action = req.get("action")
            allowed = False
            if action == "publish":
                allowed = req.get("ip") in ("127.0.0.1", "::1")
            elif action == "read":
                query = parse_qs(req.get("query") or "")
                given_token = (query.get("preview") or [None])[0]
                allowed = is_live() or (given_token == preview_token())
            self.send_response(200 if allowed else 401)
            self.end_headers()
            return

        self.send_response(404)
        self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
