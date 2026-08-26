#!/usr/bin/env python3
"""Inject WhatsApp registration (phone + SMS code) via sendevent + AdbKeyboard.

WHY NOT uiautomator2 .click() / .set_text():
  On redroid_x86_64, WhatsApp's custom registration_submit button rejects
  injected motion events (deviceId=-1 from the injection API). uiautomator2's
  accessibility ACTION_CLICK is a no-op, and input tap (mouse source) can't
  focus EditTexts. See WHATSAPP-REDROID.md for the full bug history.

WHAT WORKS:
  sendevent on /dev/input/event12 (real device coords, indistinguishable from
  a finger) for taps/focus, plus AdbKeyboard ADB_INPUT_TEXT broadcasts for
  typing. uiautomator2 is used ONLY for element discovery (bounds, text,
  existence) — read-only ops are reliable.

Prereq: `make android-mirror` must be running (SSH tunnel + adb connected).
    make whatsapp-register
    make whatsapp-register WA_PHONE=647147012 WA_CODE=686189
    make whatsapp-register WA_STAGE=phone   # only the phone step
    make whatsapp-register WA_STAGE=code    # only inject the code
    make whatsapp-register WA_RETRIES=5
"""
import os
import re
import sys
import time

import uiautomator2 as u2

DEVICE = os.environ.get("WA_DEVICE", "127.0.0.1:5555")
PHONE = os.environ.get("WA_PHONE", "647147012")
CODE = os.environ.get("WA_CODE", "")            # 6-digit code, or blank to wait
CODE_LINK = os.environ.get("WA_CODE_LINK", "")    # https://v.whatsapp.com/<code> deep-link
CODE_WAIT = int(os.environ.get("WA_CODE_WAIT", "180"))  # seconds to wait for code
COUNTRY = os.environ.get("WA_COUNTRY", "34")  # CC digits; typing '34' auto-detects Spain
NAME = os.environ.get("WA_NAME", "Pi")         # profile name for the name-setup screen
SETUP_ROUNDS = int(os.environ.get("WA_SETUP_ROUNDS", "20"))
RETRIES = int(os.environ.get("WA_RETRIES", "3"))
PACKAGE = os.environ.get("WA_PACKAGE", "com.whatsapp")
INPUT_DEV = os.environ.get("WA_INPUT_DEV", "/dev/input/event12")
STAGE = os.environ.get("WA_STAGE", "auto")  # auto | phone | code


def rid(name: str) -> str:
    return f"{PACKAGE}:id/{name}"


def norm_phone(s: str) -> str:
    """Digits only — compares WA_PHONE against WhatsApp's formatted field."""
    return re.sub(r"\D", "", s or "")


# --- sendevent: the one tap method that works on redroid + WhatsApp --------

def se_tap(d: u2.Device, x: int, y: int):
    """Tap at (x, y) via raw sendevent on the real input device.

    This is the ONLY tap method that reliably fires WhatsApp's custom button
    onClick handlers and focuses EditTexts on redroid. input tap (mouse source)
    and uiautomator2 .click() (accessibility) both fail here.
    """
    se = f"sendevent {INPUT_DEV}"
    cmd = "; ".join([
        f"{se} 1 330 1",      # EV_KEY  BTN_TOUCH down
        f"{se} 3 57 0",       # EV_ABS  ABS_MT_TRACKING_ID = 0
        f"{se} 3 53 {x}",     # EV_ABS  ABS_MT_POSITION_X
        f"{se} 3 54 {y}",     # EV_ABS  ABS_MT_POSITION_Y
        f"{se} 0 0 0",        # EV_SYN  SYN_REPORT
        f"{se} 1 330 0",      # EV_KEY  BTN_TOUCH up
        f"{se} 3 57 -1",      # EV_ABS  ABS_MT_TRACKING_ID = -1 (release)
        f"{se} 0 0 0",        # EV_SYN  SYN_REPORT
    ])
    d.shell(cmd)


def tap_elem(d: u2.Device, elem) -> bool:
    """sendevent-tap the center of a uiautomator2 element. Returns False if gone."""
    if not elem.exists:
        return False
    b = elem.info["bounds"]
    x = (b["left"] + b["right"]) // 2
    y = (b["top"] + b["bottom"]) // 2
    se_tap(d, x, y)
    return True


def broadcast_text(d: u2.Device, text: str):
    """Type text via AdbKeyboard broadcast (routes through InputConnection)."""
    d.shell(f"am broadcast -a ADB_INPUT_TEXT --es msg '{text}'")


def ensure_adbime(d: u2.Device):
    """AdbKeyboard must be active for ADB_INPUT_TEXT broadcasts to land."""
    d.shell("ime set com.android.adbkeyboard/.AdbIME")


