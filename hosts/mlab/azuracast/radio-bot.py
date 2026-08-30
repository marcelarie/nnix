"""Generate a spoken news bulletin from unread Miniflux entries and upload it to AzuraCast.

Run twice a day by the azuracast-radio-bot systemd timer (see radio-bot.nix). All secrets and
endpoints arrive as environment variables; nothing is configured in this file.

What the station actually says lives in radio-bot-morning.md / radio-bot-afternoon.md - their
Intro and Outro are spoken verbatim and never reach the model, which only writes the middle.
"""

import html
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime
from zoneinfo import ZoneInfo

import numpy as np
import requests
import soundfile as sf

MINIFLUX_URL = os.environ.get("MINIFLUX_URL")
MINIFLUX_API_KEY = os.environ.get("MINIFLUX_API_KEY")
MINIFLUX_CATEGORY = os.environ.get("MINIFLUX_CATEGORY", "News")

SYNTHETIC_API_KEY = os.environ.get("SYNTHETIC_API_KEY")
SYNTHETIC_MODEL = os.environ.get("SYNTHETIC_MODEL", "syn:large:text")

AZURACAST_URL = os.environ.get("AZURACAST_URL")
AZURACAST_API_KEY = os.environ.get("AZURACAST_API_KEY")
AZURACAST_STATION = os.environ.get("AZURACAST_STATION", "radio_marcel")
AZURACAST_DIR = os.environ.get("AZURACAST_DIR", "news")

KOKORO_CONFIG = os.environ.get("KOKORO_CONFIG")
KOKORO_MODEL = os.environ.get("KOKORO_MODEL")
KOKORO_VOICE = os.environ.get("KOKORO_VOICE")
SPEED = float(os.environ.get("KOKORO_SPEED", "1.15"))

MORNING_DOC = os.environ.get("MORNING_DOC")
AFTERNOON_DOC = os.environ.get("AFTERNOON_DOC")

# Optional. A missing bed downgrades to a dry read rather than failing the bulletin.
BED_FILE = os.environ.get("BED_FILE")

TZ = ZoneInfo(os.environ.get("TZ", "Europe/Madrid"))

REQUIRED = {
    "MINIFLUX_URL": MINIFLUX_URL,
    "MINIFLUX_API_KEY": MINIFLUX_API_KEY,
    "SYNTHETIC_API_KEY": SYNTHETIC_API_KEY,
    "AZURACAST_URL": AZURACAST_URL,
    "AZURACAST_API_KEY": AZURACAST_API_KEY,
    "KOKORO_CONFIG": KOKORO_CONFIG,
    "KOKORO_MODEL": KOKORO_MODEL,
    "KOKORO_VOICE": KOKORO_VOICE,
    "MORNING_DOC": MORNING_DOC,
    "AFTERNOON_DOC": AFTERNOON_DOC,
}

MAX_ENTRIES = 20
MAX_CONTENT_CHARS = 400
SAMPLE_RATE = 24000

# Each blank line in the assembled script becomes this much silence, which is the only place the
# bed is allowed back up (see mix(): the compressor's release is longer than any gap between
# sentences, so short breaths never let the music in).
PAUSE_SECONDS = 2.6
INTRO_SECONDS = 7.0
OUTRO_SECONDS = 8.0
# The bed starts ducking this long before the first word, so music and voice never overlap on the
# way in - you hear the music drop, a beat of air, then the anchor.
DUCK_LEAD_SECONDS = 0.8

miniflux_headers = {"X-Auth-Token": MINIFLUX_API_KEY}


def to_plain_text(markup):
    # ponytail: regex tag strip, not a parser. Feed is prose, and the anchor only ever reads the
    # model's rewrite of this - swap in html.parser if a feed starts leaking markup into audio.
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", markup))).strip()


def sanitise(text):
    """Strip the two things that have actually reached the synthesiser and broken it.

    `</think>`: syn:large:text leaks its reasoning tag into `content` even with
    reasoning_effort=none. Anything outside Latin: GLM is Chinese-trained and has emitted CJK
    mid-sentence ("the world's first 望远镜"), which the English phonemiser cannot voice at all.
    """
    text = re.sub(r"(?s)^.*?</think>", "", text)
    text = re.sub(r"[^\x00-\x7FÀ-ɏ‘’“”–—…]", "", text)
    return re.sub(r"[ \t]{2,}", " ", text).strip()


