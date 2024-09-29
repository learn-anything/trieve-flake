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
    crane.url = "github:ipetkov/crane";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ez-configs,
      crane,
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
        inherit nixpkgs;
      };

      flake.lib = import ./lib { inherit nixpkgs; };

      perSystem =
        { pkgs, ... }:
        let
          craneLib = crane.mkLib pkgs;
        in
        {
          packages.server = pkgs.callPackage ./packages/server { inherit craneLib; };
          packages.frontends = pkgs.callPackage ./packages/frontends { };
        };
    };
  nixConfig = {
    substituters = [ "https://trieve.cachix.org" ];
    trusted-public-keys = [ "trieve.cachix.org-1:eD5aNrNhvhSS/9jwGEUAuN7W4ifogVSDUk1XdjmrT+I=" ];
  };
}
