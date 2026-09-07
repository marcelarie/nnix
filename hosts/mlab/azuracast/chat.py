"""Live chat for the public radio page (nginx SSE location + systemd service; see proxy.nix and
default.nix). No accounts: GET /chat/events assigns a random name via a cookie on first connect
(kept for the browser session, forgeable client-side like the name itself - there's nothing to
protect), then streams a short backlog plus every new message as Server-Sent Events. POST
/chat/send broadcasts a message to all connected clients. Everything is in-memory only - a
service restart clears history and drops connections, which is fine for ephemeral live chat.

ponytail: run via python3, not shebang
"""

import json
import os
import queue
import random
import re
import sys
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1])
COOKIE_NAME = "chat_name"
COOKIE_RE = re.compile(rf"{COOKIE_NAME}=([^;]+)")
HISTORY_LEN = 50
MAX_MESSAGE_LEN = 300
THROTTLE_S = 1.5

OWNER_NAME = "Marcelus Wallace"
# comma-separated IPs (as seen by nginx's X-Forwarded-For) that always get OWNER_NAME instead of
# a random one - set via CHAT_OWNER_IPS in default.nix's systemd service.
OWNER_IPS = set(filter(None, os.environ.get("CHAT_OWNER_IPS", "").split(",")))

ADJECTIVES = [
    "Sneaky", "Groovy", "Chill", "Rowdy", "Fuzzy", "Cosmic", "Sleepy", "Jazzy",
    "Feral", "Loyal", "Spicy", "Gloomy", "Silent", "Turbo", "Rusty", "Velvet",
]
ANIMALS = [
    "Otter", "Raccoon", "Falcon", "Panther", "Koala", "Ferret", "Weasel", "Heron",
    "Badger", "Lynx", "Gecko", "Moth", "Pigeon", "Marmot", "Newt", "Toad",
]

history = deque(maxlen=HISTORY_LEN)
history_lock = threading.Lock()
clients = set()
clients_lock = threading.Lock()
throttle = {}
throttle_lock = threading.Lock()


def random_name():
    return f"{random.choice(ADJECTIVES)} {random.choice(ANIMALS)}{random.randint(10, 99)}"


def broadcast(msg):
    with history_lock:
        history.append(msg)
    with clients_lock:
        dead = []
        for q in clients:
            try:
                q.put_nowait(msg)
            except queue.Full:
                dead.append(q)
        for q in dead:
            clients.discard(q)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def client_ip(self):
        xff = self.headers.get("X-Forwarded-For", "")
        return xff.split(",")[0].strip() or self.client_address[0]

    def client_name(self):
        if self.client_ip() in OWNER_IPS:
            self.new_cookie = False
            return OWNER_NAME
        m = COOKIE_RE.search(self.headers.get("Cookie", ""))
        if m:
            self.new_cookie = False
            return m.group(1)
        self.new_cookie = True
        return random_name()

    def write_event(self, event, data):
        self.wfile.write(f"event: {event}\ndata: {json.dumps(data)}\n\n".encode())
        self.wfile.flush()

    def do_GET(self):
        if self.path.split("?")[0] != "/chat/events":
            self.send_response(404)
            self.end_headers()
            return
        name = self.client_name()
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "keep-alive")
        if self.new_cookie:
            self.send_header(
                "Set-Cookie", f"{COOKIE_NAME}={name}; Path=/; Max-Age=31536000; SameSite=Lax"
            )
        self.end_headers()

        q = queue.Queue(maxsize=200)
        with clients_lock:
            clients.add(q)
        try:
            self.write_event("name", {"name": name})
            with history_lock:
                backlog = list(history)
            for msg in backlog:
                self.write_event("message", msg)
            while True:
                try:
                    msg = q.get(timeout=15)
                    self.write_event("message", msg)
                except queue.Empty:
                    self.wfile.write(b": ping\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            with clients_lock:
                clients.discard(q)

    def do_POST(self):
        if self.path.split("?")[0] != "/chat/send":
            self.send_response(404)
            self.end_headers()
            return
        name = self.client_name()
        if self.new_cookie:
            # never connected to /chat/events first - no name to post under
            self.send_response(400)
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", 0))
        if length > 2000:
            self.send_response(413)
            self.end_headers()
            return
        try:
            body = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            body = {}
        text = str(body.get("message", "")).strip()[:MAX_MESSAGE_LEN]
        if not text:
            self.send_response(400)
            self.end_headers()
            return

        ip = self.client_ip()
        now = time.time()
        with throttle_lock:
            if now - throttle.get(ip, 0) < THROTTLE_S:
                self.send_response(429)
                self.end_headers()
                return
            throttle[ip] = now

        broadcast({"name": name, "text": text, "ts": now})
        self.send_response(204)
        self.end_headers()


class Server(ThreadingHTTPServer):
    daemon_threads = True


Server(("127.0.0.1", PORT), Handler).serve_forever()