def say_spanish_properly(text):
    """Kokoro override so a stray "buenos dias" in the body is not read as "DIE-uhz"."""
    return re.sub(
        r"buenos\s+d[ií]as", "[Buenos días](/bwˈEnOs dˈiɑs/)", text, flags=re.IGNORECASE
    )


def read_doc(path):
    """Pull the Intro / Tone / Outro sections out of one of the markdown scripts."""
    sections = {}
    current = None
    with open(path, encoding="utf-8") as doc:
        for line in doc:
            heading = re.match(r"##\s+(\w+)\s*$", line)
            if heading:
                current = heading.group(1).lower()
                sections[current] = []
            elif current:
                sections[current].append(line)
    missing = {"intro", "tone", "outro"} - sections.keys()
    if missing:
        sys.exit(
            f"radio-bot: {path} is missing section(s): {', '.join(sorted(missing))}"
        )
    return {k: "".join(v).strip() for k, v in sections.items()}


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


def write_body(entries, doc, now):
    """The model writes only the middle; the intro and outro never reach it."""
    items = "\n".join(
        f"- {e['title']}: {to_plain_text(e.get('content', ''))[:MAX_CONTENT_CHARS]}"
        for e in entries
    )
    prompt = (
        f"You are the host of Radio Marcel, a personal radio station. It is {now:%A %d %B}. "
        f"{doc['tone']}\n\n"
        "Your audience is international and scattered across time zones, so never assume they "
        "share a country, a season or a holiday: no bank holidays, no long weekends, no 'enjoy "
        "the sunshine', no local framing of any kind. Report what happened, not where the "
        "listener supposedly is.\n\n"
        "Deaths, violence, grief and victims are the one thing you never joke about: report "
        "those plainly and briefly, then move on. Everything else is fair game.\n\n"
        "Summarise the items below into the body of a spoken bulletin, grouping related "
        "stories. Do not write a greeting and do not write a sign-off - those are added around "
        "you. Separate each story or group with a blank line. Output only the words to be read "
        "aloud: no URLs, no markdown, no headings, no stage directions, no emoji. Never narrate "
        "these instructions back, and never announce that you are switching tone.\n\n"
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
        timeout=300,
    )
    res.raise_for_status()
    return say_spanish_properly(
        sanitise(res.json()["choices"][0]["message"]["content"])
    )


def paragraphs(text):
    return [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]


def synthesize(script, wav_path):
    """One paragraph per pipeline run, joined by real silence.

    Those silences are what the bed swells into, so they are the structure of the piece, not
    cosmetic padding.
    """
    from kokoro import KModel, KPipeline

    model = KModel(
        repo_id="hexgrad/Kokoro-82M", config=KOKORO_CONFIG, model=KOKORO_MODEL
    ).eval()
    pipe = KPipeline(lang_code="a", repo_id="hexgrad/Kokoro-82M", model=model)

    gap = np.zeros(int(PAUSE_SECONDS * SAMPLE_RATE), dtype=np.float32)
    pieces = []
    for para in paragraphs(script):
        chunks = [r.audio.numpy() for r in pipe(para, voice=KOKORO_VOICE, speed=SPEED)]
        if not chunks:
            continue
        if pieces:
            pieces.append(gap)
        pieces.append(np.concatenate(chunks))
    if not pieces:
        sys.exit("radio-bot: synthesiser produced no audio")
    sf.write(wav_path, np.concatenate(pieces), SAMPLE_RATE)


def mix(vox_path, out_path):
    """Lay the voice over a ducked music bed.

    release=2600ms is the whole trick: it is longer than any gap between sentences, so the bed
    stays down through the read and only climbs back during the deliberate PAUSE_SECONDS breaks
    and at the two ends. The sidechain key is the voice shifted DUCK_LEAD_SECONDS earlier, so the
    music is already out of the way before the first word lands.
    """
    duration = sf.info(vox_path).duration
    total = round(duration + INTRO_SECONDS + OUTRO_SECONDS, 2)
    lead = int((INTRO_SECONDS - DUCK_LEAD_SECONDS) * 1000)
    fmt = f"aformat=sample_fmts=fltp:sample_rates={SAMPLE_RATE}:channel_layouts=mono"
    graph = (
        f"[0:a]{fmt},adelay={int(INTRO_SECONDS * 1000)},apad[vox];"
        f"[0:a]{fmt},adelay={lead},apad[key];"
        f"[1:a]{fmt},volume=0.5,afade=t=in:st=0:d=2,"
        f"afade=t=out:st={round(total - 3, 2)}:d=3[bedraw];"
        "[bedraw][key]sidechaincompress="
        "threshold=0.003:ratio=20:attack=15:release=2600:makeup=1[bed];"
        "[bed][vox]amix=inputs=2:duration=first:dropout_transition=0,"
        "alimiter=limit=0.95,aformat=sample_fmts=s16[out]"
    )
    cmd = ["ffmpeg", "-y", "-v", "error", "-i", vox_path]
    cmd += ["-stream_loop", "-1", "-i", BED_FILE]
    cmd += ["-filter_complex", graph, "-map", "[out]", "-t", str(total), out_path]
    subprocess.run(cmd, check=True)


