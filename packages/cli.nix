{
  craneLib,
  fetchFromGitHub,
  darwin,
  stdenv,
  lib,
  libiconv,
  pkg-config,
  openssl,
}:
let
  commonArgs = rec {
    pname = "trieve-cli";
    version = "0.5.3";
    src = fetchFromGitHub {
      owner = "devflowinc";
      repo = pname;
      rev = "d4c897c92902999331a23198dc22be3f20683a52";
      hash = "sha256-+O4F9vTqYg4Eju0RBIyQ6aIw8Wb33bchSygUpunfFBs=";
    };
    strictDeps = true;
    nativeBuildInputs = lib.optionals stdenv.isLinux [ pkg-config ];
    buildInputs =
      lib.optionals stdenv.isDarwin (
        with darwin.apple_sdk.frameworks;
        [
          SystemConfiguration
          libiconv
        ]
      )
      ++ lib.optionals stdenv.isLinux [ openssl.dev ];
  };
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
  totalArgs = commonArgs // {
    inherit cargoArtifacts;
  };
in
craneLib.buildPackage (totalArgs // { meta.mainProgram = "trieve"; })
