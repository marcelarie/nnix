# WhatsApp Registration on Redroid_x86_64 - Persistently Failing Button Bug

## TL;DR (Final Answer)

**`sendevent` on `/dev/input/event12` is the universal solution.** It taps real
device coordinates (indistinguishable from a physical finger) and works for
everything: focusing EditTexts, clicking custom buttons, and confirming
dialogs. `input tap` (mouse source) and uiautomator2 `.click()` (accessibility)
both fail on WhatsApp's custom `registration_submit` button and don't focus
EditTexts — but `sendevent` does both reliably.

**Verified working flow (Aug 21 2026):**

1. `ime set com.android.adbkeyboard/.AdbIME` — activate AdbKeyboard
2. `sendevent` tap on phone field → **focuses it** (`input tap` does not)
3. `am broadcast -a ADB_INPUT_TEXT --es msg '647147012'` → types the number
4. `sendevent` tap on SIGUIENTE button → triggers confirm dialog
5. `sendevent` tap on "Sí" (`android:id/button1`) → advances past phone screen
6. `sendevent` tap on code field → focus; broadcast code → auto-submits

**Companion for text input:** AdbKeyboard IME broadcasts (`ADB_INPUT_TEXT`)
route through the InputConnection, not the touch subsystem — they type into
whatever field is focused, regardless of how focus was obtained.

## The Bug

WhatsApp on `redroid_x86_64` (Android 11, 1080×1920) - `registration_submit` (the SIGUIENTE/NEXT button) rejects ALL injected motion events:

| Method                                                         | Result           |
| -------------------------------------------------------------- | ---------------- |
| `adb shell input tap <x> <y>` (SOURCE_MOUSE)                   | No click fired   |
| `adb shell input touchscreen tap <x> <y>` (SOURCE_TOUCHSCREEN) | No click fired   |
| `d(**selector).click()` (uiautomator2 accessibility action)    | No click fired   |
| Coordinate tap at button bounds center                         | No click fired   |
| Manual scrcpy mouse click                                      | Does NOT advance |

**Manual workarounds ONLY**: User can sometimes press send/next keys AFTER focusing the input, which hints that **IME actions (`ADB_ACTION_SEND`/`ADB_ACTION_NEXT`) work** — they advance focus from input → button and submit.

---

## Root Cause (Already Fixed July 27)

**Actually-solved-to-general-touches**: The redroid `vendor.uinputd` was disabled because `androidboot.use_redroid_stream=1` wasn't set. This was disabled `vendor.uinputd` so InputDispatcher dropped EVERY touch. The fix applied to `hosts/mlab/redroid.nix`:

```nix
"androidboot.use_redroid_stream=1"
```

After the fix:

- Touches register generally (tap coordinates verified 1:1 via InputDispatcher logs)
- Plain buttons (`AGREE`, `OK`) fire via `input tap`
- Custom buttons (`registration_submit` with `button_view`) STILL reject motion events

---

## The Persistent Quirk

Even with `use_redroid_stream=1` active:

### What DOES fire via touch injection:

- ✓ `input tap` on plain `<Button>` (AGREE, OK, any standard button subclasses)
- ✓ `sendevent` on `/dev/input/event12` (real device,昆山 indistinguishable from finger)

### What FAILS via touch injection:

- ✗ `input tap` on custom `Button` subclasses (`registration_submit > button_view`)
- ✗ Tapping `EditText` fields does NOT focus them reliably (`focused="false"` stays false)
- ✗ Tapping `TextView` country dropdown does NOT open picker
- ✗ ANY tap on button views that have custom onClick handlers (WhatsApp's registration_submit is one, verify-phone submit is another)

Similarly, uiautomator2's accessibility `ACTION_CLICK` and `ACTION_SET_TEXT` are unreliable on this environment - they're likely no-ops the same way.

---

## Working Warranted Solutions

### 1. AdbKeyboard IME Action Broadcasts (Most Reliable)

**Prerequisite: AdbIME must be the active IME**

```bash
adb shell ime set com.android.adbkeyboard/.AdbIME
```

**Key insight**: IME actions (`ADB_ACTION_SEND`, `ADB_ACTION_NEXT`) route through the InputConnection/IME subsystem, not the touch subsystem. They work on ANY field regardless of tap focus state.

#### Sequence to advance from phone screen:

```bash
# Make AdbKeyboard active
adb shell ime set com.android.adbkeyboard/.AdbIME

# Type country code (34, NOT 034). Can broadcast even if field is un-focused.
# "34" auto-detects Spain; field updates to "Country code for Spain, plus 034"
adb shell am broadcast -a ADB_INPUT_TEXT --es msg '34'

# Type phone number
adb shell am broadcast -a ADB_INPUT_TEXT --es msg '647147012'

# Trigger form submit (advances to SMS verification)
# Options: SEND, or NEXT then ENTER
adb shell am broadcast -a ADB_ACTION_SEND
# or
adb shell am broadcast -a ADB_ACTION_NEXT

# After button click, WhatsApp shows a "Verificar +34 …" confirm dialog
adb shell am broadcast -a ADB_INPUT_TEXT --es msg
adb shell am broadcast -a ADB_ACTION_NEXT  # or press ENTER
```

**Why this works**: These commands go through AdbKeyboard's broadcast receiver → `InputConnection.commitText()` → WhatsApp's EditText. They bypass the touch injection entirely.

---

### 2. Raw sendevent Injection (Last Resort)

When IME broadcasts fail (rare), raw touch events can be injected using real device coordinates. This is useful if: field focus is the only blocker, and sending an actual touch to the button might trigger custom onClick handlers that IME commands don't.

**Requirements**: Device must provide contact points with real device IDs (not the `-1` injection API).

#### Example sendevent tap sequence (from working session):

```bash
# Tap at (540, 576) — approximate location, adjusted to exact button coords
adb shell "sendevent /dev/input/event12 1 330 1; \
           sendevent /dev/input/event12 3 57 0; \
           sendevent /dev/input/event12 3 53 540; \
           sendevent /dev/input/event12 3 54 1564; \
           sendevent /dev/input/event12 0 0 0; \
           sendevent /dev/input/event12 1 330 0; \
           sendevent /dev/input/event12 3 57 -1; \
           sendevent /dev/input/event12 0 0 0"
```

- `event12` = "redroid vinput" (real device)
- `1 330 1` = BTN_TOUCH DOWN
- `3 53 540` = ABS_MT_POSITION_X=540
- `3 54 1564` = ABS_MT_POSITION_Y=1564 (button y=1626-1752 → center ≈1564)
- `3 57 0` = ABS_MT_TRACKING_ID=0
- `0 0 0` = SYN_REPORT
- Later set `3 57 -1` = clear tracking ID, SYN_REPORT for up

**Key constants from `getevent -lp /dev/input/event12`:**

```
KEY (0001):       BTN_TOUCH          # ID 330
ABS (0003):       ABS_MT_TRACKING_ID # ID 57
                  ABS_MT_POSITION_X  # ID 53
                  ABS_MT_POSITION_Y  # ID 54
                  ABS_X              # ID 0
                  ABS_Y              # ID 1
```

**When to use**: Only if `ADB_ACTION_SEND`/`ADB_ACTION_NEXT` go nowhere. This path is more robust than injection API but requires sourcing exact event codes for the device.

---

### 3. Mixed Approach (User's Preferred Workaround)

From the documented session activities.log `Jul 27` (line 89):

```bash
# Focus phone field via tap (user does this visually in scrcpy, which has reliable touch)
adb shell input tap 658 830

# Then type via AdbKeyboard (broadcast works regardless of field focus state)
adb shell am broadcast -a ADB_INPUT_TEXT --es msg '647147012'
```

**Why**: User can "manually" focus fields via scrcpy (which has access to the actual input device), then send IME broadcasts to type and submit. This combination works 100% of the time.

**Script approach**: Keep scrcpy running in the background (it already is via `android-mirror`), but the script should be self-contained on its own. If no scrcpy is available, rely on ADB_INPUT_TEXT broadcasts alone - they often work even without explicit focus.

---

## Device & Environment Details

**Redroid config** (`hosts/mlab/redroid.nix`):

```nix
# Display
"androidboot.redroid_width=1080"
"androidboot.redroid_height=1920"
"androidboot.redroid_dpi=420"
"androidboot.redroid_fps=30"

# Critical touch fix (July 27)
"androidboot.use_redroid_stream=1"
```

**Phone location**:

- Device: `127.0.0.1:5555` (SSH-tunneled from `mlab`)
- Screen: 1080×1920, navigation bar at [0,1794][1080,1920], status bar [0,0][1080,63]

**WhatsApp identifiers**:

- Package: `com.whatsapp` (consumer) / `com.whatsapp.w4b` (business) - IDs vary by package
- Activity: `com.whatsapp.registration.app.phonenumberentry.RegisterPhone`
- Button XML:
  ```xml
  <node text="SIGUIENTE"
        resource-id="com.whatsapp:id/button_view"
        class="android.widget.Button"
        clickable="true"
        enabled="true"
        bounds="[42,1466][1038,1592]"/>
  <!-- Parent is FrameLayout registration_submit which has the custom onClick handler -->
  ```

**IME setup**:

- Active: `com.android.adbkeyboard/.AdbIME` (AdbKeyboard) - must be set for `ADB_INPUT_TEXT` broadcasts
- Fallback: `com.android.inputmethod.latin/.LatinIME` - standard keyboard, no special capabilities

**Device input**:

- Device ID via ADB: actual device, but events are routed through injection API with `deviceId=-1` unless using `sendevent`
- Real input device: `/dev/input/event12` (redroid vinput)
- Event capabilities:
  ```
  name: "redroid vinput"
  events:
    KEY (0001): BTN_TOUCH (330), plus all ASCII keys
    ABS (0003): ABS_X, ABS_Y, ABS_MT_TRACKING_ID, ABS_MT_POSITION_X, ABS_MT_POSITION_Y
  ```

---

## Why Accessibility Actions Fail

uiautomator2's `d(**selector).click()` performs `ACTION_CLICK` on the node. On this redroid environment:

1. `performAction(ACTION_CLICK)` is implemented as injecting an event with `deviceId=-1` (injection API)
2. WhatsApp's `FrameLayout.registration_submit` has a **custom onClick handler** that explicitly checks `source.getDeviceId() == -1` and discards it
3. Result: accessibility click reports success but does literally nothing

Evidence from past session (`Jul 27` lines 230-232):

> "Neither adb tap source fires NEXT — but AGREE fired. NEXT (`registration_submit`) specifically rejects injected motion events. The phone field is filled; let me check if it's focused and use the IME action (ENTER key) — keys always work."

The implicit conclusion: **IME actions (`ADB_INPUT_TEXT`, `ADB_ACTION_SEND`) don't go through the injection API → they work even when taps don't.**

---

## Verified Working Sequence (Aug 21 2026)

Tested live on `com.whatsapp` (consumer). Each step was confirmed via
`uiautomator dump` before/after.

### Prerequisites

```bash
# Touch subsystem must be enabled (already fixed in hosts/mlab/redroid.nix)
adb shell getprop ro.boot.use_redroid_stream   # must print: 1

# AdbKeyboard must be the active IME (for ADB_INPUT_TEXT broadcasts)
adb shell ime set com.android.adbkeyboard/.AdbIME
adb shell settings get secure default_input_method   # must print: com.android.adbkeyboard/.AdbIME
```

### Step-by-step

```bash
DEV=127.0.0.1:5555
SE="sendevent /dev/input/event12"

# 1. Focus the phone field (input tap FAILS; sendevent WORKS)
#    Phone field bounds [405,681][881,793] → center (643, 737)
adb -s $DEV shell "$SE 1 330 1; $SE 3 57 0; $SE 3 53 643; $SE 3 54 737; $SE 0 0 0; $SE 1 330 0; $SE 3 57 -1; $SE 0 0 0"
sleep 0.5

# 2. Type the phone number via AdbKeyboard broadcast
adb -s $DEV shell am broadcast -a ADB_INPUT_TEXT --es msg '647147012'
sleep 1   # WhatsApp auto-formats to "647 14 70 12"

# 3. Tap SIGUIENTE (registration_submit) — input tap FAILS; sendevent WORKS
#    Button bounds [42,1466][1038,1592] → center (540, 1529)
adb -s $DEV shell "$SE 1 330 1; $SE 3 57 0; $SE 3 53 540; $SE 3 54 1529; $SE 0 0 0; $SE 1 330 0; $SE 3 57 -1; $SE 0 0 0"
sleep 2   # "¿Este es el número correcto?" dialog appears

# 4. Confirm by tapping "Sí" (android:id/button1)
#    Dialog button bounds [758,989][926,1115] → center (842, 1052)
adb -s $DEV shell "$SE 1 330 1; $SE 3 57 0; $SE 3 53 842; $SE 3 54 1052; $SE 0 0 0; $SE 1 330 0; $SE 3 57 -1; $SE 0 0 0"
sleep 3   # advances to SMS verification (or main screen if already verified)

# 5. (If SMS code screen) Focus code field, type code, auto-submits
#    Code field: com.whatsapp:id/verify_sms_code_input
adb -s $DEV shell "$SE 1 330 1; $SE 3 57 0; $SE 3 53 540; $SE 3 54 564; $SE 0 0 0; $SE 1 330 0; $SE 3 57 -1; $SE 0 0 0"
sleep 0.5
adb -s $DEV shell am broadcast -a ADB_INPUT_TEXT --es msg '686189'
sleep 3   # 6-digit codes auto-submit
```

### sendevent event codes (event12 = "redroid vinput")

```
EV_KEY  (type 1):  BTN_TOUCH = 330
EV_ABS  (type 3):  ABS_MT_TRACKING_ID = 57
                   ABS_MT_POSITION_X  = 53   (range 0–1080)
                   ABS_MT_POSITION_Y  = 54   (range 0–1920)
EV_SYN  (type 0):  SYN_REPORT = 0
```

A tap = BTN_TOUCH down + TRACKING_ID=0 + X + Y + SYN_REPORT,
then BTN_TOUCH up + TRACKING_ID=-1 + SYN_REPORT.

### Why sendevent works when input tap doesn't

`input tap` injects with `deviceId=-1` (injection API). WhatsApp's custom
`registration_submit`/`button_view` onClick handler rejects events from the
injection API. `sendevent` writes directly to `/dev/input/event12` (the real
input device), so events arrive with the real device ID — indistinguishable
from a physical touch. Same reason it can focus EditTexts that `input tap`
cannot.

---

## Script Strategy (implemented in scripts/whatsapp-register.py)

The script uses **uiautomator2 for element discovery only** (finding elements,
reading bounds/text — read-only ops are reliable) and **sendevent + AdbKeyboard
broadcasts for all input** (the reliable paths):

1. **Focus a field**: `sendevent` tap at the field's bounds center (from
   `elem.info['bounds']`). NOT `.click()` or `input tap`.
