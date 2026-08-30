"""Generate a spoken news bulletin from unread Miniflux entries and upload it to AzuraCast.

Run twice a day by the azuracast-radio-bot systemd timer (see radio-bot.nix). All secrets and
endpoints arrive as environment variables; nothing is configured in this file.
"""

import html
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime
from zoneinfo import ZoneInfo

import requests

MINIFLUX_URL = os.environ.get("MINIFLUX_URL")
MINIFLUX_API_KEY = os.environ.get("MINIFLUX_API_KEY")
MINIFLUX_CATEGORY = os.environ.get("MINIFLUX_CATEGORY", "Radio")

SYNTHETIC_API_KEY = os.environ.get("SYNTHETIC_API_KEY")
SYNTHETIC_MODEL = os.environ.get("SYNTHETIC_MODEL", "syn:small:text")

AZURACAST_URL = os.environ.get("AZURACAST_URL")
AZURACAST_API_KEY = os.environ.get("AZURACAST_API_KEY")
AZURACAST_STATION = os.environ.get("AZURACAST_STATION", "radio_marcel")
AZURACAST_DIR = os.environ.get("AZURACAST_DIR", "news")

PIPER_MODEL = os.environ.get("PIPER_MODEL")
PIPER_CONFIG = os.environ.get("PIPER_CONFIG")

TZ = ZoneInfo(os.environ.get("TZ", "Europe/Madrid"))

REQUIRED = {
    "MINIFLUX_URL": MINIFLUX_URL,
    "MINIFLUX_API_KEY": MINIFLUX_API_KEY,
    "SYNTHETIC_API_KEY": SYNTHETIC_API_KEY,
    "AZURACAST_URL": AZURACAST_URL,
    "AZURACAST_API_KEY": AZURACAST_API_KEY,
    "PIPER_MODEL": PIPER_MODEL,
    "PIPER_CONFIG": PIPER_CONFIG,
}

MAX_ENTRIES = 20
MAX_CONTENT_CHARS = 400

miniflux_headers = {"X-Auth-Token": MINIFLUX_API_KEY}


def to_plain_text(markup):
    # ponytail: regex tag strip, not a parser. Feed is prose, and piper only ever sees the
    # LLM's rewrite of this - swap in html.parser if a feed starts leaking markup into audio.
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", markup))).strip()


def category_id():
    res = requests.get(
        f"{MINIFLUX_URL}/v1/categories", headers=miniflux_headers, timeout=10
    )
    res.raise_for_status()
    categories = res.json()
    for category in categories:
        if category["title"].lower() == MINIFLUX_CATEGORY.lower():
            return category["id"]
    titles = ", ".join(sorted(c["title"] for c in categories))
    sys.exit(f"No Miniflux category named {MINIFLUX_CATEGORY!r}. Available: {titles}")


def unread_entries():
    res = requests.get(
        f"{MINIFLUX_URL}/v1/categories/{category_id()}/entries",
        params={"status": "unread", "limit": MAX_ENTRIES, "direction": "desc"},
        headers=miniflux_headers,
        timeout=30,
    )
    res.raise_for_status()
    return res.json().get("entries", [])


def write_script(entries):
    now = datetime.now(TZ)
    slot = (
        "a morning bulletin. Open with a good-morning greeting and what happened overnight"
        if now.hour < 12
        else "an afternoon bulletin. Open with a good-afternoon greeting and the day's top stories"
    )
    items = "\n".join(
        f"- {e['title']}: {to_plain_text(e.get('content', ''))[:MAX_CONTENT_CHARS]}"
        for e in entries
    )
    prompt = (
        f"You are a radio news anchor. It is {now:%A %d %B, %H:%M}. Write {slot}. "
        "Summarise the items below into a natural spoken bulletin of about two minutes, "
        "grouping related stories and closing with a short sign-off. Output only the words to "
        "be read aloud: no URLs, no markdown, no headings, no stage directions.\n\n"
        + items
    )
    res = requests.post(
        "https://api.synthetic.new/v1/chat/completions",
        headers={"Authorization": f"Bearer {SYNTHETIC_API_KEY}"},
        json={
            "model": SYNTHETIC_MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "reasoning_effort": "none",
        },
        timeout=180,
    )
    res.raise_for_status()
    return res.json()["choices"][0]["message"]["content"].strip()


def synthesize(text, wav_path):
    subprocess.run(
        ["piper", "-m", PIPER_MODEL, "-c", PIPER_CONFIG, "-f", wav_path],
        input=text.encode(),
        check=True,
    )


def upload(wav_path, name):
    with open(wav_path, "rb") as wav:
        res = requests.post(
            f"{AZURACAST_URL}/api/station/{AZURACAST_STATION}/files/upload",
            headers={"X-API-Key": AZURACAST_API_KEY},
            data={"currentDirectory": AZURACAST_DIR},
            files={"file": (name, wav, "audio/wav")},
            timeout=180,
        )
    res.raise_for_status()


def mark_read(entries):
    res = requests.put(
        f"{MINIFLUX_URL}/v1/entries",
        headers=miniflux_headers,
        json={"entry_ids": [e["id"] for e in entries], "status": "read"},
        timeout=30,
    )
    res.raise_for_status()


def self_check():
    assert to_plain_text("<p>Hello &amp;   <b>world</b></p>") == "Hello & world"
    assert to_plain_text("") == ""
    print("self-check ok")


def main():
    if "--self-check" in sys.argv:
        return self_check()

    missing = [k for k, v in REQUIRED.items() if not v]
    if missing:
        sys.exit(f"radio-bot: missing environment variables: {', '.join(missing)}")

    entries = unread_entries()
    if not entries:
        print("radio-bot: no unread entries, nothing to broadcast")
        return

    text = write_script(entries)
    name = f"news-{datetime.now(TZ):%Y-%m-%d-%H%M}.wav"
    with tempfile.TemporaryDirectory() as tmp:
        wav_path = os.path.join(tmp, name)
        synthesize(text, wav_path)
        upload(wav_path, name)

    mark_read(entries)
    print(f"radio-bot: uploaded {AZURACAST_DIR}/{name} from {len(entries)} entries")


if __name__ == "__main__":
    main()
