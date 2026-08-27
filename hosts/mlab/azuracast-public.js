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

  function start() { if (started) return; if (autoplayOk !== true) return; var b = pb(); if (!b) return; started = true; clearInterval(iv); b.click(); }
  // AzuraCast fires 'now-playing' on the document when stream metadata arrives (same hook native autoplay uses).
  document.addEventListener('now-playing', function () { setTimeout(start, 0); }, { once: true });
  iv = setInterval(function () { if (pb()) setTimeout(start, 0); }, 300);
  setTimeout(function () { clearInterval(iv); }, 10000);

  function cleanup() {
    ['pointerdown', 'keydown', 'touchstart', 'wheel'].forEach(function (ev) {
      window.removeEventListener(ev, unmute, true);
    });
  }
  function unmute(e) {
    // pointer/touch on the album art precede a click handled by the art click handler (start+unmute); defer those.
    if ((e.type === 'pointerdown' || e.type === 'touchstart') &&
        e && e.target && e.target.closest && e.target.closest('.now-playing-art')) return;
    cleanup();
    // if the gesture landed on the volume/mute control, let its own click toggle (avoid a double-toggle)
    if (e && e.target && e.target.closest && e.target.closest('.radio-control-volume')) return;
    if (!isPlaying()) {                  // muted autoplay was blocked -> must start inside this user gesture
      started = true;                    // cancel any pending async start() so it won't fire and double-toggle
      clearInterval(iv);
      var b = pb(); if (b) b.click();    // play() within the gesture is always allowed by autoplay policy
    }
    if (isMuted()) {                     // only toggle if actually muted (avoids re-muting an already-unmuted store)
      var a = au(); if (a) a.muted = false;  // best-effort; AzuraCast uses a detached Audio (no <audio> in DOM),
      var m = mb(); if (m) m.click();        // so the store toggle (m.click) is what actually unmutes
    }
  }
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
      if (!isPlaying()) {                                  // paused -> start; unmute only if still muted (first start)
        started = true; clearInterval(iv);
        b.click();
        if (isMuted()) {
          var a = au(); if (a) a.muted = false;
          var m = mb(); if (m) m.click();
          cleanup();
        }
      } else {
        b.click();                                         // playing -> pause
      }
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
