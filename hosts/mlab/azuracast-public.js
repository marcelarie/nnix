(function () {
  // Muted-autoplay-where-allowed + unmute on first user gesture.
  // Chrome/Firefox allow muted autoplay without a gesture; Brave (and Chromium with autoplay
  // disabled) block even muted play() until the user interacts. We probe below and only attempt
  // load-time muted play where it will succeed; where it's blocked we stay paused (flashing PLAY
  // overlay) and start on the first gesture, which is always allowed. The store boots muted
  // (localStorage "player_muted" = "true") so a successful muted autoplay is silent until the
  // user clicks to unmute, keeping store + UI in sync.
  try { localStorage.setItem('player_muted', 'true'); } catch (e) {}

  function getPlayButton() { return document.querySelector('.radio-control-play-button'); }
  function getMuteButton() { return document.querySelector('.radio-control-volume .btn'); }
  function getAudioEl() { return document.querySelector('audio'); }

  // --- debug (gated on ?azdebug); remove once autoplay is confirmed ---
  var DBG = (function () {
    if (location.search.indexOf('azdebug') === -1) return function () {};
    var log = (window.__azLog = []);
    function emit() {
      var args = [].slice.call(arguments);
      log.push(((performance.now() / 100) | 0) + ' ' + args.join(' '));
      try { console.log.apply(console, args); } catch (e) {}
    }
    emit('azdebug ON');

    function attachAudioLog() {
      var audio = getAudioEl();
      if (!audio || audio._azDbg) return;
      audio._azDbg = 1;
      ['play', 'playing', 'pause', 'ended', 'error', 'suspend', 'stalled', 'emptied', 'loadstart', 'canplay', 'waiting', 'abort', 'ratechange'].forEach(function (ev) {
        audio.addEventListener(ev, function () {
          emit('audio.' + ev, 'paused=' + audio.paused, 'muted=' + audio.muted, 'readyState=' + audio.readyState, audio.error ? ('err=' + audio.error.code) : '');
        }, true);
      });
    }
    setInterval(attachAudioLog, 200);

    function watchBtn(sel, label) {
      var btn = document.querySelector(sel);
      if (!btn || btn._azDbg) return;
      btn._azDbg = 1;
      new MutationObserver(function () {
        emit(label, 'icon-> isPlaying=' + isPlaying() + ' isMuted=' + isMuted());
      }).observe(btn, { childList: true, subtree: true, attributes: true });
    }
    setInterval(function () {
      watchBtn('.radio-control-play-button', 'PLAYBTN');
      watchBtn('.radio-control-volume .btn', 'MUTEBTN');
    }, 200);

    // attachAudioLog only ever instruments the FIRST <audio> found. If AzuraCast ever leaves a
    // stale element behind while playing through a new one, its events are invisible above, so
    // report the element count whenever it changes.
    var lastCount = -1;
    setInterval(function () {
      var els = document.querySelectorAll('audio');
      if (els.length === lastCount) return;
      lastCount = els.length;
      var states = [];
      for (var i = 0; i < els.length; i++) states.push(i + ':paused=' + els[i].paused + ',t=' + els[i].currentTime.toFixed(1) + ',rs=' + els[i].readyState);
      emit('AUDIO ELEMENTS n=' + els.length, states.join(' | '));
    }, 250);

    return emit;
  })();

  // --- stream auto-recovery ---
  // A network interruption can kill the stream without the browser or AzuraCast ever reconnecting
  // on their own. Recovery is what already works manually: toggle the real play button.
  //
  // Liveness is judged by currentTime ADVANCING, not by media events. An earlier version listened
  // for the 'playing' event, bound via a poll racing AzuraCast's own element-swap-on-toggle -
  // that race was lost constantly and produced a self-sustaining reconnect loop that strangled a
  // healthy stream every ~8s (see report.md for the full incident). A playing stream always
  // advances currentTime, so polling progress has no event to miss and cannot misfire on a
  // healthy stream.
  var recoveryEl = null, recoveryLastTime = -1, recoverySeenProgress = false, recoveryStalledSince = 0;
  var STALL_MS = 10000; // zero progress this long while unpaused = a real outage, not a blip

  function resetRecoveryProgress(audio) {
    recoveryEl = audio;
    recoveryLastTime = audio ? audio.currentTime : -1;
    recoverySeenProgress = false;
    recoveryStalledSince = 0;
  }

  setInterval(function () {
    var audio = getAudioEl();
    // paused is the user's choice, not ours to "fix"; no element yet means nothing to watch
    if (!audio || audio.paused) { resetRecoveryProgress(audio); return; }
    // element swapped -> rebase, don't compare currentTime across two different elements
    // (the new one restarts near 0, which would read as a huge backwards jump)
    if (audio !== recoveryEl) { resetRecoveryProgress(audio); return; }
    // abs(), not >: a backward jump (the browser reconnecting internally on the same element,
    // restarting currentTime near 0) also proves the element is alive. A forward-only test would
    // get stuck at the old high-water mark and read every later second as "no progress".
    if (Math.abs(audio.currentTime - recoveryLastTime) > 0.1) {
      recoveryLastTime = audio.currentTime;
      recoverySeenProgress = true;
      recoveryStalledSince = 0;
      return;
    }
    // Only ever act on "was playing, then stopped" - a stream that never started belongs to the
    // autoplay / ensurePlaying() path below, and clicking at it from here would fight it.
    if (!recoverySeenProgress) return;
    if (!recoveryStalledSince) recoveryStalledSince = performance.now();
    if (performance.now() - recoveryStalledSince < STALL_MS) return;
    recoveryStalledSince = 0; // give this retry a full fresh window
    DBG('recovery: soft retry (no progress for ' + STALL_MS + 'ms)');
    var playBtn = getPlayButton();
    if (playBtn) {
      playBtn.click();
      setTimeout(function () { var btn = getPlayButton(); if (btn) btn.click(); }, 300);
    }
  }, 1000);

  // Brave (and Chromium with autoplay disabled) block even muted play() until the user interacts.
  // AzuraCast flips isPlaying=true *before* play() resolves, so a blocked muted-autoplay desyncs
  // the store (icon says "pause", audio is silent) and the gesture handler below would trust that
  // icon and never restart -> dead silence. So: probe muted autoplay first (below), and only
  // attempt load-time play where it will succeed. Where it's blocked we stay paused (flashing PLAY
  // overlay) and start on the first user gesture, which is always allowed. Any NotAllowedError
  // that slips through is swallowed so the console stays clean; the gesture handler recovers
  // playback regardless.
  window.addEventListener('unhandledrejection', function (e) {
    if (e && e.reason && e.reason.name === 'NotAllowedError') e.preventDefault();
  });

  var started = false, autoplayPollId, autoplayOk = null; // null = probe pending; true/false once resolved

  (function probeAutoplay() {
    try {
      var probe = new Audio();
      probe.muted = true;
      probe.src = 'data:audio/wav;base64,UklGRiYAAABXQVZFZm10IBAAAAABAAEAIlYAAESsAAAQABAAZGF0YQIAAAAAAA==';
      var playPromise = probe.play();
      if (playPromise && playPromise.then) {
        playPromise.then(
          function () { autoplayOk = true; },
          function (err) {
            if (err && err.name === 'NotAllowedError') { autoplayOk = false; clearInterval(autoplayPollId); }
            else autoplayOk = true; // any other failure (e.g. bad src) isn't an autoplay block
          }
        );
      } else {
        autoplayOk = true;
      }
    } catch (e) { autoplayOk = false; clearInterval(autoplayPollId); }
  })();

  function start() {
    DBG('start', 'started=' + started, 'autoplayOk=' + autoplayOk);
    if (started) return;
    if (autoplayOk !== true) return;
    var playBtn = getPlayButton();
    if (!playBtn) return;
    started = true;
    clearInterval(autoplayPollId);
    DBG('start -> b.click()');
    playBtn.click();
  }
  // AzuraCast fires 'now-playing' on the document when stream metadata arrives (same hook native autoplay uses).
  document.addEventListener('now-playing', function () { setTimeout(start, 0); }, { once: true });
  autoplayPollId = setInterval(function () { if (getPlayButton()) setTimeout(start, 0); }, 300);
  setTimeout(function () { clearInterval(autoplayPollId); }, 10000);

  function cleanupGestureListeners() {
    ['pointerdown', 'keydown', 'touchstart', 'wheel'].forEach(function (ev) {
      window.removeEventListener(ev, unmute, true);
    });
  }

  // Trust the <audio> element's real state, NOT the play-button icon. On mobile, the autoplay
  // probe may pass so start() auto-clicks the play button with NO user gesture; the real stream
  // play() (deferred to a nextTick, no activation) is then blocked, but AzuraCast has already
  // flipped isPlaying=true -> store desyncs (icon says "playing", audio is paused). So: if the
  // audio is actually paused, call play() directly inside this gesture (always allowed on
  // mobile), resuming the already-loaded stream; only if no stream is loaded yet do we click the
  // play button to make AzuraCast load+play it.
  function ensurePlaying() {
    var audio = getAudioEl();
    if (audio && !audio.paused) { DBG('ensurePlaying: already playing -> unmute'); unmuteAfterPlay(); return; }
    if (audio && audio.src) { // paused but stream loaded (autoplay blocked / desynced)
      audio.muted = isMuted();
      DBG('ensurePlaying: paused+src -> a.play() in gesture (muted=' + audio.muted + ')');
      var playPromise = audio.play();
      if (playPromise && playPromise.catch) playPromise.catch(function () {});
      unmuteAfterPlay();
      return;
    }
    DBG('ensurePlaying: no src -> b.click() start');
    started = true;
    clearInterval(autoplayPollId);
    var playBtn = getPlayButton();
    if (playBtn) playBtn.click(); // no stream loaded -> AzuraCast loads+plays in nextTick
    unmuteAfterPlay();
  }

  function unmute(e) {
    initEq(); // first user gesture -> boot the Web Audio analyser (needs a gesture)
    DBG('unmute', e.type, 'isPlaying=' + isPlaying(), 'isMuted=' + isMuted(), 'audioPaused=' + (getAudioEl() ? getAudioEl().paused : 'no-audio'), 'target=' + (e.target && (e.target.className || e.target.tagName)));
    // pointer/touch on the album art precede a click handled by the art click handler (start+unmute); defer those.
    if ((e.type === 'pointerdown' || e.type === 'touchstart') &&
        e && e.target && e.target.closest && e.target.closest('.now-playing-art')) { DBG('unmute: defer to art handler'); return; }
    // Anti-seizure button: a UI toggle, not a "start the radio" gesture. Return BEFORE cleanup()
    // so the listeners stay bound and the next real gesture still starts playback.
    if (e && e.target && e.target.closest && e.target.closest('.az-calm-btn')) { DBG('unmute: on calm btn, skip'); return; }
    cleanupGestureListeners();
    if (e && e.target && e.target.closest) {
      // let the volume/mute control and the play button run their OWN real click (avoids a
      // double-toggle: our synthetic click + the real click = start then stop)
      if (e.target.closest('.radio-control-volume')) { DBG('unmute: on volume ctrl, skip'); return; }
      if (e.target.closest('.radio-control-play-button')) { DBG('unmute: on play btn, just unmute-after'); unmuteAfterPlay(); return; }
    }
    ensurePlaying();
  }

  // Toggle play/pause from any user gesture (album-art click or Space key). Pauses only when
  // actually playing AND unmuted; otherwise starts/unmutes - trusting the real <audio> state
  // (not the play-button icon), same logic as the art click.
  function togglePlayPause() {
    initEq(); // spacebar gesture -> boot analyser (idempotent)
    cleanupGestureListeners();
    var audio = getAudioEl(), playBtn = getPlayButton();
    if (audio && !audio.paused && !isMuted()) { if (playBtn) playBtn.click(); } // playing+unmuted -> pause
    else { ensurePlaying(); } // paused or muted -> start/unmute
  }

  // Zoom lightbox trigger, shared between the ZOOM corner click and the 'z' keydown below.
  // triggeringZoom guards against double-handling: link.click() bubbles a click back up through
  // .now-playing-art, which the art click handler (see relocate()) would otherwise also catch.
  var triggeringZoom = false;
  function triggerZoom() {
    var link = document.querySelector('.radio-player-widget .now-playing-art a.album-art');
    if (!link) return;
    triggeringZoom = true;
    link.click();
    triggeringZoom = false;
  }

  // Spacebar toggles play/pause; ArrowUp/ArrowDown raise/lower volume; z toggles the album art
  // zoom lightbox; m toggles mute. Registered BEFORE the window 'unmute' keydown (capture) so
  // stopImmediatePropagation stops it also firing ensurePlaying (which would re-start right
  // after a pause). preventDefault stops the page scrolling on Space/arrow keys. Skipped while
  // focus is in an input/textarea/contenteditable so we don't hijack typing, and a focused
  // volume slider keeps its native arrow handling instead of double-applying.
  window.addEventListener('keydown', function (e) {
    var isSpace = (e.key === ' ' || e.code === 'Space');
    var isVol = (e.key === 'ArrowUp' || e.key === 'ArrowDown');
    var isZoom = (e.key === 'z' || e.key === 'Z');
    var isMute = (e.key === 'm' || e.key === 'M');
    if (!isSpace && !isVol && !isZoom && !isMute) return;
    var target = e.target;
    // Only defer to a REAL text-entry control. Matching a focused <input type=range> here would
    // silently swallow Space/z; it keeps its own native arrow-key handling below regardless.
    if (target && (target.isContentEditable || /^(TEXTAREA|SELECT)$/.test(target.tagName) || (target.tagName === 'INPUT' && target.type !== 'range'))) return;
    if (isVol && target && target.tagName === 'INPUT' && target.type === 'range') return;
    e.preventDefault();
    e.stopImmediatePropagation(); // block the 'unmute' keydown (same target+phase, registered later)
    if (isSpace) {
      if (e.repeat) return; // held Space: still block scroll, but don't toggle again
      togglePlayPause();
    } else if (isZoom) {
      if (e.repeat) return;
      triggerZoom();
    } else if (isMute) {
      if (e.repeat) return;
      var muteBtn = getMuteButton();
      if (muteBtn) muteBtn.click(); // same real click the mute button itself would get
    } else {
      bumpVolume(e.key === 'ArrowUp' ? 5 : -5); // repeats allowed: hold to ramp volume
    }
  }, true);
  ['pointerdown', 'keydown', 'touchstart', 'wheel'].forEach(function (ev) {
    window.addEventListener(ev, unmute, { capture: true, passive: true });
  });

  // Read play state from the real button's SVG icon (the store's isPlaying, locale-independent):
  // stop-circle icon (path has "H8V8") = playing; play-circle icon (triangle) = paused.
  function isPlaying() {
    var playBtn = getPlayButton();
    if (!playBtn) return false;
    var path = playBtn.querySelector('path');
    return !!(path && (path.getAttribute('d') || '').indexOf('H8V8') !== -1);
  }
  // Read mute state from the volume button's SVG icon (locale-independent):
  // volume-off icon (path has "4.27 3L3 4.27") = muted; volume-down/up = unmuted.
  function isMuted() {
    var muteBtn = getMuteButton();
    if (!muteBtn) return false;
    var path = muteBtn.querySelector('path');
    return !!(path && (path.getAttribute('d') || '').indexOf('4.27 3L3 4.27') !== -1);
  }

  // Arrow keys adjust volume by setting the range input's value and dispatching an 'input' event,
  // which Vue's v-model picks up, updates the store, and persists to localStorage. If muted,
  // unmute on up so the change is audible; down on a muted stream does nothing (already silent).
  var VOL_STEP = 5;
  function bumpVolume(delta) {
    var input = document.querySelector('.radio-control-volume .form-range');
    if (!input) return; // iOS: volume controls disabled (audio.volume not settable)
    var raw = Number(input.value);
    var cur = isNaN(raw) ? 50 : raw; // NOT `|| 50` -> that treats a real 0 as falsy and jumps to 50
    var next = Math.max(0, Math.min(100, cur + delta));
    if (next === cur) return;
    input.value = next;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    if (delta > 0 && next > 0 && isMuted()) {
      var muteBtn = getMuteButton();
      if (muteBtn) muteBtn.click();
    }
  }

  // Drives the mushroom<->mouth volume-bar theme (see CSS): --vol (0-1) lets the track fill and
  // the mouth glow react to the same number. Delegated on document (bubbles) so it works
  // regardless of when Vue mounts the input; bumpVolume's synthetic 'input' event triggers it
  // too. Rising edge into max spawns the "1UP" (.az-1up in CSS) and the chomp; falling edge
  // resets the flag so it can fire again next time volume is pushed back to max.
  var AZ_BITE_MS = 500;    // mouth-bite animation length
  var AZ_HIDDEN_MS = 3000; // how long the mushroom stays eaten once the bite ends
  function syncVolVar(input) {
    var volCtrl = document.querySelector('.radio-control-volume');
    if (!volCtrl) return;
    var frac = (Number(input.value) || 0) / 100;
    volCtrl.style.setProperty('--vol', frac);
    if (frac >= 1) {
      volCtrl.classList.add('az-maxed'); // mouth stays gone while parked at max (see CSS)
      if (!input._azMaxed) { input._azMaxed = true; spawn1Up(volCtrl); chompMushroom(volCtrl); }
    } else {
      input._azMaxed = false;
      volCtrl.classList.remove('az-chomp', 'az-eaten', 'az-maxed'); // dragged back down -> thumb must be grabbable again
    }
  }
  // Mouth bites, then the mushroom stays hidden for AZ_HIDDEN_MS after the bite ends, then
  // comes back. --az-bite-ms feeds the azchomp animation-duration in CSS so the two never
  // drift apart. Every timer only REMOVES classes, so overlapping chomps/drags can't leave
  // the thumb stuck hidden.
  function chompMushroom(volCtrl) {
    volCtrl.style.setProperty('--az-bite-ms', AZ_BITE_MS + 'ms');
    volCtrl.classList.add('az-chomp', 'az-eaten');
    setTimeout(function () { volCtrl.classList.remove('az-chomp'); }, AZ_BITE_MS);
    setTimeout(function () { volCtrl.classList.remove('az-eaten'); }, AZ_BITE_MS + AZ_HIDDEN_MS);
  }
  function spawn1Up(volCtrl) {
    var el = document.createElement('span');
    el.className = 'az-1up';
    el.textContent = '1UP';
    el.addEventListener('animationend', function () { el.remove(); });
    volCtrl.appendChild(el);
  }
  document.addEventListener('input', function (e) {
    if (e.target.matches && e.target.matches('.radio-control-volume .form-range')) syncVolVar(e.target);
  }, true);

  // Unmute WITHOUT racing play(). AzuraCast's play() runs in a Vue nextTick and reads isMuted at
  // that moment: toggling the store before that nextTick makes Vue flush the isMuted watcher
  // first, so play() runs UNMUTED and gets blocked on mobile (a fresh gesture is needed, and the
  // microtask loses it). So the store must stay MUTED until play() lands, then we unmute on the
  // 'play' event (unmuting an already-playing element needs no gesture).
  //
  // On first interaction there's no <audio> in the DOM yet - AzuraCast creates it in that same
  // nextTick. We must NOT unmute now (that flips the store before the audio exists, so
  // AzuraCast's play() runs unmuted and gets blocked). Instead wait for the <audio> to be
  // inserted (a MutationObserver microtask fires before the 'play' event task), then attach the
  // unmute listener so the store flips only after muted play() succeeds.
  function doUnmute(audio) {
    if (!audio.paused) { // already playing (muted) -> unmute now, no new play()
      DBG('doUnmute: playing -> unmute now');
      if (isMuted()) { var muteBtn = getMuteButton(); if (muteBtn) muteBtn.click(); }
      return;
    }
    var onPlay = function () { // muted play() will land -> unmute the store then
      audio.removeEventListener('play', onPlay);
      DBG('doUnmute: play event -> unmute');
      if (isMuted()) { var muteBtn = getMuteButton(); if (muteBtn) muteBtn.click(); }
    };
    audio.addEventListener('play', onPlay, { once: true });
    setTimeout(function () { // safety: if 'play' never fires (load stall), unmute after 2s
      audio.removeEventListener('play', onPlay);
      DBG('doUnmute: 2s safety', 'isMuted=' + isMuted());
      if (isMuted()) { var muteBtn = getMuteButton(); if (muteBtn) muteBtn.click(); }
    }, 2000);
  }
  function unmuteAfterPlay() {
    var audio = getAudioEl();
    if (audio) { doUnmute(audio); return; }
    DBG('unmuteAfterPlay: no <audio> yet -> wait for insertion (keep store muted)');
    var obs = new MutationObserver(function () {
      var newAudio = getAudioEl();
      if (newAudio) { obs.disconnect(); DBG('audio appeared -> doUnmute', 'paused=' + newAudio.paused); doUnmute(newAudio); }
    });
    obs.observe(document.documentElement, { childList: true, subtree: true });
    setTimeout(function () { obs.disconnect(); }, 3000);
  }

  // Album art overlay: flashing PLAY/PAUSE text (center) + ZOOM corner.
  // Clicking the art toggles play/pause (the <a> lightbox is blocked); the zoom corner opens the lightbox.
  // artObserver/artSyncTimer track the PREVIOUS art node's watchers so relocate() can tear them
  // down before attaching new ones. Without this, every art-less track (Player.vue destroys and
  // rebuilds .now-playing-art on a v-if) left the old observer+interval running forever on a
  // detached node - a MutationObserver keeps its target alive even with no JS references to it,
  // so this was an unbounded leak over a long listening session.
  var artObserver = null, artSyncTimer = null;
  function relocate() {
    var art = document.querySelector('.radio-player-widget .now-playing-art');
    var playBtn = getPlayButton();
    var volInput = document.querySelector('.radio-control-volume .form-range');
    if (volInput && !volInput._azVolSynced) { volInput._azVolSynced = true; syncVolVar(volInput); }
    if (!art || !playBtn || art._azInit) return !!(art && playBtn);
    art._azInit = true;

    if (artObserver) { artObserver.disconnect(); artObserver = null; }
    if (artSyncTimer) { clearInterval(artSyncTimer); artSyncTimer = null; }

    var overlay = document.createElement('div');
    overlay.className = 'az-overlay-play';
    art.appendChild(overlay);

    var zoomCorner = document.createElement('div');
    zoomCorner.className = 'az-zoom';
    zoomCorner.textContent = 'ZOOM';
    art.appendChild(zoomCorner);

    function sync() {
      var playing = isPlaying();
      var label = playing ? 'PAUSE' : 'PLAY';
      if (overlay.textContent !== label) overlay.textContent = label;
      art.classList.toggle('az-paused', !playing);
    }
    // MutationObserver: the button's icon swaps when isPlaying changes -> update immediately.
    artObserver = new MutationObserver(sync);
    artObserver.observe(playBtn, { childList: true, subtree: true, attributes: true });
    artSyncTimer = setInterval(sync, 500); // safety-net poll
    sync();

    art.addEventListener('click', function (e) {
      if (triggeringZoom) return; // synthetic click from zoom corner/'z' key -> let <a> lightbox fire
      if (e.target.closest('.az-zoom')) { // zoom corner -> open lightbox via the <a>
        e.stopPropagation(); e.preventDefault();
        triggerZoom();
        return;
      }
      e.stopPropagation(); e.preventDefault(); // block <a> lightbox; image click toggles play
      togglePlayPause();
      setTimeout(sync, 0); // reflect the new state immediately
    }, true);
    return true;
  }
  // Persistent: .now-playing-art is behind a v-if on song.art, so an art-less track destroys the
  // container and the overlay/click handlers along with it. Guarded per node by art._azInit.
  setInterval(relocate, 200);

  // --- real audio-reactive equalizer, multiple LINES (placeholder; custom visualizer later) ---
  // One Web Audio AnalyserNode taps the <audio>; several SVG path ribbons trace different
  // frequency bands, each its own color + granularity + smoothing. DOM is built eagerly (polled)
  // so the 44px slot is reserved from page load -> no layout shift on fade. AudioContext is lazy
  // (needs a gesture) so muted autoplay isn't blocked. Same-origin guard: a cross-origin stream
  // bound to MediaElementSource taints it -> silence, so we skip. Per-track smoothing is done in
  // JS (analyser smoothing is global) so bass reads smooth, mids spiky, highs very spiky. eqFrame
  // re-binds each new <audio> (AzuraCast swaps it across pause/play) and resumes a
  // Chrome-auto-suspended context so data doesn't go flat.
  var eqCtx, eqAn, eqSrc, eqData, eqRAF, eqInit, eqBoundEl, eqBox, eqLastSound = 0;
  // band = fraction of frequency bins [lo,hi]; pts = granularity; smooth = per-track smoothing
  // (0=raw/spiky, 1=frozen); amp = vertical amplitude (fraction of half-height).
  var EQ_TRACKS = [
    { color: '#00e5ff', band: [0.00, 0.15], pts: 24, smooth: 0.6,  amp: 0.7 }, // bass -> smooth,   cyan
    { color: '#ff3df0', band: [0.15, 0.50], pts: 56, smooth: 0.12, amp: 0.9 }, // mid  -> grainier, magenta
    { color: '#ffe600', band: [0.50, 1.00], pts: 90, smooth: 0.03, amp: 1.0 }  // high -> very grainy, yellow
  ];
  function buildEqDom() {
    if (eqBox) return;
    var host = document.querySelector('.radio-player-widget');
    if (!host) return;
    eqBox = document.createElement('div');
    eqBox.className = 'az-eq';
    var NS = 'http://www.w3.org/2000/svg';
    var svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('viewBox', '0 0 100 40');
    svg.setAttribute('preserveAspectRatio', 'none');
    EQ_TRACKS.forEach(function (track, i) {
      track.el = document.createElementNS(NS, 'path');
      track.el.setAttribute('fill', track.color);
      track.el.style.opacity = 0.9 - i * 0.12; // back lines slightly fainter so the front reads
      svg.appendChild(track.el);
      track.sm = new Float32Array(track.pts); // per-track smoothed buffer
    });
    eqBox.appendChild(svg);
    var main = host.querySelector('.now-playing-main'); // same column as title/artist, where the time-display bar used to sit
    if (main) {
      main.appendChild(eqBox);
    } else {
      var ctrl = host.querySelector('.radio-controls');
      if (ctrl) host.insertBefore(eqBox, ctrl); else host.appendChild(eqBox);
    }
  }
  var eqDomPollId = setInterval(function () { if (document.querySelector('.radio-player-widget')) { buildEqDom(); clearInterval(eqDomPollId); } }, 200);
  setTimeout(function () { clearInterval(eqDomPollId); }, 10000);

  function initEq() {
    if (eqInit) return;
    eqInit = true;
    buildEqDom(); // safety: ensure DOM exists even if the poll hasn't fired yet
    try {
      eqCtx = new (window.AudioContext || window.webkitAudioContext)();
      eqAn = eqCtx.createAnalyser();
      eqAn.fftSize = 256; // 128 bins -> enough to slice into 3 bands
      eqAn.smoothingTimeConstant = 0; // raw -> per-track smoothing in JS (each line its own feel)
      eqAn.connect(eqCtx.destination);
      eqData = new Uint8Array(eqAn.frequencyBinCount);
    } catch (e) { eqCtx = null; return; }
    if (!eqRAF) eqFrame();
  }
  function attachEqSource(audio) {
    if (!eqCtx || !audio || audio === eqBoundEl) return;
    if (audio._azEqSrc) { eqBoundEl = audio; return; } // already bound -> just record
    audio._azEqSrc = 1;
    try {
      if (new URL(audio.src || '', location.href).origin !== location.origin) { eqBoundEl = audio; return; } // cross-origin -> skip (would silence)
      eqSrc = eqCtx.createMediaElementSource(audio);
      eqSrc.connect(eqAn);
      audio.addEventListener('play', function () { if (eqCtx && eqCtx.state === 'suspended') eqCtx.resume(); });
    } catch (e) { /* already bound to another context / unavailable -> no viz */ }
    eqBoundEl = audio;
  }
  function eqFrame() {
    eqRAF = requestAnimationFrame(eqFrame);
    var audio = getAudioEl();
    if (audio && audio !== eqBoundEl) attachEqSource(audio); // <audio> swapped across pause/play -> rebind
    if (eqCtx && eqCtx.state === 'suspended') eqCtx.resume(); // Chrome auto-suspends idle contexts
    if (!eqAn || !audio || audio.paused || isMuted() || !eqBox || !EQ_TRACKS[0].el) {
      if (eqBox) eqBox.style.opacity = 0;
      setBgFx(0, 0, 0, 0); // paused/muted -> background goes still
      return;
    }
    eqAn.getByteFrequencyData(eqData);
    var len = eqData.length, gmax = 0, peaks = [0, 0, 0];
    for (var k = 0; k < EQ_TRACKS.length; k++) {
      var track = EQ_TRACKS[k];
      var b0 = Math.floor(track.band[0] * len);
      var b1 = Math.max(b0 + 1, Math.floor(track.band[1] * len));
      var span = b1 - b0, top = [], bot = [];
      for (var i = 0; i < track.pts; i++) {
        var s0 = b0 + Math.floor(i / track.pts * span);
        var s1 = Math.max(s0 + 1, b0 + Math.floor((i + 1) / track.pts * span));
        var v = 0;
        for (var j = s0; j < s1 && j < b1; j++) if (eqData[j] > v) v = eqData[j]; // max -> spikes (granularity)
        v = Math.min(255, v * 1.3); // gain -> lift detail
        if (v > gmax) gmax = v;
        track.sm[i] = track.sm[i] * track.smooth + v * (1 - track.smooth); // per-track smoothing
        if (track.sm[i] > peaks[k]) peaks[k] = track.sm[i]; // per-band peak this frame -> drives the background fx
        var x = i / (track.pts - 1) * 100;
        var cy = 20 - (track.sm[i] / 255) * (track.amp * 15); // centerline (baseline y=20, rises with level)
        var th = 1.5 + (track.sm[i] / 255) * 5; // thickness ∝ level: loud = fat, quiet = thin
        top.push(x.toFixed(1) + ',' + (cy - th / 2).toFixed(1));
        bot.unshift(x.toFixed(1) + ',' + (cy + th / 2).toFixed(1)); // reverse order -> path closes cleanly R-to-L
      }
      track.el.setAttribute('d', 'M' + top.join(' L') + ' L' + bot.join(' L') + ' Z');
    }
    if (gmax > 8) eqLastSound = performance.now();
    eqBox.style.opacity = (performance.now() - eqLastSound < 250) ? '1' : '0';
    setBgFx(gmax / 255, peaks[0] / 255, peaks[1] / 255, peaks[2] / 255);
  }

  // Background vibrate + glow, driven by the same analyser data as the equalizer: bass -> zoom
  // pulse, mid/high -> a small shake offset, overall loudness -> glow strength. Color follows
  // whichever band is loudest (matches the eq track colors).
  //
  // Drop detection: bgBassAvg is a slow rolling average of the bass band ("what's normal right
  // now"). A frame where bass suddenly jumps well above that average is a hit (kick/drop), not
  // just a loud sustained bassline. Each hit relocates the glow to a random spot and injects
  // bgDropEnergy, which exponentially decays over the next ~0.3-0.5s -> a punch, not a toggle.
  var bgFxRoot = document.documentElement.style;
  var bgBassAvg = 0, bgDropEnergy = 0, bgLastHit = 0;
  // Glow dodges the cursor: bgGlowBaseX/Y is where a bass hit relocated it to; applyGlowPos pushes
  // that point away from the last known mouse position when the cursor gets close, so the light
  // "escapes" instead of sitting under it. Skipped entirely under prefers-reduced-motion (CSS
  // already hides the ::after layer there).
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
      if (document.documentElement.classList.contains('az-calm')) return; // hidden by CSS in calm mode - skip the trig
      bgMouseX = e.clientX; bgMouseY = e.clientY;
      applyGlowPos();
    });
  }
  function setBgFx(punch, bassN, midN, highN) {
    // Anti-seizure mode hides zoom/shake/glow entirely via CSS (html.az-calm) - none of the
    // work below has any visible effect while it's on, so skip it rather than compute for nothing.
    if (document.documentElement.classList.contains('az-calm')) return;
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
    el.classList.remove('az-marquee'); // measure in block state (no ::after)
    var textW = el.scrollWidth, cw = el.clientWidth;
    if (textW > cw + 1) { // overflow -> scroll
      el.style.setProperty('--az-shift', -(textW + GAP) + 'px');
      el.style.setProperty('--az-dur', Math.max(6, Math.min(20, (textW + GAP) / SPEED)) + 's');
      el.classList.add('az-marquee');
    }
  }
  // marqueeObservers tracks the PREVIOUS title/artist node's observer per selector, so a Vue
  // rebuild (title/artist live in one of three keyed v-if branches - see below) can disconnect
  // the stale one instead of leaking it forever on a detached node (same leak class as relocate()'s art watcher).
  var marqueeObservers = {};
  function setupMarquee() {
    ['.now-playing-title', '.now-playing-artist'].forEach(function (sel) {
      var el = document.querySelector('.radio-player-widget ' + sel);
      if (!el || el._azMarquee) return;
      el._azMarquee = true;
      var isArtist = sel === '.now-playing-artist';
      if (isArtist) applyArtistLink();
      updateMarquee(el);
      if (marqueeObservers[sel]) marqueeObservers[sel].disconnect();
      // Vue updates the text node -> re-measure. attributes (class/style) excluded -> no self-loop.
      marqueeObservers[sel] = new MutationObserver(function () { updateMarquee(el); if (isArtist) applyArtistLink(); });
      marqueeObservers[sel].observe(el, { childList: true, subtree: true, characterData: true });
    });
  }
  // Persistent for the same reason as the art watcher: Player.vue renders title/artist in one of
  // three keyed v-if branches, so whenever is_online or song.title changes truthiness Vue throws
  // the h4/h5 away and builds new ones - precisely when the uplink flaps. setupMarquee is a
  // guarded no-op per node (el._azMarquee).
  setInterval(setupMarquee, 300);
  var resizeTimer;
  window.addEventListener('resize', function () { clearTimeout(resizeTimer); resizeTimer = setTimeout(setupMarquee, 150); });

  // Keyboard-shortcut hint: pinned to the bottom-right corner of now-playing-details (see CSS
  // .az-hint), not its own row, so it adds no extra card height. Lives inside now-playing-details
  // (not the outer widget) because that's the box position:relative is actually set on. Desktop
  // only - CSS hides it under 768px (touch devices have no arrow keys).
  function setupHint() {
    var host = document.querySelector('.radio-player-widget .now-playing-details');
    if (!host || host.querySelector('.az-hint')) return !!host;
    var hint = document.createElement('div');
    hint.className = 'az-hint';
    hint.textContent = '↑/↓ volume  ·  space play/pause  ·  m mute  ·  z zoom';
    host.appendChild(hint);
    return true;
  }
  var hintPollId = setInterval(function () { if (setupHint()) clearInterval(hintPollId); }, 300);
  setTimeout(function () { clearInterval(hintPollId); }, 10000);

  // --- anti-seizure toggle ---
  // Everything it disables (background zoom/shake, beat glow, animated text colors) is driven by
  // CSS, so one class on <html> is the whole switch - see html.az-calm in the CSS. The class is
  // applied before the button exists so a reloaded page never flashes the effects first.
  (function () {
    var CALM_KEY = 'az_calm';
    var calm = false;
    try { calm = localStorage.getItem(CALM_KEY) === '1'; } catch (e) {}
    document.documentElement.classList.toggle('az-calm', calm);

    function addCalmButton() {
      if (!document.body || document.querySelector('.az-calm-btn')) return;
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'az-calm-btn';
      function label() { btn.textContent = calm ? 'Anti Seizure Mode' : 'I am having a seizure'; }
      label();
      btn.setAttribute('aria-pressed', String(calm));

      // Idle timer: the button only screams while you're near it. .az-calm-idle (CSS) fades it
      // to a near-invisible still ghost 2s after the pointer leaves - EXCEPT when the music is
      // stopped, then it stays fully visible (see syncPlay below), so a paused page can't hide
      // the one control that kills the strobing.
      var idleTimer, hovering = false;
      function idle(on) {
        clearTimeout(idleTimer);
        if (on) {
          idleTimer = setTimeout(function () {
            if (!isPlaying()) return; // stopped -> never go idle, stay fully visible
            btn.classList.add('az-calm-idle');
          }, 2000);
        } else {
          btn.classList.remove('az-calm-idle');
        }
      }
      btn.addEventListener('pointerenter', function () { hovering = true; idle(false); });
      btn.addEventListener('pointerleave', function () { hovering = false; idle(true); });
      btn.addEventListener('focus', function () { hovering = true; idle(false); });
      btn.addEventListener('blur', function () { hovering = false; idle(true); });
      btn.addEventListener('click', function () {
        calm = !calm;
        document.documentElement.classList.toggle('az-calm', calm);
        label();
        btn.setAttribute('aria-pressed', String(calm));
        try { localStorage.setItem(CALM_KEY, calm ? '1' : '0'); } catch (e) {}
        idle(false); // touch has no hover: a tap must reveal it, then re-idle on leave
      });
      document.body.appendChild(btn);

      // Music stopped -> button stays fully visible (no idle fade); playing -> usual hover/idle.
      // Polled: isPlaying() reads the play-button icon, which fires no event we can hook here.
      var wasStopped = null;
      function syncPlay() {
        var stopped = !isPlaying();
        if (stopped === wasStopped) return;
        wasStopped = stopped;
        if (stopped) btn.classList.remove('az-calm-idle'); // paused -> always show
        else if (!hovering) idle(true); // resumed -> fade after 2s (unless hovering)
      }
      syncPlay();
      setInterval(syncPlay, 300);
    }
    if (document.body) addCalmButton();
    else document.addEventListener('DOMContentLoaded', addCalmButton);
  })();

  // --- art change watcher ---
  // AzuraCast's own SSE drives title/artist/art reactively; no app-level polling needed for those.
  //
  // Deliberately NO cache-busting here. AzuraCast's art URLs are already unique and immutable per
  // track (/api/station/radio_marcel/art/<media-id>-<mtime>.jpg) and served with a one-year
  // cache-control. An earlier version appended a rising ?_az=N param on every now-playing event,
  // which defeated that cache and re-downloaded the ~390KB cover on every SSE tick - see
  // report.md for the full incident. Unique URL in, browser cache does the rest.
  (function () {
    function attachImgWatch() {
      var img = document.querySelector('.radio-player-widget .now-playing-art img');
      if (!img || img._azCacheWatch) return !!img;
      img._azCacheWatch = true;
      // AzuraCast's AlbumArt.vue renders loading="lazy", which lets the browser defer a track
      // change's cover fetch to a later rendering opportunity (indefinitely in a background tab).
      // This image is always in view and is the point of the page - fetch it eagerly.
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
    // Persistent, not "poll until found then stop": .now-playing-art is behind a v-if on song.art,
    // so a track with no cover destroys the container and the next track with art builds a NEW
    // <img>. attachImgWatch is a guarded no-op per node (img._azCacheWatch).
    setInterval(attachImgWatch, 300);
  })();

  // Track-change "push": two throwaway <img> clones (old cover + new cover) layered above the
  // real <img> - which already has the new src by the time this runs - while the clones slide.
  // See .az-art-slide/-incoming/-outgoing in CSS for the movement itself.
  var PUSH_MS = 1400;
  var PUSH_WAIT_MS = 600;
  // Don't animate a cover that has no pixels yet - a slow fetch used to play the "push" over an
  // empty rectangle. preloadArt() below normally has the next cover cached already, so decode
  // resolves in the same tick; PUSH_WAIT_MS caps the wait for a cold fetch so a slow/failed load
  // degrades to the old behavior instead of dropping the transition entirely.
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
    if (art._azPushTimer) clearTimeout(art._azPushTimer); // a transition was already mid-flight -> its cleanup must not fire late and cut this one short
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
  // bandcampsync publishes an exact "artist|album" -> bandcamp url map (the real url from the
  // bandcamp API, not a guess) at bcsync.marcel.cool/links.json. The nowplaying API gives us
  // song.album (not present in the DOM); the artist TEXT stays fully Vue-owned, we just wrap it
  // in a link once both the map and a matching Vue-rendered artist agree.
  var bcLinks = null, lastSong = null;
  fetch('https://bcsync.marcel.cool/links.json', { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : {}; })
    .then(function (j) { bcLinks = j || {}; applyArtistLink(); })
    .catch(function () { bcLinks = {}; });

  // Matches bandcampsync_report.py's norm(): folder names are filesystem-sanitized (apostrophes
  // stripped, etc.) and differ from the raw tags AzuraCast reports.
  function bcNorm(s) {
    return (s || '').toLowerCase().replace(/['’]/g, '').replace(/[^a-z0-9]+/g, ' ').trim();
  }
  function applyArtistLink() {
    if (bcLinks === null || !lastSong) return;
    var el = document.querySelector('.radio-player-widget .now-playing-artist');
    var artist = (lastSong.artist || '').trim();
    if (!el || !artist || (el.textContent || '').trim() !== artist) return; // Vue hasn't rendered this artist yet
    var url = bcLinks[bcNorm(artist) + '|' + bcNorm(lastSong.album)] || '';
    var link = el.querySelector('a.az-bc-link');
    if (link ? link.href === url : !url) return; // already correct (incl. no link available)
    el.textContent = artist;
    if (!url) return;
    link = document.createElement('a');
    link.className = 'az-bc-link';
    link.href = url;
    link.target = '_blank';
    link.rel = 'noopener';
    link.textContent = artist;
    el.textContent = '';
    el.appendChild(link);
  }

  (function () {
    // Hardcoded, not derived from location.pathname: the homepage serves this station's public
    // page directly at "/" (no redirect), so a /public/<shortcode> match never fires there.
    // Single-station page -> just hardcode it, matching homepage_redirect_url in azuracast.nix.
    var apiUrl = location.origin + '/api/nowplaying/radio_marcel';
    // Warm the browser cache with the NEXT track's cover while the current one is still playing.
    // The response already carries playing_next.song.art, and art URLs are immutable per track,
    // so by the time Vue swaps the src the bytes are local: the push transition starts instantly
    // instead of racing a ~390KB download.
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
