#!/usr/bin/env python3
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

UNIT = "azuracast-live-capture"
PORT = int(sys.argv[1])
SYSTEMCTL = "/run/current-system/sw/bin/systemctl"
SUDO = "/run/wrappers/bin/sudo"

PAGE = """<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Live DJ stream</title>
<style>
body {{ font-family: sans-serif; background: #111; color: #eee; display: flex; flex-direction: column;
       align-items: center; justify-content: center; height: 100vh; margin: 0; gap: 1.5rem; }}
.badge {{ font-size: 1.5rem; padding: 0.5rem 1.5rem; border-radius: 2rem; }}
.live {{ background: #2e7d32; }}
.offline {{ background: #555; }}
button {{ font-size: 1.5rem; padding: 1rem 2rem; border-radius: 0.5rem; border: none; cursor: pointer; }}
</style></head>
<body>
<div class="badge {badge_class}">{status}</div>
<form method="post" action="/toggle"><button>{action}</button></form>
</body></html>
"""


def is_active() -> bool:
    return subprocess.run([SYSTEMCTL, "is-active", "--quiet", UNIT]).returncode == 0


class Handler(BaseHTTPRequestHandler):
    def render(self):
        live = is_active()
        html = PAGE.format(
            badge_class="live" if live else "offline",
            status="LIVE" if live else "OFFLINE",
            action="Stop streaming" if live else "Start streaming",
        )
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html.encode())

    def do_GET(self):
        self.render()

    def do_POST(self):
        if self.path == "/toggle":
            action = "stop" if is_active() else "start"
            subprocess.run([SUDO, SYSTEMCTL, action, UNIT], check=False)
        self.send_response(303)
        self.send_header("Location", "/")
        self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
