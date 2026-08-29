# Persist jiti's on-the-fly TS transpile cache so pi stays warm-start across
# nix-shell sessions.
#
# Root cause: nix-shell gives every shell a fresh ephemeral TMPDIR. jiti (pi's
# TS extension loader) has no env var to set the cache *path* (JITI_FS_CACHE /
# JITI_CACHE are booleans). Its cache dir is chosen by, in order:
#   (a) the programmatic `cache` option passed to createJiti,
#   (b) auto-detect of node_modules/.cache/jiti near the caller file,
#   (c) os.tmpdir()/jiti.
# pi passes no `cache` opt and its caller file (loader.js) lives in the
# read-only nix store, so (a)/(b) are unreachable without a patch and jiti
# falls back to (c) -> the per-shell TMPDIR -> wiped every shell -> cold
# recompile every time.
#
# This overlay does (a): inject `cache:` into pi's createJiti call so jiti
# writes to a persistent, jiti-only dir. pi's own ephemeral os.tmpdir() usage
# (bash output accumulator, external editor) is left on the shell TMPDIR, so
# it keeps getting cleaned up as intended -- only the transpile cache persists.
#
# Override the cache dir with PI_JITI_CACHE=/path; default $XDG_CACHE_HOME/pi/jiti
# (-> ~/.cache/pi/jiti). If pi bumps and the createJiti call changes shape,
# --replace-fail makes the build fail loudly so this can be updated.
final: prev: {
  pi-coding-agent = prev.pi-coding-agent.overrideAttrs (old: {
    postFixup =
      (old.postFixup or "")
      + ''
        substituteInPlace "$out/lib/node_modules/pi-monorepo/dist/core/extensions/loader.js" \
          --replace-fail 'moduleCache: false,' 'moduleCache: false, cache: process.env.PI_JITI_CACHE || path.join(process.env.XDG_CACHE_HOME || path.join(process.env.HOME || "/tmp", ".cache"), "pi", "jiti"),'
      '';
  });
}
