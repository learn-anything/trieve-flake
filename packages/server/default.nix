{
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  openssl,
  pkg-config,
  lib,
  stdenv,
  darwin,
  postgresql,
  # use the default cargo release profile instead of the heavilily optimised one included in trieve
  # this can reduce compile times from a hundred of minutes to ten miinutes (on my machine)
  defaultReleaseProfile ? false,
}:
let
  swagger-ui = fetchurl rec {
    pname = "swagger-ui";
    version = "5.17.12";
    url = "https://github.com/swagger-api/swagger-ui/archive/refs/tags/v${version}.zip";
    hash = "sha256-HK4z/JI+1yq8BTBJveYXv9bpN/sXru7bn/8g5mf2B/I=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "trieve-server";
  version = "0.11.8";

  src = fetchFromGitHub {
    owner = "devflowinc";
    repo = "trieve";
    rev = "v${version}";
    hash = "sha256-4osska+/OTRPQyUxnBDb9m5+urbZSFwqV0HvIGIQPwM=";
  };
  cargoHash = "sha256-Z6Njc1t63Zwj4rWv+CSIhkKUMHlYyr7dZ0CJL3mmK6Q=";
  sourceRoot = "${src.name}/server";

  cargoPatches = lib.optional defaultReleaseProfile ./release.patch;
  postPatch = ''
    rm migrations/.gitkeep
  '';

  env.SWAGGER_UI_DOWNLOAD_URL = "file://${swagger-ui}";
  buildInputs = [
    openssl
    postgresql
  ] ++ lib.optionals stdenv.isDarwin [ darwin.apple_sdk.frameworks.SystemConfiguration ];
  nativeBuildInputs = [ pkg-config ];
  buildFeatures = [ "runtime-env" ];

  preCheck = ''
    printf 'Removing swagger-ui so utopia build script can copy it again:\n'
    find target -name "$(basename ${lib.escapeShellArg swagger-ui})" -prune -print -exec rm -r {} +
  '';

  postInstall = ''
    mkdir -p "$out/share/trieve"
    cp -R ./migrations/ "$out/share/trieve"
    cp -R ./ch_migrations/ "$out/share/trieve"
    mkdir -p "$out/share/trieve/src/"
    cp -R ./src/public/ "$out/share/trieve/src/"
  '';
}
