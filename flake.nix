{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    ez-configs.url = "github:ehllie/ez-configs";
    ez-configs.inputs = {
      flake-parts.follows = "flake-parts";
      nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      nixpkgs,
      flake-parts,
      ez-configs,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.platforms.all;
      imports = [
        ez-configs.flakeModule
      ];
      ezConfigs.root = ./.;

      perSystem =
        { pkgs, ... }:
        {
          packages.server = pkgs.callPackage ./packages/server { };
          packages.frontends = pkgs.callPackage ./packages/frontends { };
        };
    };
}