def upload(wav_path, name):
    with open(wav_path, "rb") as wav:
        res = requests.post(
            f"{AZURACAST_URL}/api/station/{AZURACAST_STATION}/files/upload",
            headers={"X-API-Key": AZURACAST_API_KEY},
            data={"currentDirectory": AZURACAST_DIR},
            files={"file": (name, wav, "audio/wav")},
            timeout=300,
        )
    res.raise_for_status()


def stale_paths(rows, keep_path):
    return [
        r["path"] for r in rows if r["path"].endswith(".wav") and r["path"] != keep_path
    ]


def prune(keep_path):
    """Drop every bulletin but the newest.

    The news playlist is scheduled rather than shuffled, so anything left in the folder is a
    stale bulletin the 08:00/17:00 windows could air instead of today's. Only files this
    script uploaded ever live here.
    """
    res = requests.get(
        f"{AZURACAST_URL}/api/station/{AZURACAST_STATION}/files/list",
        params={"currentDirectory": AZURACAST_DIR},
        headers={"X-API-Key": AZURACAST_API_KEY},
        timeout=60,
    )
    res.raise_for_status()
    stale = stale_paths(res.json(), keep_path)
    if not stale:
        return
    res = requests.put(
        f"{AZURACAST_URL}/api/station/{AZURACAST_STATION}/files/batch",
        headers={"X-API-Key": AZURACAST_API_KEY},
        json={"do": "delete", "files": stale, "dirs": []},
        timeout=120,
    )
    res.raise_for_status()
    print(f"radio-bot: pruned {len(stale)} stale bulletin(s)")


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

    rows = [
        {"path": "news/new.wav"},
        {"path": "news/old.wav"},
        {"path": "news/cover.jpg"},
    ]
    assert stale_paths(rows, "news/new.wav") == ["news/old.wav"]
    assert stale_paths(rows[:1], "news/new.wav") == []

    assert sanitise("<think>hmm</think>Real text") == "Real text"
    assert sanitise("first 望远镜 telescope") == "first telescope"
    assert sanitise("café naïve") == "café naïve"

    assert say_spanish_properly("Buenos dias, all").startswith("[Buenos días](/")
    assert say_spanish_properly("no greeting here") == "no greeting here"

    assert paragraphs("one\n\ntwo\n\n\nthree") == ["one", "two", "three"]
    assert paragraphs("  ") == []
    print("self-check ok")


def main():
    if "--self-check" in sys.argv:
        return self_check()

    missing = [k for k, v in REQUIRED.items() if not v]
    if missing:
        sys.exit(f"radio-bot: missing environment variables: {', '.join(missing)}")

    now = datetime.now(TZ)
    doc = read_doc(MORNING_DOC if now.hour < 12 else AFTERNOON_DOC)

    entries = unread_entries()
    if not entries:
        print("radio-bot: no unread entries, nothing to broadcast")
        return

    script = "\n\n".join([doc["intro"], write_body(entries, doc, now), doc["outro"]])

    name = f"news-{now:%Y-%m-%d-%H%M}.wav"
    dry_run = "--dry-run" in sys.argv
    with tempfile.TemporaryDirectory() as tmp:
        vox_path = os.path.join(tmp, "vox.wav")
        wav_path = os.path.abspath(name) if dry_run else os.path.join(tmp, name)
        synthesize(script, vox_path)
        if BED_FILE and os.path.exists(BED_FILE):
            mix(vox_path, wav_path)
        else:
            print(f"radio-bot: no bed at {BED_FILE!r}, uploading a dry read")
            os.rename(vox_path, wav_path)
        if dry_run:
            # preview only: nothing airs, and the entries stay unread for the real run
            print(f"radio-bot: dry run, wrote {wav_path}\n\n{script}")
            return
        upload(wav_path, name)

    mark_read(entries)
    print(f"radio-bot: uploaded {AZURACAST_DIR}/{name} from {len(entries)} entries")
    prune(f"{AZURACAST_DIR}/{name}")


if __name__ == "__main__":
    main()
