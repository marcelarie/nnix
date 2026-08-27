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
    return d;
  })();

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
    DBG('unmute', e.type, 'isPlaying=' + isPlaying(), 'isMuted=' + isMuted(), 'audioPaused=' + (au() ? au().paused : 'no-audio'), 'target=' + (e.target && (e.target.className || e.target.tagName)));
    // pointer/touch on the album art precede a click handled by the art click handler (start+unmute); defer those.
    if ((e.type === 'pointerdown' || e.type === 'touchstart') &&
        e && e.target && e.target.closest && e.target.closest('.now-playing-art')) { DBG('unmute: defer to art handler'); return; }
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
    cleanup();
    var a = au(), b = pb();
    if (a && !a.paused && !isMuted()) { if (b) b.click(); }   // playing+unmuted -> pause
    else { ensurePlaying(); }                                 // paused or muted -> start/unmute
  }
  // Spacebar toggles play/pause. Registered BEFORE the window 'unmute' keydown (capture, passive)
  // so stopImmediatePropagation stops it also firing ensurePlaying (which would re-start right
  // after a pause). preventDefault stops the page scrolling on Space. Skipped while focus is in
  // an input/textarea/contenteditable so we don't hijack typing a space.
  window.addEventListener('keydown', function (e) {
    if (e.key !== ' ' && e.code !== 'Space') return;
    var t = e.target;
    if (t && (t.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(t.tagName))) return;
    e.preventDefault();
    e.stopImmediatePropagation();      // block the 'unmute' keydown (same target+phase, reg'd later)
    if (e.repeat) return;              // held Space: still block scroll, but don't toggle again
    togglePlayPause();
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

    var triggeringZoom = false;
    art.addEventListener('click', function (e) {
      if (triggeringZoom) return;                          // synthetic click from zoom corner -> let <a> lightbox fire
      if (e.target.closest('.az-zoom')) {                  // zoom corner -> open lightbox via the <a>
        e.stopPropagation(); e.preventDefault();
        var link = art.querySelector('a.album-art');
        if (link) { triggeringZoom = true; link.click(); triggeringZoom = false; }
        return;
      }
      e.stopPropagation(); e.preventDefault();             // block <a> lightbox; image click toggles play
      togglePlayPause();                                  // pause if playing+unmuted, else start/unmute (trusting real audio state)
      setTimeout(sync, 0);                                 // reflect the new state immediately
    }, true);
    return true;
  }
  var riv = setInterval(function () { if (relocate()) clearInterval(riv); }, 200);
  setTimeout(function () { clearInterval(riv); }, 10000);

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
      updateMarquee(el);
      // Vue updates the text node -> re-measure. attributes (class/style) excluded -> no self-loop.
      new MutationObserver(function () { updateMarquee(el); }).observe(el, { childList: true, subtree: true, characterData: true });
    });
  }
  var miv = setInterval(function () { if (document.querySelector('.radio-player-widget .now-playing-title')) { setupMarquee(); clearInterval(miv); } }, 300);
  setTimeout(function () { clearInterval(miv); }, 10000);
  var rt;
  window.addEventListener('resize', function () { clearTimeout(rt); rt = setTimeout(setupMarquee, 150); });
})();
