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
          packages.frontends = pkgs.callPackage ./packages/frontends {
            env = {
              VITE_SENTRY_ANALYTICS_DSN = "";
              VITE_SENTRY_CHAT_DSN = "";
              VITE_SENTRY_DASHBOARD_DSN = "";
              VITE_SENTRY_SEARCH_DSN = "";
              VITE_API_HOST = "";
              VITE_DASHBOARD_URL = "";
              VITE_SEARCH_UI_URL = "";
              VITE_CHAT_UI_URL = "";
              VITE_ANALYTICS_UI_URL = "";
              VITE_BM25_ACTIVE = "";
            };
          };
        };
    };
}
