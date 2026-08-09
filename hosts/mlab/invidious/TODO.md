# Invidious — YouTube blocker mitigation

Setup: Invidious backend (native NixOS service, port 9800) + invidious-companion
(podman, `--network=host`, port 8282). Both egress via the host network, so
host-level IPv6 rotation / proxying covers both.

## Already in place
- IPv6 connectivity + `/64` subnet
- `channel_threads = 0` — InnerTube scraping disabled (was getting blocked)
- `feed_threads = 1` — RSS feeds for subscriptions (reliable)
- invidious-companion running, generates PO tokens (THC_VERSION=0.39.0)
- Last 7 days of logs: **no** 429 / PO token / ban signatures; direct curl to
  YouTube from mlab returns 200. Not currently blocked.

## TODO (priority order)

### 1. Pin + auto-update companion image
Currently `quay.io/invidious/invidious-companion:latest`, last pulled ~3 months
ago. `:latest` drifts silently and PO token logic changes often.
- Pin to a digest in `default.nix` (`image =
  "quay.io/invidious/invidious-companion@sha256:..."`)
- Schedule a weekly `podman image pull` + container recreate, or use
  `virtualisation.oci-containers` with `autoUpdate` / a systemd timer

### 2. Update Invidious backend
Build `2.20260723.0`; latest release `v2.20260804.1`. PO token / extractor
hotfixes land here frequently.
- Bump the nixpkgs ref (or override the invidious package rev) and
  `nixos-rebuild switch --flake .#mlab`

### 3. Install smart-ipv6-rotator (prevention, highest reliability)
Have IPv6 + `/64` but no rotation — the single most effective method per the
iv-org guide, and it's free.
- Clone to `/opt/smart-ipv6-rotator`
- Cron twice daily: `0 */12 * * * python /opt/smart-ipv6-rotator/run.py --ipv6range=YOUR_SUBNET/64`
- Verify egress IP changes: `curl -6 -m5 ipv6.icanhazip.com` before/after

### 4. Ban / PO token monitoring
Catch blocks before users report them.
- Systemd timer running a journalctl grep for:
  `429|po.?token|playability|sign in to confirm|bot`
- Emit to the existing monitoring (homepage widget / gotify / matrix) on hit

### 5. Fallbacks (only if bans recur after rotation)
- **WARP via wgcf**: generate WireGuard config, route `*.youtube.com` +
  `*.googlevideo.com` over it
- **Residential proxy / VPN**: Invidious supports outbound proxy in settings;
  companion supports `HTTP_PROXY`/`HTTPS_PROXY` env. Split-tunnel so only
  YouTube egresses via the proxy
