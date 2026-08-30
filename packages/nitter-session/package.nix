{pkgs}: let
  python = pkgs.python3.withPackages (ps: with ps; [curl-cffi pyotp]);
in
  pkgs.writeShellApplication {
    name = "nitter-session";
    runtimeInputs = [python];
    text = ''
      if [ $# -lt 2 ]; then
        echo "usage: nitter-session <username> <password> [totp_seed] [--append sessions.jsonl]" >&2
        echo "output: one JSONL line for the nitter_sessions sops secret" >&2
        exit 1
      fi
      exec python3 ${pkgs.nitter.src}/tools/create_session_curl.py "$@"
    '';
  }
