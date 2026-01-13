{
  description = "haralyzer from nixpkgs";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    packages.${system} = let
      haralyzer = pkgs.python3Packages.buildPythonPackage {
        pname = "haralyzer";
        version = "2.4.0";
        format = "setuptools";
        src = pkgs.fetchPypi {
          pname = "haralyzer";
          version = "2.4.0";
          sha256 = "1154162a328a5226bc6d1d9626be19536ae049dd44b0a160081054f4808326a5";
        };
        nativeBuildInputs = [pkgs.makeWrapper];
        postPatch = ''
          touch requirements.txt
          touch requirements-dev.txt
        '';
        propagatedBuildInputs = with pkgs.python3Packages; [
          cached-property
          python-dateutil
        ];
        postInstall = ''
          mkdir -p $out/bin
          cat > $out/bin/haralyzer <<'PY'
          #!${pkgs.python3}/bin/python
          import argparse
          import base64
          import hashlib
          import mimetypes
          import os
          import re
          from urllib.parse import unquote, urlparse

          from haralyzer import HarParser

          def sanitize_segment(segment):
              value = unquote(segment)
              value = re.sub(r"[^A-Za-z0-9._-]+", "_", value)
              return value or "index"

          def shorten_segment(segment, max_len=120):
              if len(segment) <= max_len:
                  return segment
              digest = hashlib.sha256(segment.encode("utf-8")).hexdigest()[:12]
              head = segment[: max_len - 13]
              return f"{head}-{digest}"

          def unique_path(path):
              if not os.path.exists(path):
                  return path
              base, ext = os.path.splitext(path)
              counter = 1
              while True:
                  candidate = f"{base}-{counter}{ext}"
                  if not os.path.exists(candidate):
                      return candidate
                  counter += 1

          def build_target(out_dir, url, mime_type):
              if url.startswith("data:"):
                  data_info = url.split(",", 1)[0]
                  header = data_info.split(":", 1)[1]
                  mime = header.split(";", 1)[0] if header else ""
                  extension = mimetypes.guess_extension(mime or "")
                  digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
                  extension = extension or ""
                  filename = f"data-{digest}{extension}"
                  dir_path = os.path.join(out_dir, "data")
                  os.makedirs(dir_path, exist_ok=True)
                  return os.path.join(dir_path, filename)

              parsed = urlparse(url)
              host = sanitize_segment(parsed.netloc or "unknown")
              path = parsed.path or "/"
              parts = [sanitize_segment(part) for part in path.split("/") if part]
              parts = [shorten_segment(part) for part in parts]
              if not parts:
                  parts = ["index"]
              filename = parts[-1]
              if not os.path.splitext(filename)[1]:
                  extension = mimetypes.guess_extension(mime_type or "")
                  if extension:
                      filename = f"{filename}{extension}"
              filename = shorten_segment(filename)
              dir_path = os.path.join(out_dir, host, *parts[:-1])
              os.makedirs(dir_path, exist_ok=True)
              return os.path.join(dir_path, filename)

          def main():
              parser = argparse.ArgumentParser()
              parser.add_argument("har_files", nargs="+")
              parser.add_argument("out_dir")
              args = parser.parse_args()

              out_dir = os.path.abspath(args.out_dir)

              for har_file in args.har_files:
                  har = HarParser.from_file(har_file)
                  for page in har.pages:
                      for entry in page.entries:
                          if not entry.response.text:
                              continue
                          data = entry.response.text
                          if entry.response.textEncoding == "base64":
                              try:
                                  data = base64.b64decode(data)
                              except Exception:
                                  continue
                          else:
                              data = data.encode("utf-8")
                          target = build_target(
                              out_dir,
                              entry.request.url,
                              entry.response.mimeType,
                          )
                          target = unique_path(target)
                          with open(target, "wb") as handle:
                              handle.write(data)

          if __name__ == "__main__":
              main()
          PY
          chmod +x $out/bin/haralyzer
          wrapProgram $out/bin/haralyzer --prefix PYTHONPATH : "$out/${pkgs.python3.sitePackages}"
        '';
      };
    in {
      inherit haralyzer;
      default = haralyzer;
    };
  };
}
