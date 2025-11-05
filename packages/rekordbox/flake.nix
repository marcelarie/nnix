{
  description = "Rekordbox via Wine (declarative)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = {
    self,
    nixpkgs,
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = f:
      builtins.listToAttrs (map (system: {
          name = system;
          value = f system;
        })
        systems);

    mk = system: let
      pkgs = import nixpkgs {inherit system;};

      winePkg = pkgs.wineWowPackages.stagingFull;
      winebin = pkgs.wineWowPackages.stagingFull;
      winetricks = pkgs.winetricks;
      xdg-utils = pkgs.xdg-utils;
      curl = pkgs.curl;
      unzip = pkgs.unzip;
      vulkan-loader = pkgs.vulkan-loader;

      dollar = "$";
      prefixVar = "${dollar}{XDG_DATA_HOME:-${dollar}HOME/.local/share}/rekordbox/wineprefix";
      installerPath = "${dollar}{XDG_DATA_HOME:-${dollar}HOME/.local/share}/rekordbox/installer.exe";
      installerUrl = "https://cdn.rekordbox.com/files/20250610145851/Install_rekordbox_x64_6_8_6.zip";
      webviewInstaller = "${dollar}{XDG_DATA_HOME:-${dollar}HOME/.local/share}/rekordbox/MicrosoftEdgeWebView2RuntimeInstaller.exe";
      webviewUrl = "https://go.microsoft.com/fwlink/p/?LinkId=2124703";

      rekordbox-install = pkgs.writeShellApplication {
        name = "rekordbox-install";
        runtimeInputs = [winePkg winetricks xdg-utils curl unzip vulkan-loader];
        text = ''
          set -euo pipefail
          export WINEPREFIX="${prefixVar}"
          if [ ! -d "$WINEPREFIX" ]; then
            export WINEARCH=win64
          fi
          if [ -z "''${WINEDEBUG:-}" ]; then
            export WINEDEBUG=-all
          fi
          export WINEESYNC=1
          export STAGING_SHARED_MEMORY=1
          export WINEFSYNC=1

          installerDir=$(dirname "${installerPath}")
          mkdir -p "$installerDir"
          if [ ! -f "${installerPath}" ]; then
            tmpZip="$installerDir/rekordbox-installer.zip"
            echo "Downloading Rekordbox installer..."
            curl -fL -o "$tmpZip" "${installerUrl}"
            unzip -o -d "$installerDir" "$tmpZip" >/dev/null
            candidate="$(find "$installerDir" -maxdepth 1 -name 'Install_rekordbox*.exe' -print -quit)"
            if [ -z "$candidate" ]; then
              candidate="$(find "$installerDir" -maxdepth 2 -name 'Install_rekordbox*.exe' -print -quit)"
            fi
            if [ -n "$candidate" ] && [ "$candidate" != "${installerPath}" ]; then
              mv -f "$candidate" "${installerPath}"
            fi
            rm -f "$tmpZip"
          fi
          if [ ! -f "${installerPath}" ]; then
            echo "Unable to obtain Rekordbox installer at: ${installerPath}"
            exit 1
          fi
          if [ ! -f "${webviewInstaller}" ]; then
            echo "Downloading Microsoft Edge WebView2 runtime..."
            curl -fL -o "${webviewInstaller}" "${webviewUrl}"
          fi

          winetricks -q win10 || true
          winetricks -q corefonts || true
          winetricks settings fontsmooth=rgb || true
          winetricks -q dxvk || true
          winetricks -q vcrun2019 || true
          winetricks -q mf || true
          echo "Installing WebView2 runtime..."
          wine start /unix "${webviewInstaller}" /silent /install || true
          wineserver -w || true
          wine "${installerPath}"

          echo "Done. Launch with: nix run .#rekordbox"
        '';
      };

      rekordbox-run = pkgs.writeShellApplication {
        name = "rekordbox";
        runtimeInputs = [winePkg xdg-utils vulkan-loader];
        text = ''
          set -euo pipefail
          export WINEPREFIX="${prefixVar}"
          if [ -z "''${WINEDEBUG:-}" ]; then
            export WINEDEBUG=-all
          fi
          export WINEESYNC=1
          export STAGING_SHARED_MEMORY=1
          export WINEFSYNC=1

          echo "Wine prefix: $WINEPREFIX"
          exe_host="$WINEPREFIX/drive_c/Program Files/Pioneer/rekordbox/rekordbox.exe"
          if [ ! -f "$exe_host" ]; then
            exe_host="$(find "$WINEPREFIX/drive_c" -type f -name rekordbox.exe -print -quit 2>/dev/null || true)"
          fi
          if [ -z "$exe_host" ] || [ ! -f "$exe_host" ]; then
            echo "Rekordbox not found in prefix. Run: nix run .#rekordbox-install"
            exit 1
          fi
          echo "Launching Rekordbox from: $exe_host"
          wine start /unix "$exe_host"
          status=$?
          echo "wine start exit code: $status"
          if [ $status -ne 0 ]; then
            echo "Falling back to direct wine execution"
            if command -v winepath >/dev/null 2>&1; then
              exe_win="$(winepath -w "$exe_host")"
            else
              exe_win="$exe_host"
            fi
            wine "$exe_win"
          fi
          wineserver -w || true
        '';
      };

      desktopItem = pkgs.makeDesktopItem {
        name = "rekordbox";
        desktopName = "Rekordbox (Wine)";
        exec = "${rekordbox-run}/bin/rekordbox";
        categories = ["Audio" "AudioVideo" "Music"];
        terminal = false;
      };

      bundle = pkgs.symlinkJoin {
        name = "rekordbox-wine-tools";
        paths = [rekordbox-install rekordbox-run desktopItem];
      };
    in {
      packages = {
        default = bundle;
        rekordbox = bundle;
        rekordbox-install = rekordbox-install;
      };

      apps = {
        default = {
          type = "app";
          program = "${rekordbox-run}/bin/rekordbox";
        };
        rekordbox = {
          type = "app";
          program = "${rekordbox-run}/bin/rekordbox";
        };
        rekordbox-install = {
          type = "app";
          program = "${rekordbox-install}/bin/rekordbox-install";
        };
      };
    };
  in {
    packages = forAllSystems (s: (mk s).packages);
    apps = forAllSystems (s: (mk s).apps);
  };
}
