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

  // Move play button inside album art as a bottom overlay; show on hover, always show when paused.
  function relocate() {
    var art = document.querySelector('.radio-player-widget .now-playing-art');
    var b = pb(), a = au();
    if (!art || !b || !a || art.contains(b)) return false;
    art.appendChild(b);
    b.classList.add('az-overlay-play');
    function sync() { art.classList.toggle('az-paused', a.paused); }
    a.addEventListener('play', sync);
    a.addEventListener('pause', sync);
    sync();
    return true;
  }
  var riv = setInterval(function () { if (relocate()) clearInterval(riv); }, 200);
  setTimeout(function () { clearInterval(riv); }, 10000);
})();
