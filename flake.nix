{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    # https://github.com/ehllie/ez-configs/pull/15
    # ez-configs.url = "github:ehllie/ez-configs";
    ez-configs.url = "github:thecaralice/ez-configs/early-args";
    ez-configs.inputs = {
      flake-parts.follows = "flake-parts";
      nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      self,
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
      ezConfigs.earlyModuleArgs = {
        inherit self;
      };

      flake.lib = import ./lib { inherit nixpkgs; };

      perSystem =
        { pkgs, ... }:
        {
          packages.server = pkgs.callPackage ./packages/server { };
          packages.frontends = pkgs.callPackage ./packages/frontends { };
        };
    };
}
