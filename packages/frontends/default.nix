{
  fetchFromGitHub,
  stdenv,
  fetchYarnDeps,
  yarnConfigHook,
  nodejs,
  lib,
  buildFrontends ? [
    "analytics"
    "chat"
    "dashboard"
    "search"
  ],
}:
let
  common = import ../common.nix;
in
stdenv.mkDerivation rec {
  pname = "trieve-frontends";
  inherit (common) version;

  src = fetchFromGitHub common.src;
  yarnOfflineCache = fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-ZD5uCXrPblWrbUShllCA9wt2GTLQxGHdKeBLGVrM+lo=";
  };

  buildPhase =
    ''
      runHook preBuild
      (
        cd clients/ts-sdk/
        yarn --offline run build
      )
      cd frontends
    ''
    + lib.concatMapStrings (
      name: # sh
      ''
        (
          cd ${lib.escapeShellArg name}
          yarn --offline run build
        )
      '') buildFrontends
    + ''
      runHook postBuild
    '';
  nativeBuildInputs = [
    yarnConfigHook
    nodejs
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/trieve/"
    for dist in */dist; do 
      member="$(basename "$(dirname "$dist")")"
      cp -R "$dist" "$out/share/trieve/$member"
    done
    runHook postInstall
  '';

  fixupPhase = ''
    runHook preFixup
    cd "$out/share/trieve/"
    sed -i -E -e 's/\$\{([A-Z0-9_]+)\}/{{ env "\1" }}/g' */index.html
    runHook postFixup
  '';
}
