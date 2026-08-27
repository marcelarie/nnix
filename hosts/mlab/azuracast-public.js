(function () {
  // Muted-autoplay-where-allowed + unmute on first user gesture.
  // Chrome/Firefox allow muted autoplay without a gesture; Brave (and Chromium with autoplay
  // disabled) block even muted play() until the user interacts. We probe (see below) and only
  // attempt load-time muted play where it will succeed; where it's blocked we stay paused
  // (flashing PLAY overlay) and start on the first gesture, which is always allowed. The store
  // boots muted (localStorage "player_muted" = "true") so a successful muted autoplay is silent
  // until the user clicks to unmute via the mute button, keeping store + UI in sync.
  try { localStorage.setItem('player_muted', 'true'); } catch (e) {}

  var pb = function () { return document.querySelector('.radio-control-play-button'); };
  var mb = function () { return document.querySelector('.radio-control-volume .btn'); };
  var au = function () { return document.querySelector('audio'); };

  // --- debug (gated on ?azdebug); remove once autoplay is confirmed ---
  var DBG = (function () {
    if (location.search.indexOf('azdebug') === -1) return function () {};
    var log = (window.__azLog = []);
    function d() { var a = [].slice.call(arguments); log.push(((performance.now() / 100) | 0) + ' ' + a.join(' ')); try { console.log.apply(console, a); } catch (e) {} }
    d('azdebug ON');
    function attachAudio() {
      var a = au();
      if (!a || a._azDbg) return; a._azDbg = 1;
      ['play', 'playing', 'pause', 'ended', 'error', 'suspend', 'stalled', 'emptied', 'loadstart', 'canplay', 'waiting', 'abort', 'ratechange'].forEach(function (ev) {
        a.addEventListener(ev, function () { d('audio.' + ev, 'paused=' + a.paused, 'muted=' + a.muted, 'readyState=' + a.readyState, a.error ? ('err=' + a.error.code) : ''); }, true);
      });
    }
    setInterval(attachAudio, 200);
    function watchBtn(sel, label) {
      var b = document.querySelector(sel);
      if (!b || b._azDbg) return; b._azDbg = 1;
      new MutationObserver(function () { d(label, 'icon-> isPlaying=' + isPlaying() + ' isMuted=' + isMuted()); }).observe(b, { childList: true, subtree: true, attributes: true });
    }
    setInterval(function () { watchBtn('.radio-control-play-button', 'PLAYBTN'); watchBtn('.radio-control-volume .btn', 'MUTEBTN'); }, 200);
    // attachAudio only ever instruments document.querySelector('audio') - the FIRST one. If
    // AzuraCast ever leaves a stale element behind while playing through a new one, every event
    // on the live element is invisible above, so report the count whenever it changes.
    var lastCount = -1;
    setInterval(function () {
      var els = document.querySelectorAll('audio');
      if (els.length === lastCount) return;
      lastCount = els.length;
      var st = [];
      for (var i = 0; i < els.length; i++) st.push(i + ':paused=' + els[i].paused + ',t=' + els[i].currentTime.toFixed(1) + ',rs=' + els[i].readyState);
      d('AUDIO ELEMENTS n=' + els.length, st.join(' | '));
    }, 250);
    return d;
  })();

  // --- stream auto-recovery ---
  // A network interruption (confirmed via ?azdebug: net::ERR_NETWORK_CHANGED -> audio
  // 'waiting' -> 'stalled') can kill the stream without the browser or AzuraCast ever
  // reconnecting on their own - and since it's the same underlying network change, it often
  // takes the SSE metadata feed down with it too (title/art then look frozen). Recovery is
  // what already works manually: toggle the real play button.
  //
  // Liveness is judged by currentTime ADVANCING, not by media events. The previous version
  // listened for 'playing' to decide the stream was healthy again, bound via a 500ms poll
  // because AzuraCast swaps the <audio> element on every play toggle. That was a race it lost
  // constantly: the retry's own b.click() swaps in a new element, and when that element fired
  // 'playing' inside the 500ms window the event was missed, "healthy" was never set, and 8s
  // later the watchdog retried - swapping the element and re-losing the event, forever. Icecast's
  // access log showed the result: a new radio.mp3 connection every 8s, each killed at exactly
  // 8s, each delivering ~31KB/s of a 24KB/s stream. It was strangling a perfectly healthy
  // stream, at 20-40 reconnects per 10 minutes against an actual fault rate of ~1 uplink flap
  // per day. A stream that is playing always advances currentTime, so polling progress has no
  // event to miss and cannot misfire on a healthy stream.
  var lastEl = null, lastT = -1, seenProgress = false, stalledSince = 0;
  var STALL_MS = 10000;   // zero progress this long while unpaused = a real outage, not a blip
  function resetProgress(a) {
    lastEl = a;
    lastT = a ? a.currentTime : -1;
    seenProgress = false;
    stalledSince = 0;
  }
  setInterval(function () {
    var a = au();
    // paused is the user's choice, not ours to "fix"; no element yet means nothing to watch
    if (!a || a.paused) { resetProgress(a); return; }
    // element swapped -> rebase, don't compare currentTime across two different elements
    // (the new one restarts near 0, which would read as a huge backwards jump)
    if (a !== lastEl) { resetProgress(a); return; }
    // abs(), not >: a backward jump (the browser reconnecting internally on the same element
    // restarts currentTime near 0) also proves the element is alive and doing something. With a
    // forward-only test, lastT would stay stuck at the old high-water mark and every subsequent
    // second would read as "no progress" -> a retry on a stream that is in fact playing fine.
    if (Math.abs(a.currentTime - lastT) > 0.1) {  // moving at all -> healthy, by definition
      lastT = a.currentTime;
      seenProgress = true;
      stalledSince = 0;
      return;
    }
    // Only ever act on "was playing, then stopped". A stream that never started at all belongs
    // to the autoplay / ensurePlaying() path below, and clicking at it from here would fight it.
    if (!seenProgress) return;
    if (!stalledSince) stalledSince = performance.now();
    if (performance.now() - stalledSince < STALL_MS) return;
    stalledSince = 0;                           // give this retry a full fresh window
    DBG('recovery: soft retry (no progress for ' + STALL_MS + 'ms)');
    var b = pb();
    if (b) { b.click(); setTimeout(function () { var b2 = pb(); if (b2) b2.click(); }, 300); }
  }, 1000);

  // Brave (and Chromium with autoplay disabled) block even muted play() until the user
  // interacts. AzuraCast flips isPlaying=true *before* play() resolves, so a blocked
  // muted-autoplay desyncs the store (play button shows "pause", but audio is silent) and
  // the gesture handler below trusts that icon and never restarts -> dead silence.
  // So: probe muted autoplay first, and only attempt load-time play where it will succeed.
  // Where it's blocked we stay paused (flashing PLAY overlay) and start on the first user
  // gesture, which is always allowed. Any NotAllowedError that slips past is swallowed so
  // the console stays clean; the gesture handler recovers playback regardless.
  window.addEventListener('unhandledrejection', function (e) {
    if (e && e.reason && e.reason.name === 'NotAllowedError') e.preventDefault();
  });

  var started = false, iv, autoplayOk = null;  // null = probe pending; true/false once resolved
  (function probe() {
    try {
      var a = new Audio();
      a.muted = true;
      a.src = 'data:audio/wav;base64,UklGRiYAAABXQVZFZm10IBAAAAABAAEAIlYAAESsAAAQABAAZGF0YQIAAAAAAA==';
      var p = a.play();
      if (p && p.then) p.then(
        function () { autoplayOk = true; },
        function (err) {
          if (err && err.name === 'NotAllowedError') { autoplayOk = false; clearInterval(iv); }
          else autoplayOk = true;   // any other failure (e.g. bad src) isn't an autoplay block
        }
      );
      else autoplayOk = true;
    } catch (e) { autoplayOk = false; clearInterval(iv); }
  })();

  function start() { DBG('start', 'started=' + started, 'autoplayOk=' + autoplayOk); if (started) return; if (autoplayOk !== true) return; var b = pb(); if (!b) return; started = true; clearInterval(iv); DBG('start -> b.click()'); b.click(); }
  // AzuraCast fires 'now-playing' on the document when stream metadata arrives (same hook native autoplay uses).
  document.addEventListener('now-playing', function () { setTimeout(start, 0); }, { once: true });
  iv = setInterval(function () { if (pb()) setTimeout(start, 0); }, 300);
  setTimeout(function () { clearInterval(iv); }, 10000);

  function cleanup() {
    ['pointerdown', 'keydown', 'touchstart', 'wheel'].forEach(function (ev) {
      window.removeEventListener(ev, unmute, true);
    });
  }
  // Trust the <audio> element's real state, NOT the play-button icon. On mobile, the probe may
  // pass (a muted data: WAV plays) so start() auto-clicks the play button with NO user gesture;
  // the real stream play() (deferred to a nextTick, no activation) is blocked, but AzuraCast has
  // already flipped isPlaying=true -> store desyncs (icon says "playing", audio is paused). The
  // gesture handler used to trust the icon and never restart -> dead silence. So: if the audio
  // is actually paused, call play() directly inside this user gesture (always allowed on mobile),
  // resuming the already-loaded stream; only if no stream is loaded yet do we click the play
  // button to make AzuraCast load+play it.
  function ensurePlaying() {
    var a = au();
    if (a && !a.paused) { DBG('ensurePlaying: already playing -> unmute'); unmuteAfterPlay(); return; }
    if (a && a.src) {                                       // paused but stream loaded (autoplay blocked / desynced)
      a.muted = isMuted();
      DBG('ensurePlaying: paused+src -> a.play() in gesture (muted=' + a.muted + ')');
      var p = a.play(); if (p && p.catch) p.catch(function () {});
      unmuteAfterPlay();
      return;
    }
    DBG('ensurePlaying: no src -> b.click() start');
    started = true; clearInterval(iv);
    var b = pb(); if (b) b.click();                          // no stream loaded -> AzuraCast loads+plays in nextTick
    unmuteAfterPlay();
  }

  function unmute(e) {
    initEq();   // first user gesture -> boot the Web Audio analyser (needs a gesture)
    DBG('unmute', e.type, 'isPlaying=' + isPlaying(), 'isMuted=' + isMuted(), 'audioPaused=' + (au() ? au().paused : 'no-audio'), 'target=' + (e.target && (e.target.className || e.target.tagName)));
    // pointer/touch on the album art precede a click handled by the art click handler (start+unmute); defer those.
    if ((e.type === 'pointerdown' || e.type === 'touchstart') &&
        e && e.target && e.target.closest && e.target.closest('.now-playing-art')) { DBG('unmute: defer to art handler'); return; }
    // Anti-seizure button: a UI toggle, not a "start the radio" gesture. Return BEFORE cleanup()
    // so the listeners stay bound and the next real gesture still starts playback.
    if (e && e.target && e.target.closest && e.target.closest('.az-calm-btn')) { DBG('unmute: on calm btn, skip'); return; }
    cleanup();
    if (e && e.target && e.target.closest) {
      // let the volume/mute control and the play button run their OWN real click (avoids a
      // double-toggle: our synthetic b.click() + the real click = start then stop = "split second then stops")
      if (e.target.closest('.radio-control-volume')) { DBG('unmute: on volume ctrl, skip'); return; }
      if (e.target.closest('.radio-control-play-button')) { DBG('unmute: on play btn, just unmute-after'); unmuteAfterPlay(); return; }
    }
    ensurePlaying();
  }
  // Toggle play/pause from any user gesture (album-art click or Space key).
  // Pauses only when actually playing AND unmuted; otherwise starts/unmutes,
  // trusting the real <audio> state (not the play-button icon) -> same logic as the art click.
  function togglePlayPause() {
    initEq();   // spacebar gesture -> boot analyser (idempotent)
    cleanup();
    var a = au(), b = pb();
    if (a && !a.paused && !isMuted()) { if (b) b.click(); }   // playing+unmuted -> pause
    else { ensurePlaying(); }                                 // paused or muted -> start/unmute
  }
  // Zoom lightbox trigger, shared between the ZOOM corner click and the 'z' keydown below.
  // triggeringZoom guards against double-handling: link.click() bubbles a click back up through
  // .now-playing-art, which the art click handler (see relocate()) would otherwise also catch.
  var triggeringZoom = false;
  function triggerZoom() {
    var link = document.querySelector('.radio-player-widget .now-playing-art a.album-art');
    if (!link) return;
    triggeringZoom = true; link.click(); triggeringZoom = false;
  }

  // Spacebar toggles play/pause; ArrowUp/ArrowDown raise/lower volume; z toggles the album
  // art zoom lightbox; m toggles mute (same as clicking the mute button). Registered BEFORE
  // the window 'unmute' keydown (capture, passive) so stopImmediatePropagation stops it also
  // firing ensurePlaying (which would re-start right after a pause). preventDefault stops the
  // page scrolling on Space / arrow keys. Skipped while focus is in an input/textarea/
  // contenteditable so we don't hijack typing a space/z/m — and so a focused volume slider
  // keeps its native arrow handling instead of double-applying.
  window.addEventListener('keydown', function (e) {
    var isSpace = (e.key === ' ' || e.code === 'Space');
    var isVol = (e.key === 'ArrowUp' || e.key === 'ArrowDown');
    var isZoom = (e.key === 'z' || e.key === 'Z');
    var isMute = (e.key === 'm' || e.key === 'M');
    if (!isSpace && !isVol && !isZoom && !isMute) return;
    var t = e.target;
    // Only defer to a REAL text-entry control. The old check also matched the volume
    // <input type=range> whenever it had focus (e.g. right after dragging it), silently
    // swallowing Space/z. The range input still keeps its own native arrow-key handling
    // when focused (isVol below), just not at the cost of blocking the other keys too.
    if (t && (t.isContentEditable || /^(TEXTAREA|SELECT)$/.test(t.tagName) || (t.tagName === 'INPUT' && t.type !== 'range'))) return;
    if (isVol && t && t.tagName === 'INPUT' && t.type === 'range') return;
    e.preventDefault();
    e.stopImmediatePropagation();      // block the 'unmute' keydown (same target+phase, reg'd later)
    if (isSpace) {
      if (e.repeat) return;            // held Space: still block scroll, but don't toggle again
      togglePlayPause();
    } else if (isZoom) {
      if (e.repeat) return;
      triggerZoom();
    } else if (isMute) {
      if (e.repeat) return;
      var m = mb(); if (m) m.click();  // same real click the mute button itself would get
    } else {
      bumpVolume(e.key === 'ArrowUp' ? 5 : -5);   // repeats allowed: hold to ramp volume
    }
  }, true);
  ['pointerdown', 'keydown', 'touchstart', 'wheel'].forEach(function (ev) {
    window.addEventListener(ev, unmute, { capture: true, passive: true });
  });

  // Read play state from the real button's SVG icon (the store's isPlaying, locale-independent):
  // stop-circle icon (path has "H8V8") = playing; play-circle icon (triangle) = paused.
  function isPlaying() {
    var b = pb();
    if (!b) return false;
    var p = b.querySelector('path');
    return !!(p && (p.getAttribute('d') || '').indexOf('H8V8') !== -1);
  }
  // Read mute state from the volume button's SVG icon (locale-independent):
  // volume-off icon (path has "4.27 3L3 4.27") = muted; volume-down/up = unmuted.
  function isMuted() {
    var m = mb();
    if (!m) return false;
    var p = m.querySelector('path');
    return !!(p && (p.getAttribute('d') || '').indexOf('4.27 3L3 4.27') !== -1);
  }

  // Arrow keys adjust volume by setting the range input's value and dispatching an 'input' event,
  // which Vue's v-model picks up and updates the store's `volume` ref. The store synchronously
  // sets `audio.volume` (via logVolume) and persists to localStorage. If muted, unmute on up so
  // the change is audible; down on a muted stream does nothing (already silent).
  var VOL_STEP = 5;
  function bumpVolume(delta) {
    var input = document.querySelector('.radio-control-volume .form-range');
    if (!input) return;                       // iOS: volume controls disabled (audio.volume not settable)
    var raw = Number(input.value);
    var cur = isNaN(raw) ? 50 : raw;             // NOT `|| 50` -> that treats a real 0 as falsy and jumps to 50
    var nv = Math.max(0, Math.min(100, cur + delta));
    if (nv === cur) return;
    input.value = nv;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    // unmute first on up so the change is audible (volume change while muted is silent)
    if (delta > 0 && nv > 0 && isMuted()) {
      var m = mb();
      if (m) m.click();
    }
  }

  // Drives the mushroom<->mouth volume-bar theme (see CSS): --vol (0-1) on the volume
  // control lets the track fill and the mouth glow react to the SAME number. Delegated on
  // document (bubbles) so it works regardless of when Vue mounts the input; bumpVolume's
  // synthetic 'input' event triggers it too. Rising edge into max (mushroom reaches the
  // mouth) spawns the "1UP" (see .az-1up in CSS); falling edge just resets the flag so it
  // can fire again next time volume is pushed back to max.
  function syncVolVar(input) {
    var vol = document.querySelector('.radio-control-volume');
    if (!vol) return;
    var frac = (Number(input.value) || 0) / 100;
    vol.style.setProperty('--vol', frac);
    if (frac >= 1) {
      if (!input._azMaxed) { input._azMaxed = true; spawn1Up(vol); }
    } else {
      input._azMaxed = false;
    }
  }
  function spawn1Up(vol) {
    var el = document.createElement('span');
    el.className = 'az-1up';
    el.textContent = '1UP';
    el.addEventListener('animationend', function () { el.remove(); });
    vol.appendChild(el);
  }
  document.addEventListener('input', function (e) {
    if (e.target.matches && e.target.matches('.radio-control-volume .form-range')) syncVolVar(e.target);
  }, true);

  // Unmute WITHOUT racing play(). AzuraCast's play() runs in a Vue nextTick and reads isMuted
  // at that moment. If we toggle the store (m.click) before that nextTick, Vue flushes the
  // isMuted watcher first -> play() is called UNMUTED -> blocked on mobile (unmuted play needs
  // a fresh gesture; the microtask loses it). So the store must stay MUTED until play() lands,
  // then we unmute on the 'play' event (unmuting an already-playing element needs no gesture).
  //
  // Tricky case: on first interaction there's no <audio> in the DOM yet — AzuraCast creates
  // it in that same nextTick. We must NOT unmute now (that flips the store unmuted before the
  // audio exists, so AzuraCast's play() runs unmuted -> blocked). Instead wait for the <audio>
  // to be inserted (MutationObserver, a microtask — fires before the 'play' event task), then
  // attach the unmute listener so the store flips only after muted play() succeeds.
  function doUnmute(a) {
    if (!a.paused) {                       // already playing (muted) -> unmute now, no new play()
      DBG('doUnmute: playing -> unmute now');
      if (isMuted()) { var m = mb(); if (m) m.click(); }
      return;
    }
    var fire = function () {              // muted play() will land -> unmute the store then
      a.removeEventListener('play', fire);
      DBG('doUnmute: play event -> unmute');
      if (isMuted()) { var m = mb(); if (m) m.click(); }
    };
    a.addEventListener('play', fire, { once: true });
    setTimeout(function () {              // safety: if 'play' never fires (load stall), unmute after 2s
      a.removeEventListener('play', fire); DBG('doUnmute: 2s safety', 'isMuted=' + isMuted());
      if (isMuted()) { var m = mb(); if (m) m.click(); }
    }, 2000);
  }
  function unmuteAfterPlay() {
    var a = au();
    if (a) { doUnmute(a); return; }
    DBG('unmuteAfterPlay: no <audio> yet -> wait for insertion (keep store muted)');
    var obs = new MutationObserver(function () {
      var na = au();
      if (na) { obs.disconnect(); DBG('audio appeared -> doUnmute', 'paused=' + na.paused); doUnmute(na); }
    });
    obs.observe(document.documentElement, { childList: true, subtree: true });
    setTimeout(function () { obs.disconnect(); }, 3000);   // stop watching after 3s
  }

  // Album art overlay: flashing PLAY/PAUSE text (center) + ZOOM corner.
  // Clicking the art toggles play/pause (the <a> lightbox is blocked); the zoom corner opens the lightbox.
  function relocate() {
    var art = document.querySelector('.radio-player-widget .now-playing-art');
    var b = pb();
    var vi = document.querySelector('.radio-control-volume .form-range');
    if (vi && !vi._azVolSynced) { vi._azVolSynced = true; syncVolVar(vi); }
    if (!art || !b || art._azInit) return !!(art && b);
    art._azInit = true;

    var ov = document.createElement('div');
    ov.className = 'az-overlay-play';
    art.appendChild(ov);

    var zm = document.createElement('div');
    zm.className = 'az-zoom';
    zm.textContent = 'ZOOM';
    art.appendChild(zm);

    function sync() {
      var playing = isPlaying();
      var label = playing ? 'PAUSE' : 'PLAY';
      if (ov.textContent !== label) ov.textContent = label;
      art.classList.toggle('az-paused', !playing);
    }
    // MutationObserver: the button's icon swaps when isPlaying changes -> update immediately.
    new MutationObserver(sync).observe(b, { childList: true, subtree: true, attributes: true });
    setInterval(sync, 500);              // safety-net poll
    sync();

    art.addEventListener('click', function (e) {
      if (triggeringZoom) return;                          // synthetic click from zoom corner/'z' key -> let <a> lightbox fire
      if (e.target.closest('.az-zoom')) {                  // zoom corner -> open lightbox via the <a>
        e.stopPropagation(); e.preventDefault();
        triggerZoom();
        return;
      }
      e.stopPropagation(); e.preventDefault();             // block <a> lightbox; image click toggles play
      togglePlayPause();                                  // pause if playing+unmuted, else start/unmute (trusting real audio state)
      setTimeout(sync, 0);                                 // reflect the new state immediately
    }, true);
    return true;
  }
  // Persistent: .now-playing-art is behind a v-if on song.art, so an art-less track destroys
  // the container and the overlay/click handlers along with it. Guarded per node by art._azInit.
  setInterval(relocate, 200);

  // --- real audio-reactive equalizer, multiple LINES (placeholder; custom visualizer later) ---
  // One Web Audio AnalyserNode taps the <audio>; several SVG path ribbons trace different frequency
  // bands, each its own color + granularity + smoothing -> layered, never fake. DOM is built
  // eagerly (polled) so the 44px slot is reserved from page load -> no layout shift on fade.
  // AudioContext is lazy (needs a gesture) so muted autoplay isn't blocked. Same-origin guard: a
  // cross-origin stream bound to MediaElementSource taints it -> silence, so we skip (audio safe).
  // Per-track smoothing is done in JS (analyser smoothing is global): analyser reads raw (0), each
  // track keeps its own smoothed buffer -> bass smooth, mids spiky, highs very spiky. Max-per-point
  // sampling preserves peaks (granularity). Reliability: eqFrame re-binds each new <audio>
  // (AzuraCast swaps it across pause/play; binding is one-shot per element) and resumes a
  // Chrome-auto-suspended context so data doesn't go flat.
  var eqCtx, eqAn, eqSrc, eqData, eqRAF, eqInit, eqBoundEl, eqBox, eqLastSound = 0;
  // band = fraction of frequency bins [lo,hi]; pts = granularity; smooth = per-track smoothing
  // (0=raw/spiky, 1=frozen); amp = vertical amplitude (fraction of half-height).
  var EQ_TRACKS = [
    { color: '#00e5ff', band: [0.00, 0.15], pts: 24, smooth: 0.6,  amp: 0.7 },  // bass -> smooth,       cyan
    { color: '#ff3df0', band: [0.15, 0.50], pts: 56, smooth: 0.12, amp: 0.9 },  // mid  -> grainier,     magenta
    { color: '#ffe600', band: [0.50, 1.00], pts: 90, smooth: 0.03, amp: 1.0 }   // high -> very grainy,  yellow
  ];
  function buildEqDom() {
    if (eqBox) return;
    var host = document.querySelector('.radio-player-widget');
    if (!host) return;
    eqBox = document.createElement('div'); eqBox.className = 'az-eq';
    var NS = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 100 40');
    svg.setAttribute('preserveAspectRatio', 'none');
    EQ_TRACKS.forEach(function (t, i) {
      t.el = document.createElementNS(NS, 'path');
      t.el.setAttribute('fill', t.color);
      t.el.style.opacity = 0.9 - i * 0.12;            // back lines slightly fainter so the front reads
      svg.appendChild(t.el);
      t.sm = new Float32Array(t.pts);                  // per-track smoothed buffer
    });
    eqBox.appendChild(svg);
    var main = host.querySelector('.now-playing-main');   // same column as title/artist, where the time-display bar used to sit
    if (main) main.appendChild(eqBox);
    else {
      var ctrl = host.querySelector('.radio-controls');
      if (ctrl) host.insertBefore(eqBox, ctrl); else host.appendChild(eqBox);
    }
  }
  var eqdiv = setInterval(function () { if (document.querySelector('.radio-player-widget')) { buildEqDom(); clearInterval(eqdiv); } }, 200);
  setTimeout(function () { clearInterval(eqdiv); }, 10000);
  function initEq() {
    if (eqInit) return; eqInit = true;
    buildEqDom();                       // safety: ensure DOM exists even if the poll hasn't fired yet
    try {
      eqCtx = new (window.AudioContext || window.webkitAudioContext)();
      eqAn = eqCtx.createAnalyser();
      eqAn.fftSize = 256;               // 128 bins -> enough to slice into 3 bands
      eqAn.smoothingTimeConstant = 0;   // raw -> per-track smoothing in JS (each line its own feel)
      eqAn.connect(eqCtx.destination);
      eqData = new Uint8Array(eqAn.frequencyBinCount);
    } catch (e) { eqCtx = null; return; }
    if (!eqRAF) eqFrame();
  }
  function attachEqSource(a) {
    if (!eqCtx || !a || a === eqBoundEl) return;
    if (a._azEqSrc) { eqBoundEl = a; return; }          // already bound -> just record
    a._azEqSrc = 1;
    try {
      if (new URL(a.src || '', location.href).origin !== location.origin) { eqBoundEl = a; return; }  // cross-origin -> skip (would silence)
      eqSrc = eqCtx.createMediaElementSource(a);
      eqSrc.connect(eqAn);
      a.addEventListener('play', function () { if (eqCtx && eqCtx.state === 'suspended') eqCtx.resume(); });
    } catch (e) { /* already bound to another context / unavailable -> no viz */ }
    eqBoundEl = a;
  }
  function eqFrame() {
    eqRAF = requestAnimationFrame(eqFrame);
    var a = au();
    if (a && a !== eqBoundEl) attachEqSource(a);         // <audio> swapped across pause/play -> rebind
    if (eqCtx && eqCtx.state === 'suspended') eqCtx.resume();   // Chrome auto-suspends idle contexts
    if (!eqAn || !a || a.paused || isMuted() || !eqBox || !EQ_TRACKS[0].el) {
      if (eqBox) eqBox.style.opacity = 0;
      setBgFx(0, 0, 0, 0);                // paused/muted -> background goes still
      return;
    }
    eqAn.getByteFrequencyData(eqData);
    var len = eqData.length, gmax = 0, peaks = [0, 0, 0];
    for (var k = 0; k < EQ_TRACKS.length; k++) {
      var t = EQ_TRACKS[k];
      var b0 = Math.floor(t.band[0] * len);
      var b1 = Math.max(b0 + 1, Math.floor(t.band[1] * len));
      var span = b1 - b0, top = [], bot = [];
      for (var i = 0; i < t.pts; i++) {
        var s0 = b0 + Math.floor(i / t.pts * span);
        var s1 = Math.max(s0 + 1, b0 + Math.floor((i + 1) / t.pts * span));
        var v = 0;
        for (var j = s0; j < s1 && j < b1; j++) if (eqData[j] > v) v = eqData[j];   // max -> spikes (granularity)
        v = Math.min(255, v * 1.3);                                                   // gain -> lift detail
        if (v > gmax) gmax = v;
        t.sm[i] = t.sm[i] * t.smooth + v * (1 - t.smooth);                           // per-track smoothing
        if (t.sm[i] > peaks[k]) peaks[k] = t.sm[i];                                  // per-band peak this frame -> drives the background fx
        var x = i / (t.pts - 1) * 100;
        var cy = 20 - (t.sm[i] / 255) * (t.amp * 15);                                // centerline (baseline y=20, rises with level)
        var th = 1.5 + (t.sm[i] / 255) * 5;                                          // thickness ∝ level: loud = fat, quiet = thin (real, sound-driven)
        top.push(x.toFixed(1) + ',' + (cy - th / 2).toFixed(1));
        bot.unshift(x.toFixed(1) + ',' + (cy + th / 2).toFixed(1));                  // reverse order -> path closes cleanly R-to-L
      }
      t.el.setAttribute('d', 'M' + top.join(' L') + ' L' + bot.join(' L') + ' Z');
    }
    if (gmax > 8) eqLastSound = performance.now();
    eqBox.style.opacity = (performance.now() - eqLastSound < 250) ? '1' : '0';
    setBgFx(gmax / 255, peaks[0] / 255, peaks[1] / 255, peaks[2] / 255);
  }
  // Background vibrate + glow, driven by the same analyser data as the equalizer:
  // bass -> zoom pulse, mid/high -> a small shake offset, overall loudness -> glow strength.
  // Color follows whichever band is loudest (matches the eq track colors).
  //
  // Drop detection: bgBassAvg is a slow rolling average of the bass band ("what's normal
  // right now"). A frame where bass suddenly jumps well above that average is a hit (kick/drop),
  // not just a loud sustained bassline. Each hit relocates the glow to a random spot and injects
  // bgDropEnergy, which exponentially decays over the next ~0.3-0.5s -> a punch, not a toggle.
  var bgFxRoot = document.documentElement.style;
  var bgBassAvg = 0, bgDropEnergy = 0, bgLastHit = 0;
  // Glow dodges the cursor: bgGlowBaseX/Y is where a bass hit relocated it to; applyGlowPos
  // pushes that point away from the last known mouse position when the cursor gets close,
  // so the light "escapes" instead of sitting under it. Skipped entirely as pure motion under
  // prefers-reduced-motion (CSS already hides the ::after layer there).
  var bgGlowBaseX = 50, bgGlowBaseY = 35, bgMouseX = -9999, bgMouseY = -9999;
  var GLOW_DODGE_R = 260; // px
  function applyGlowPos() {
    var w = window.innerWidth, h = window.innerHeight;
    var bx = bgGlowBaseX / 100 * w, by = bgGlowBaseY / 100 * h;
    var dx = bx - bgMouseX, dy = by - bgMouseY;
    var dist = Math.sqrt(dx * dx + dy * dy);
    var fx = bx, fy = by;
    if (dist < GLOW_DODGE_R && dist > 0.01) {
      var push = GLOW_DODGE_R - dist;
      fx = bx + (dx / dist) * push;
      fy = by + (dy / dist) * push;
    }
    bgFxRoot.setProperty('--az-glow-x', Math.max(0, Math.min(100, fx / w * 100)).toFixed(1) + '%');
    bgFxRoot.setProperty('--az-glow-y', Math.max(0, Math.min(100, fy / h * 100)).toFixed(1) + '%');
  }
  if (!window.matchMedia || !window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    window.addEventListener('mousemove', function (e) {
      bgMouseX = e.clientX; bgMouseY = e.clientY;
      applyGlowPos();
    });
  }
  function setBgFx(punch, bassN, midN, highN) {
    bgBassAvg = bgBassAvg * 0.97 + bassN * 0.03;
    var now = performance.now();
    if (bassN > 0.35 && bassN > bgBassAvg * 1.35 && now - bgLastHit > 120) {
      bgLastHit = now;
      bgDropEnergy = 1;
      bgGlowBaseX = 15 + Math.random() * 70;
      bgGlowBaseY = 15 + Math.random() * 60;
      applyGlowPos();
    } else {
      bgDropEnergy *= 0.90;
    }
    bgFxRoot.setProperty('--az-bg-scale', (1 + bassN * 0.045 + bgDropEnergy * 0.14).toFixed(4));
    bgFxRoot.setProperty('--az-bg-x', ((midN - 0.5) * 14).toFixed(2) + 'px');
    bgFxRoot.setProperty('--az-bg-y', ((highN - 0.5) * 10).toFixed(2) + 'px');
    bgFxRoot.setProperty('--az-glow-opacity', Math.min(0.75, punch * 0.5 + bgDropEnergy * 0.5).toFixed(3));
    bgFxRoot.setProperty('--az-glow-color', bassN >= midN && bassN >= highN ? '#1e40ff' : (midN >= highN ? '#ff3df0' : '#ffe600'));
  }

  // Marquee: scroll title/artist side-to-side when text overflows its column.
  var GAP = 48, SPEED = 60; // px/s
  function updateMarquee(el) {
    var text = (el.textContent || '').trim();
    if (text !== el.getAttribute('data-az-text')) el.setAttribute('data-az-text', text);
    el.classList.remove('az-marquee');          // measure in block state (no ::after)
    var textW = el.scrollWidth, cw = el.clientWidth;
    if (textW > cw + 1) {                        // overflow -> scroll
      el.style.setProperty('--az-shift', -(textW + GAP) + 'px');
      el.style.setProperty('--az-dur', Math.max(6, Math.min(20, (textW + GAP) / SPEED)) + 's');
      el.classList.add('az-marquee');
    }
  }
  function setupMarquee() {
    ['.now-playing-title', '.now-playing-artist'].forEach(function (sel) {
      var el = document.querySelector('.radio-player-widget ' + sel);
      if (!el || el._azMarquee) return;
      el._azMarquee = true;
      var isArtist = sel === '.now-playing-artist';
      if (isArtist) applyArtistLink();
      updateMarquee(el);
      // Vue updates the text node -> re-measure. attributes (class/style) excluded -> no self-loop.
      new MutationObserver(function () { updateMarquee(el); if (isArtist) applyArtistLink(); }).observe(el, { childList: true, subtree: true, characterData: true });
    });
  }
  // Persistent for the same reason as the art watcher: Player.vue renders the title/artist in
  // one of three keyed v-if branches (offline / title+artist / text-only), so whenever
  // is_online or song.title changes truthiness Vue throws the h4/h5 away and builds new ones.
  // That happens on every stream interruption - precisely when the uplink flaps. Stopping the
  // poll after 10s left the marquee observer bound to a detached node, so from then on the
  // title never re-measured: long names silently stopped scrolling and the bandcamp artist link
  // stopped being re-applied. setupMarquee is a guarded no-op per node (el._azMarquee).
  setInterval(setupMarquee, 300);
  var rt;
  window.addEventListener('resize', function () { clearTimeout(rt); rt = setTimeout(setupMarquee, 150); });

  // Keyboard-shortcut hint: pinned to the bottom-right corner of now-playing-details (see
  // CSS .az-hint), not its own row below the controls, so it adds no extra card height.
  // Lives inside now-playing-details (not the outer widget) for the same reason the volume
  // control does: that's the box position:relative is actually set on and that matches the
  // card's real bounds, so the hint stays inside the card instead of creating a bottom "chin".
  // Desktop only — CSS hides it under 768px (touch devices have no arrow keys).
  function setupHint() {
    var host = document.querySelector('.radio-player-widget .now-playing-details');
    if (!host || host.querySelector('.az-hint')) return !!host;
    var h = document.createElement('div');
    h.className = 'az-hint';
    h.textContent = '↑/↓ volume  ·  space play/pause  ·  m mute  ·  z zoom';
    host.appendChild(h);
    return true;
  }
  var hiv = setInterval(function () { if (setupHint()) clearInterval(hiv); }, 300);
  setTimeout(function () { clearInterval(hiv); }, 10000);

  // --- anti-seizure toggle ---
  // Everything it disables (background zoom/shake, beat glow, animated text colors) is driven
  // by CSS, so one class on <html> is the whole switch - see html.az-calm in the CSS. The class
  // is applied before the button exists so a reloaded page never flashes the effects first.
  (function () {
    var CALM_KEY = 'az_calm';
    var calm = false;
    try { calm = localStorage.getItem(CALM_KEY) === '1'; } catch (e) {}
    document.documentElement.classList.toggle('az-calm', calm);
    function addCalmButton() {
      if (!document.body || document.querySelector('.az-calm-btn')) return;
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'az-calm-btn';
      function label() { b.textContent = calm ? 'Anti Seizure Mode' : 'I am having a seizure'; }
      label();
      b.setAttribute('aria-pressed', String(calm));
      // Idle timer: the button only screams while you're near it. .az-calm-idle (see CSS) fades
      // it to a near-invisible still ghost 2s after the pointer leaves, and it starts idle so an
      // untouched page never has it strobing in the corner.
      var idleTimer;
      function idle(on) {
        clearTimeout(idleTimer);
        if (on) idleTimer = setTimeout(function () { b.classList.add('az-calm-idle'); }, 2000);
        else b.classList.remove('az-calm-idle');
      }
      b.addEventListener('pointerenter', function () { idle(false); });
      b.addEventListener('pointerleave', function () { idle(true); });
      b.addEventListener('focus', function () { idle(false); });
      b.addEventListener('blur', function () { idle(true); });
      b.classList.add('az-calm-idle');
      b.addEventListener('click', function () {
        calm = !calm;
        document.documentElement.classList.toggle('az-calm', calm);
        label();
        b.setAttribute('aria-pressed', String(calm));
        try { localStorage.setItem(CALM_KEY, calm ? '1' : '0'); } catch (e) {}
        idle(false);   // touch has no hover: a tap must reveal it, then re-idle on leave
      });
      document.body.appendChild(b);
    }
    if (document.body) addCalmButton();
    else document.addEventListener('DOMContentLoaded', addCalmButton);
  })();

  // --- art change watcher ---
  // AzuraCast's own SSE (now that the reverse proxy streams it unbuffered - see proxy.nix
  // /live/ location) drives title/artist/art reactively; no app-level polling needed for those.
  //
  // There is deliberately NO cache-busting here. AzuraCast's art URLs are already unique and
  // immutable per track (/api/station/radio_marcel/art/<media-id>-<mtime>.jpg) and are served
  // with "cache-control: public, max-age=31536000". An earlier version appended a rising _az=N
  // param on every now-playing event, which defeated that cache completely: the cover is ~390KB,
  // SSE ticks about every 13s, so each listener re-downloaded 390KB every 13s (more bandwidth
  // than the 128kbps audio stream itself), and a track change fetched the new cover TWICE under
  // two different URLs (bare for the push clone, ?_az=N for the real img). While each of those
  // fetches was in flight the <img> had no frame to paint - which is exactly the "art takes ages
  // to change" / "no animation" symptom. Unique URL in, browser cache does the rest.
  (function () {
    function attachImgWatch() {
      var img = document.querySelector('.radio-player-widget .now-playing-art img');
      if (!img || img._azCacheWatch) return !!img;
      img._azCacheWatch = true;
      // AzuraCast's AlbumArt.vue renders loading="lazy". On a track change that lets the browser
      // defer the new cover's fetch to a later rendering opportunity (indefinitely in a
      // background tab), so the art lagged the title by seconds for no reason. This image is
      // always in view and is the point of the page - fetch it eagerly.
      img.loading = 'eager';
      img.setAttribute('fetchpriority', 'high');
      new MutationObserver(function (muts) {
        muts.forEach(function (mut) {
          if (mut.attributeName !== 'src') return;
          var newSrc = img.getAttribute('src') || '';
          DBG('img src mutation', 'old=' + mut.oldValue, 'new=' + newSrc);
          if (mut.oldValue && newSrc && mut.oldValue !== newSrc) playArtPush(mut.oldValue, newSrc);
        });
      }).observe(img, { attributes: true, attributeFilter: ['src'], attributeOldValue: true });
      return true;
    }
    // Persistent, not "poll until found then stop": .now-playing-art is behind a v-if on
    // song.art in Player.vue, so a track with no cover art destroys the whole container and the
    // next track with art builds a NEW <img>. The old version stopped polling after 15s, so
    // after one art-less track the observer was orphaned on a detached node and the push
    // transition never fired again for the rest of the session. attachImgWatch is a guarded
    // no-op per node (img._azCacheWatch), so re-checking costs a querySelector.
    setInterval(attachImgWatch, 300);
  })();

  // Track-change "push": two throwaway <img> clones (old cover + new cover) layered above the
  // real <img> - which already has the new src by the time this runs, so it needs no changes
  // itself, just to be covered while the clones slide. See .az-art-slide/-incoming/-outgoing
  // in CSS for the movement itself.
  var PUSH_MS = 1400;
  var PUSH_WAIT_MS = 600;
  // Don't animate a cover that has no pixels yet. The clone used to get its src at the same
  // moment it started sliding, so on any slow fetch the "push" played out as an empty rectangle
  // and the real cover just popped in afterwards - read as "the animation didn't happen".
  // preloadArt() below normally has the next cover cached already, so decode resolves in the
  // same tick and there's no added latency; PUSH_WAIT_MS caps the wait for a cold fetch so a
  // slow/failed load degrades to the old behavior instead of dropping the transition entirely.
  function playArtPush(oldSrc, newSrc) {
    var pre = new Image();
    pre.src = newSrc;
    if (pre.complete) { startArtPush(oldSrc, newSrc); return; }
    var fired = false;
    var go = function () {
      if (fired) return;
      fired = true;
      DBG('playArtPush: new cover ready=' + pre.complete);
      startArtPush(oldSrc, newSrc);
    };
    pre.onload = pre.onerror = go;
    setTimeout(go, PUSH_WAIT_MS);
  }
  function startArtPush(oldSrc, newSrc) {
    var art = document.querySelector('.radio-player-widget .now-playing-art');
    var img = art && art.querySelector('img');
    if (!art || !img) return;

    DBG('playArtPush', art._azPushTimer ? 'RESTART (previous push still in flight)' : 'start');
    if (art._azPushTimer) clearTimeout(art._azPushTimer);   // a transition was already mid-flight -> its cleanup must not fire late and cut this one short
    var leftover = art.querySelectorAll('.az-art-slide');
    for (var i = 0; i < leftover.length; i++) leftover[i].remove();

    var outgoing = document.createElement('img');
    outgoing.src = oldSrc;
    outgoing.className = 'az-art-slide az-art-outgoing';
    art.appendChild(outgoing);

    var incoming = document.createElement('img');
    incoming.src = newSrc;
    incoming.className = 'az-art-slide az-art-incoming';
    art.appendChild(incoming);

    art._azPushTimer = setTimeout(function () {
      art._azPushTimer = null;
      outgoing.remove();
      incoming.remove();
    }, PUSH_MS);
  }

  // --- artist name -> bandcamp album link ---
  // bandcampsync publishes an exact "artist|album" -> bandcamp url map (the real url from
  // the bandcamp API, not a guess) at bcsync.marcel.cool/links.json. The nowplaying API
  // gives us song.album (not present in the DOM); the artist TEXT stays fully Vue-owned,
  // we just wrap it in a link once both the map and a matching Vue-rendered artist agree.
  var bcLinks = null, lastSong = null;
  fetch('https://bcsync.marcel.cool/links.json', { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : {}; })
    .then(function (j) { bcLinks = j || {}; applyArtistLink(); })
    .catch(function () { bcLinks = {}; });

  // Matches bandcampsync_report.py's norm(): folder names are filesystem-sanitized
  // (apostrophes stripped, etc.) and differ from the raw tags AzuraCast reports.
  function bcNorm(s) {
    return (s || '').toLowerCase().replace(/['’]/g, '').replace(/[^a-z0-9]+/g, ' ').trim();
  }
  function applyArtistLink() {
    if (bcLinks === null || !lastSong) return;
    var el = document.querySelector('.radio-player-widget .now-playing-artist');
    var artist = (lastSong.artist || '').trim();
    if (!el || !artist || (el.textContent || '').trim() !== artist) return;   // Vue hasn't rendered this artist yet
    var url = bcLinks[bcNorm(artist) + '|' + bcNorm(lastSong.album)] || '';
    var a = el.querySelector('a.az-bc-link');
    if (a ? a.href === url : !url) return;   // already correct (incl. no link available)
    el.textContent = artist;
    if (!url) return;
    a = document.createElement('a');
    a.className = 'az-bc-link';
    a.href = url;
    a.target = '_blank';
    a.rel = 'noopener';
    a.textContent = artist;
    el.textContent = '';
    el.appendChild(a);
  }

  (function () {
    // Hardcoded, not derived from location.pathname: the homepage (radio.marcel.cool/) serves
    // this station's public page directly at "/" (no redirect), so a /public/<shortcode> match
    // against location.pathname never fires there. Single-station page -> just hardcode it,
    // matching homepage_redirect_url in azuracast.nix.
    var apiUrl = location.origin + '/api/nowplaying/radio_marcel';
    // Warm the browser cache with the NEXT track's cover while the current one is still playing.
    // The response already carries playing_next.song.art, and art URLs are immutable per track
    // (see the art change watcher), so by the time Vue swaps the src the bytes are local: the
    // push transition starts instantly with real pixels instead of racing a ~390KB download.
    var preloaded = {};
    function preloadArt(url) {
      if (!url || preloaded[url]) return;
      preloaded[url] = new Image();
      preloaded[url].src = url;
    }
    function fetchSong() {
      fetch(apiUrl, { cache: 'no-store' })
        .then(function (r) { return r.ok ? r.json() : null; })
        .then(function (data) {
          if (data && data.playing_next && data.playing_next.song) preloadArt(data.playing_next.song.art);
          var song = data && data.now_playing && data.now_playing.song;
          if (!song) return;
          lastSong = song;
          applyArtistLink();
        })
        .catch(function () {});
    }
    document.addEventListener('now-playing', function () { setTimeout(fetchSong, 0); });
    fetchSong();
  })();
})();