# --- screen detection -------------------------------------------------------

def on_phone_screen(d: u2.Device) -> bool:
    return d(resourceId=rid("registration_phone")).exists


def on_code_screen(d: u2.Device) -> bool:
    return d(resourceId=rid("verify_sms_code_input")).exists


def on_main_screen(d: u2.Device) -> bool:
    """WhatsApp chat list: the fab + conversations list, and a non-setup activity."""
    if d(resourceId=rid("fab")).exists:
        return True
    if d(resourceId=rid("conversations_list_view")).exists:
        return True
    # Fallback: WhatsApp foreground but on none of the known setup screens.
    cur = d.app_current()
    if cur.get("package") != PACKAGE:
        return False
    act = (cur.get("activity") or "")
    setup_markers = ("registration", "EULA", "Verify", "RequestPermission",
                     "VerifyOtp", "profile", "Profile", "Setup", "Welcome")
    return not any(m in act for m in setup_markers)


def dump_screen(d: u2.Device, tag: str):
    """Print visible text + field values; save hierarchy to /tmp for debugging."""
    xml = d.dump_hierarchy()
    path = f"/tmp/wa-dump-{tag}-{int(time.time())}.xml"
    with open(path, "w") as f:
        f.write(xml)
    texts = [t for t in re.findall(r'text="([^"]*)"', xml) if t.strip()]
    print(f"  --- dump [{tag}] -> {path} ---")
    print(f"  visible text: {texts}")


# --- phone stage ------------------------------------------------------------

def do_phone_stage(d: u2.Device) -> bool:
    """Enter the phone number and advance past the registration screen.

    Returns True if we left the phone screen.
    """
    # Set country if not already (fresh install shows "Choose a country").
    # Typing the CC digits (e.g. '34') in the CC field auto-detects Spain.
    cc = d(resourceId=rid("registration_cc"))
    if cc.exists and not norm_phone(cc.get_text() or ""):
        print(f"  country not set — typing CC '{COUNTRY}' to auto-detect")
        tap_elem(d, cc)
        time.sleep(0.5)
        broadcast_text(d, COUNTRY)
        time.sleep(1.2)

    field = d(resourceId=rid("registration_phone"))
    current = field.get_text() or ""

    if norm_phone(current) == norm_phone(PHONE):
        print(f"  phone already set ({current!r}) — skipping inject")
    else:
        print(f"  focusing phone field (was: {current!r})...")
        if not tap_elem(d, field):
            print("  phone field vanished", file=sys.stderr)
            return False
        time.sleep(0.5)
        print(f"  typing {PHONE}...")
        broadcast_text(d, PHONE)
        time.sleep(1.2)

    # Tap SIGUIENTE (registration_submit) — sendevent, not .click()
    btn = d(resourceId=rid("registration_submit"))
    if not btn.exists:
        print("  SIGUIENTE button not found", file=sys.stderr)
        return False
    if not btn.info.get("enabled", True):
        print("  SIGUIENTE is disabled (invalid form?) — dumping state")
        dump_screen(d, "submit-disabled")
        return False
    print("  tapping SIGUIENTE...")
    tap_elem(d, btn)
    time.sleep(2.5)

    # Confirm dialog: "¿Este es el número correcto?" → tap "Sí" (button1)
    if d(resourceId="android:id/button1").exists:
        print("  confirming number (Sí)...")
        tap_elem(d, d(resourceId="android:id/button1"))
        time.sleep(3)

    if on_phone_screen(d):
        print("  still on phone screen after submit")
        dump_screen(d, "stuck-on-phone")
        return False
    print("  ADVANCED past phone screen")
    return True


# --- code stage -------------------------------------------------------------

def code_from_link(url: str) -> str:
    """Extract the 6-digit code from a v.whatsapp.com/<code> URL."""
    m = re.search(r'v\.whatsapp\.com/(\d+)', url or "")
    return m.group(1) if m else ""


