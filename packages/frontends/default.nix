{
  fetchFromGitHub,
  stdenv,
  fetchYarnDeps,
  yarnConfigHook,
  nodejs,
  lib,
  envsubst,
  buildFrontends ? [
    "analytics"
    "chat"
    "dashboard"
    "search"
  ],
  env ? { },
}:
stdenv.mkDerivation rec {
  pname = "trieve-frontends";
  version = "0.11.8";
  src = fetchFromGitHub {
    owner = "devflowinc";
    repo = "trieve";
    rev = "v${version}";
    hash = "sha256-4osska+/OTRPQyUxnBDb9m5+urbZSFwqV0HvIGIQPwM=";
  };
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
    envsubst
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

  inherit env;

  fixupPhase = ''
    runHook preFixup
    cd "$out/share/trieve/"
    for member in *; do 
      mv "$member/index.html" index.html.template
      envsubst -no-digit -no-unset -i index.html.template -o "$member/index.html"
      rm index.html.template
    done
    runHook postFixup
  '';
}
