{
  craneLib,
  lib,
  fetchFromGitHub,
  fetchurl,
  openssl,
  postgresql,
  stdenv,
  darwin,
  pkg-config,
  libiconv,
  defaultReleaseProfile ? false,
}:
let
  swagger-ui = fetchurl rec {
    pname = "swagger-ui";
    version = "5.17.12";
    url = "https://github.com/swagger-api/swagger-ui/archive/refs/tags/v${version}.zip";
    hash = "sha256-HK4z/JI+1yq8BTBJveYXv9bpN/sXru7bn/8g5mf2B/I=";
  };
  commonArgs = rec {
    pname = "trieve";
    version = "0.11.8";
    src = fetchFromGitHub {
      owner = "devflowinc";
      repo = "trieve";
      rev = "v${version}";
      hash = "sha256-4osska+/OTRPQyUxnBDb9m5+urbZSFwqV0HvIGIQPwM=";
    };
    sourceRoot = "${src.name}/server";
    strictDeps = true;
    env.SWAGGER_UI_DOWNLOAD_URL = "file://${swagger-ui}";
    buildInputs =
      [
        openssl
        postgresql
      ]
      ++ lib.optionals stdenv.isDarwin [
        darwin.apple_sdk.frameworks.SystemConfiguration
        libiconv
      ];
    nativeBuildInputs = [ pkg-config ];
    cargoExtraArgs = "--features runtime-env";
    cargoVendorDir = craneLib.vendorCargoDeps {
      cargoLock = ./Cargo.lock;
      overrideVendorCargoPackage =
        p: drv:
        if p.name == "qdrant-client" && p.version == "1.10.1" then
          drv.overrideAttrs { postPatch = ''rm build.rs''; }
        else if p.name == "utoipa-swagger-ui" && p.version == "7.1.0" then
          drv.overrideAttrs { patches = [ ./utoipa.patch ]; }
        else
          drv;
    };
  };
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
  totalArgs = commonArgs // {
    postPatch = ''
      rm migrations/.gitkeep
    '';
    inherit cargoArtifacts;
    patches = lib.optional defaultReleaseProfile ./release.patch;
  };
in
craneLib.buildPackage (
  totalArgs
  // {
    postInstall = ''
      mkdir -p "$out/share/trieve"
      cp -R ./migrations/ "$out/share/trieve"
      cp -R ./ch_migrations/ "$out/share/trieve"
      mkdir -p "$out/share/trieve/src/"
      cp -R ./src/public/ "$out/share/trieve/src/"
    '';
  }
)
