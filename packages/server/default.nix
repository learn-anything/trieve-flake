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
  fetchpatch2,
  defaultReleaseProfile ? false,
}:
let
  common = import ../common.nix;
  swagger-ui = fetchurl rec {
    pname = "swagger-ui";
    version = "5.17.12";
    url = "https://github.com/swagger-api/swagger-ui/archive/refs/tags/v${version}.zip";
    hash = "sha256-HK4z/JI+1yq8BTBJveYXv9bpN/sXru7bn/8g5mf2B/I=";
  };
  commonArgs = rec {
    pname = "trieve";
    inherit (common) version;
    src = fetchFromGitHub common.src;
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
      src = "${src}/server";
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
  cargoArtifacts = craneLib.buildDepsOnly (
    commonArgs
    // {
      cargoLock = "${commonArgs.src}/server/Cargo.lock";
    }
  );
  totalArgs = commonArgs // {
    inherit cargoArtifacts;
    patches = [
      (fetchpatch2 {
        url = "https://github.com/devflowinc/trieve/pull/2592.patch";
        hash = "sha256-NiKXzNBLyFV4V5Tl/4QcXfTq3EzQy8dN/P46lE2TEk0=";
        relative = "server";
      })
      (fetchpatch2 {
        url = "https://github.com/devflowinc/trieve/pull/2590.patch";
        hash = "sha256-fRKHMcpRxUBpLsoQUEAxxR5fSFXj3WkOaLIH2vTKszI=";
        relative = "server";
      })
      (fetchpatch2 {
        url = "https://github.com/devflowinc/trieve/pull/2625.patch";
        hash = "sha256-aCOfsp3ZH9ZrCglOtVN0lfB5kBx/aKEp8eEphjhQ2xQ=";
        relative = "server";
      })
    ] ++ lib.optional defaultReleaseProfile ./release.patch;
  };
in
craneLib.buildPackage (
  totalArgs
  // {
    postInstall = ''
      mkdir -p "$out/share/"
      cp -R ./migrations/ "$out/share/"
      cp -R ./ch_migrations/ "$out/share/"
      mkdir -p "$out/share/src/"
      cp -R ./src/public/ "$out/share/src/"
    '';
  }
)
