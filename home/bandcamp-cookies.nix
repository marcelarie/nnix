{pkgs, ...}: let
  py = pkgs.python3.withPackages (p: [p.browser-cookie3]);
  exportScript = pkgs.writeScript "bandcamp-cookies-export" ''
    #!${py}/bin/python3
    import browser_cookie3, os
    out = os.path.expanduser("~/Sync/bandcamp-cookies/cookies.txt")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    cj = browser_cookie3.brave(cookie_file=os.path.expanduser(
        "~/.config/BraveSoftware/Brave-Origin-Nightly/Default/Cookies"))
    with open(out, "w") as f:
        f.write("# Netscape HTTP Cookie File\n")
        for c in cj:
            if "bandcamp" not in c.domain: continue
            f.write(f"{c.domain}\t{'TRUE' if c.domain.startswith('.') else 'FALSE'}"
                    f"\t{c.path}\t{'TRUE' if c.secure else 'FALSE'}"
                    f"\t{int(c.expires or 0)}\t{c.name}\t{c.value}\n")
  '';
in {
  systemd.user = {
    services.bandcamp-cookies-export = {
      Unit.Description = "Export brave-origin bandcamp cookies for mlab syncthing";
      Service.ExecStart = toString exportScript;
    };
    timers.bandcamp-cookies-export = {
      Unit.Description = "Hourly bandcamp cookie export";
      Timer = {
        OnCalendar = "hourly";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