def do_code_stage(d: u2.Device) -> bool:
    """Enter the verification code.

    Two supported inputs (the link path is the easy one the user described):
      - WA_CODE_LINK: a https://v.whatsapp.com/<code> URL. Opening it deep-links
        into WhatsApp (com.whatsapp.VerifyOtpDeepLink) and auto-verifies; the
        redroid webview app (org.chromium.webview_shell) loads the same URL and
        also forwards the code to WhatsApp.
      - WA_CODE: the raw 6-digit code; broadcast into the focused code field.
    If neither is set, wait up to WA_CODE_WAIT seconds for the code screen to
    clear on its own (user opens a link via scrcpy / waits for the SMS).
    Returns True once we leave the code screen.
    """
    if CODE_LINK:
        print(f"  opening code link {CODE_LINK} (deep-link -> WhatsApp auto-verify)")
        d.shell(f"am start -a android.intent.action.VIEW -d '{CODE_LINK}' {PACKAGE}")
        if wait_off_code(d, tries=12):   # ~6s for the deep-link to verify
            print("  link auto-verified -- ADVANCED")
            return True
        # Fallback: open in the redroid webview app (also forwards to WhatsApp)
        print("  deep-link didn't clear it -- trying webview app")
        d.shell(f"am start -a android.intent.action.VIEW -d '{CODE_LINK}' org.chromium.webview_shell")
        if wait_off_code(d, tries=12):
            print("  webview forwarded the code -- ADVANCED")
            return True
        # Last resort: extract the code from the link and broadcast it
        code = code_from_link(CODE_LINK)
        if code:
            print(f"  falling back to broadcasting extracted code {code}")
            return _broadcast_code(d, code)
        print("  link yielded no code and didn't auto-verify", file=sys.stderr)
        return False

    if CODE:
        return _broadcast_code(d, CODE)

    # No code provided -- wait for the user to handle it (open a link, etc.).
    print(f"  no WA_CODE/WA_CODE_LINK set -- waiting up to {CODE_WAIT}s for the code screen to clear")
    print("  (open a v.whatsapp.com/<code> link in the redroid, or re-run with WA_CODE=...)")
    return wait_off_code(d, tries=CODE_WAIT // 2)


def _broadcast_code(d: u2.Device, code: str) -> bool:
    """Focus the code field, type the code, wait for WhatsApp to auto-submit."""
    field = d(resourceId=rid("verify_sms_code_input"))
    if not field.exists:
        print("  code field not found", file=sys.stderr)
        return False
    print("  focusing code field...")
    tap_elem(d, field)
    time.sleep(0.5)
    print(f"  typing code {code}...")
    broadcast_text(d, code)
    time.sleep(3)  # 6-digit codes auto-submit in WhatsApp
    if wait_off_code(d, tries=6):
        print("  code accepted -- ADVANCED")
        return True
    print("  code did not auto-submit", file=sys.stderr)
    return False


def wait_off_code(d: u2.Device, tries: int = 10) -> bool:
    for _ in range(tries):
        time.sleep(0.5)
        if not on_code_screen(d):
            return True
    return False


# --- setup stage: drive permission/profile screens to the chat list ---------

# Buttons that advance a setup screen, in priority order. Tap the first one
# found on the screen. WhatsApp CTAs first (grant-style for a fuller setup),
# skip-style last (for restore-backup-style screens where skipping is the
# only way forward).
SETUP_BUTTONS = [
    "CONTINUAR", "Continue", "Siguiente", "Next",
    "Permitir", "Allow", "Permitir siempre", "Permitir solo esta vez",
    "S\u00ed", "Yes",                       # Sí (confirm dialogs)
    "ACEPTAR Y CONTINUAR", "Agree and continue",
    "Comenzar", "Get started", "Start messaging",
    "Listo", "Hecho", "Done", "OK", "Aceptar", "Accept",
    "Omitir", "Saltar", "Skip", "AHORA NO", "Not now", "Ahora no",
]

# EditText resource IDs used for the profile-name step.
NAME_FIELDS = ["account_name", "name", "profile_name", "registration_name"]


def fill_name_if_present(d: u2.Device) -> bool:
    """If a profile-name field is showing, fill it with WA_NAME (no tap needed)."""
    for nf in NAME_FIELDS:
        elem = d(resourceId=rid(nf))
        if elem.exists and elem.info.get("className", "").endswith("EditText"):
            print(f"  name field ({nf}) found -- filling {NAME!r}")
            tap_elem(d, elem)
            time.sleep(0.4)
            broadcast_text(d, NAME)
            time.sleep(0.6)
            return True
    return False


def tap_first_setup_button(d: u2.Device) -> bool:
    """Tap the first known setup button on screen. Returns True if one was tapped.

    WhatsApp and the system permission dialogs render button labels in UPPERCASE
    (e.g. "SIGUIENTE", "PERMITIR"), so match case-insensitively with a (?i)
    regex string (textMatches is evaluated server-side by Java's Pattern).
    """
    for label in SETUP_BUTTONS:
        elem = d(textMatches=r"(?i)^" + re.escape(label) + r"$")
        if elem.exists:
            print(f"  tapping [{label}]")
            tap_elem(d, elem)
            return True
    return False


def visible_text(d: u2.Device) -> str:
    xml = d.dump_hierarchy()
    texts = [t for t in re.findall(r'text="([^"]*)"', xml) if t.strip()]
    return "|".join(texts[:8])


def _tap_skip(d: u2.Device) -> bool:
    for label in ("Omitir", "Saltar", "Skip", "AHORA NO", "Not now", "Ahora no"):
        elem = d(textMatches=r"(?i)^" + re.escape(label) + r"$")
        if elem.exists:
            print(f"  tapping skip [{label}]")
            tap_elem(d, elem)
            return True
    return False


def _tap_system_allow(d: u2.Device) -> bool:
    """Tap Allow/Permitir in a system permission popup.

    System dialogs render UPPERCASE ("PERMITIR", "DENEGAR"); match (?i).
    Falls back to DENEGAR (deny still dismisses the dialog and advances setup).
    """
    for label in ("Permitir", "Allow", "Permitir siempre", "While using the app",
                  "Permitir solo esta vez", "Only this time", "DENEGAR", "Deny"):
        elem = d(textMatches=r"(?i)^" + re.escape(label) + r"$")
        if elem.exists:
            print(f"  tapping system dialog [{label}]")
            tap_elem(d, elem)
            return True
    return False


def drive_setup(d: u2.Device) -> bool:
    """Tap through WhatsApp setup screens until the chat list appears.

    Handles contacts/notifications permissions, profile name, restore-backup
    prompt, and welcome intros. Stops at the main screen or after SETUP_ROUNDS.
    """
    print(f"=== setup stage (up to {SETUP_ROUNDS} rounds) ===")
    prev_text = None
    stuck = 0
    for rnd in range(1, SETUP_ROUNDS + 1):
        if on_main_screen(d):
            print("  reached chat list -- WhatsApp is set up")
            return True
        # System permission dialogs (Permitir / Allow) sit in a separate window.
        # Prefer them so a CONTINUAR that triggered one doesn't stall.
        if d(resourceId="android:id/button1").exists:
            print("  confirming system dialog (button1)")
            tap_elem(d, d(resourceId="android:id/button1"))
            time.sleep(2)
            continue
        if fill_name_if_present(d):
            time.sleep(1)
        if tap_first_setup_button(d):
            time.sleep(2.5)
            cur_text = visible_text(d)
            if cur_text == prev_text:
                stuck += 1
                if stuck >= 2:
                    print("  stuck -- trying skip-style")
                    if not _tap_skip(d):
                        dump_screen(d, f"setup-stuck-r{rnd}")
                    time.sleep(2.5)
            else:
                stuck = 0
            prev_text = cur_text
            continue
        if _tap_system_allow(d):
            time.sleep(2)
            continue
        print(f"  round {rnd}: no known setup button -- waiting")
        dump_screen(d, f"setup-no-btn-r{rnd}")
        time.sleep(2)
    return on_main_screen(d)


# --- main -------------------------------------------------------------------

d = u2.connect(DEVICE)
print("Connected to device:", d.info["productName"])

ensure_adbime(d)

# Bring WhatsApp to the foreground if needed
if d.app_current().get("package") != PACKAGE:
    d.app_start(PACKAGE)
    time.sleep(2)

advanced = False

if STAGE in ("auto", "phone") and on_phone_screen(d):
    for attempt in range(1, RETRIES + 1):
        print(f"=== phone attempt {attempt}/{RETRIES} ===")
        if do_phone_stage(d):
            advanced = True
            break
        if attempt < RETRIES:
            print("  retrying in 3s...")
            time.sleep(3)
    if not advanced:
        print("ERROR: could not advance past phone screen", file=sys.stderr)
        sys.exit(1)
elif STAGE == "phone" and not on_phone_screen(d):
    print("Not on phone screen — nothing to do for stage=phone", file=sys.stderr)
else:
    print("Skipping phone step (not on phone screen)")

# Code stage runs if forced, or if we advanced this run, or if we're already
# sitting on the code screen (number already verified, mid-registration).
if STAGE == "code" or (STAGE == "auto" and (advanced or on_code_screen(d))):
    time.sleep(2)
    print("=== code stage ===")
    if on_code_screen(d):
        if not do_code_stage(d):
            print("WARNING: did not leave the code screen", file=sys.stderr)
    elif STAGE == "code":
        print("Not on code screen — nothing to do for stage=code", file=sys.stderr)
    else:
        print("Skipping code (not on code screen — number may already be verified)")
else:
    print("Skipping code stage")

# Setup stage: drive through permission/profile screens to the chat list.
# Runs whenever we're on WhatsApp but not yet at the main screen.
if STAGE in ("auto", "setup") and not on_main_screen(d):
    if d.app_current().get("package") == PACKAGE:
        if not drive_setup(d):
            print("WARNING: did not reach the chat list", file=sys.stderr)
    elif STAGE == "setup":
        print("Not on WhatsApp — nothing to drive for stage=setup", file=sys.stderr)
else:
    if on_main_screen(d):
        print("Already at the chat list — WhatsApp is set up")
    else:
        print("Skipping setup stage")
