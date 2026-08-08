{
  pkgs,
  inputs,
  services,
  ...
}: let
  ytifySrc = pkgs.runCommand "ytify-src" {} ''
    cp -r ${inputs.ytify} $out
    chmod -R u+w $out
    cp ${./ytify/package-lock.json} $out/package-lock.json
    cp ${./ytify/server.ts} $out/server.ts
    cp ${./ytify/vite.server.config.ts} $out/vite.server.config.ts
    # make the SPA call /api on its own origin instead of the upstream worker
    # (whose CORS allowlist excludes our domain). same-origin = no CORS check.
    substituteInPlace $out/src/lib/stores/app.ts \
      --replace "'https://api.ytify.workers.dev'" "'/api'"
  '';
  ytify = pkgs.buildNpmPackage {
    pname = "ytify";
    version = "8.4-pr4";
    src = ytifySrc;
    npmDepsHash = "sha256-Mnmo0muZKAI4qvjkSa5w1qkcOnKaTThLjVi/7uxHD+8=";
    postBuild = ''
      ./node_modules/.bin/vite build --config vite.server.config.ts --outDir dist-server
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/ytify
      cp -r dist $out/share/ytify/dist
      cp dist-server/server.js $out/share/ytify/server.js
      runHook postInstall
    '';
  };
in {
  systemd.services.ytify = {
    description = "ytify — minimal YouTube audio streaming PWA";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    environment.PORT = toString services.ytify.port;
    serviceConfig = {
      ExecStart = "${pkgs.nodejs}/bin/node ${ytify}/share/ytify/server.js";
      DynamicUser = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      PrivateTmp = true;
      Restart = "on-failure";
    };
  };
}
