(function () {
  // Muted autoplay + unmute on first user gesture.
  // Browsers block unmuted autoplay without a prior gesture; muted play is always allowed.
  // Boot the AzuraCast player store muted (localStorage "player_muted" = "true", read once at boot),
  // start on load (muted), then unmute on the first pointer/keydown/wheel/touch via the mute button
  // so the store + mute-button UI stay in sync.
  try { localStorage.setItem('player_muted', 'true'); } catch (e) {}

  var pb = function () { return document.querySelector('.radio-control-play-button'); };
  var mb = function () { return document.querySelector('.radio-control-volume .btn'); };
  var au = function () { return document.querySelector('audio'); };

  var started = false, iv;
  function start() { if (started) return; var b = pb(); if (!b) return; started = true; clearInterval(iv); b.click(); }
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
    var a = au();
    if (!a) return;
    if (a.paused) {                    // muted autoplay was blocked on mobile -> must start inside this user gesture
      started = true;                  // cancel any pending async start() so it won't fire and double-toggle pause
      clearInterval(iv);
      var b = pb(); if (b) b.click();   // play() within the gesture is always allowed by autoplay policy
    }
    a.muted = false;                    // unmute the element
    var m = mb(); if (m) m.click();     // toggleMute -> store isMuted=false -> icon + audio stay in sync
  }
  ['pointerdown', 'keydown', 'touchstart', 'wheel'].forEach(function (ev) {
    window.addEventListener(ev, unmute, { capture: true, passive: true });
  });

  // Album art overlay: flashing PLAY/PAUSE text (center) + ZOOM corner.
  // Clicking the art toggles play/pause (the <a> lightbox is blocked); the zoom corner opens the lightbox.
  function relocate() {
    var art = document.querySelector('.radio-player-widget .now-playing-art');
    if (!art || art._azInit) return !!art;
    art._azInit = true;

    var ov = document.createElement('div');
    ov.className = 'az-overlay-play';
    art.appendChild(ov);

    var zm = document.createElement('div');
    zm.className = 'az-zoom';
    zm.textContent = 'ZOOM';
    art.appendChild(zm);

    // One source of truth: re-query audio each tick (element may be recreated), set label directly.
    function sync() {
      var a = au();
      if (!a) return;
      var label = a.paused ? 'PLAY' : 'PAUSE';
      if (ov.textContent !== label) ov.textContent = label;
      art.classList.toggle('az-paused', a.paused);
    }
    // events drive immediate updates; the poll is a self-correcting safety net (cheap, runs forever)
    document.addEventListener('play', sync, true);
    document.addEventListener('pause', sync, true);
    setInterval(sync, 500);
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
      var a = au(), b = pb();
      if (!b) return;
      if (a && a.paused) {                                 // start + unmute within this gesture
        started = true; clearInterval(iv);
        b.click();
        a.muted = false; var m = mb(); if (m) m.click();
        cleanup();
      } else {
        b.click();                                         // pause
      }
      setTimeout(sync, 0);                                 // reflect the new state immediately
    }, true);
    return true;
  }
  var riv = setInterval(function () { if (relocate()) clearInterval(riv); }, 200);
  setTimeout(function () { clearInterval(riv); }, 10000);
})();