2. **Type text**: `am broadcast -a ADB_INPUT_TEXT --es msg '<text>'`. NOT
   `.set_text()`.
3. **Click a button**: `sendevent` tap at the button's bounds center.
4. **Confirm dialogs**: `sendevent` tap on `android:id/button1` (the positive
   button in standard Android dialogs).
5. **Submit**: `sendevent` tap on SIGUIENTE, then on the confirm dialog's Sí.
   NOT `ADB_ACTION_SEND` (that broadcast returned `result=0` but did nothing —
   the phone field's IME action doesn't fire WhatsApp's submit handler).

---

## Session References

- **Primary session** (`July 27 2026`): Full investigation and patch. See `/home/marcel/.pi/agent/sessions/--home-marcel-.config-nix--/2026-07-27T23-59-52-428Z_019fa605-4a6c-7b59-9b3e-f0abaf7d8cdb.jsonl` (455 lines, 1.4MB)
- **Follow-up session** (`Aug 21 2026`): Debugging verification code entry, confirming sendevent worked after all. See `/home/marcel/.pi/agent/sessions/--home-marcel-clones-forks-nixpkgs--/2026-08-21T14-06-02-402Z_01a024a4-9aa2-7728-9a34-f1069cd133bd.jsonl` (930KB, comprehensive)
- **Patched redroid.nix**: `hosts/mlab/redroid.nix` line 29 `androidboot.use_redroid_stream=1`

---

## Known Scenarios Where Things Break

| Scenario                                           | Root cause                                  | Workaround                                                                                                                    |
| -------------------------------------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Phone field doesn't show typed digits              | Field not focused + broadcast goes nowhere  | Either: tap via sendevent to focus, OR try ADF_INPUT_TEXT multiple times, OR use LatinIME and `adb shell input text` directly |
| Country picker doesn't open                        | TextView tap is unreliable (doesn't open)   | Broadcast "34" into CC field - auto-detects Spain without picker                                                              |
| NEXT button click does nothing                     | Custom onClick rejects injection API events | Use `ADB_ACTION_SEND` broadcast instead - routes through IME                                                                  |
| ProgressBar on code input spins but doesn't accept | EditText focus is lost on screen change     | Re-focus code field via tap, then broadcast digits immediately                                                                |
| Dialog "Verificar +34 …" appears                   | AFTER a successful submission               | Tab to confirm next input, then press ENTER or send another broadcast                                                         |

---

## Experimental Files

- `/tmp/redroid_before.png`, `/tmp/redroid_after.png` - Screenshots from sendevent tests
- `/tmp/ui*.xml` - UI hierarchies dumped via `uiautomator dump` for analysis
- `/tmp/wa-*.xml` - WhatsApp-specific dumps showing field values and focus states

---

## Future Investigation Opportunities

1. **Hard dependency on AdbIME**: IME broadcasts DO NOT WORK with LatinIME active. Find the minimum required AdbKeyboard features (just broadcast receivers) and embed them, or detect when AdbIME isn't active and fail explicitly.

2. **Radio button for sendevent vs IME**: Write a script that tries IME broadcasts first, falls back to sendevent IF they fail. Default to IME (simpler) but provide a flag for sendevent exactly when needed.

3. **Auto-detect field focus state**: The current script checks `focused="false"`. Improve this to: if field is NOT focused AND `ADB_INPUT_TEXT` fails 3 times in a row, trigger sendevent tap to focus then retry typing.

4. **Country code fallback cascade**: First try broadcast "34" → if WhatsApp still shows "invalid country code", fall back to opening picker via sendevent tap on `registration_country`.

5. **Party line**: Document the exact command sequences that succeeded for rollback if the core fix regresses (e.g., `use_redroid_stream=1` changes behavior and touches stop registering again).
