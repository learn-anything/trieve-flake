{
  self,
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.services.trieve;
  redis-cfg = config.services.redis.servers.trieve;
  inherit (lib) types;
in
{
  imports = [ self.nixosModules.clickhouse ];
  options = {
    services.trieve = {
      enable = lib.mkEnableOption "trieve";
      frontends = {
        package = lib.mkOption {
          type = types.package;
          default = self.packages.${pkgs.system}.frontends;
        };
      };
      server = {
        package = lib.mkOption {
          type = types.package;
          default = self.packages.${pkgs.system}.server;
          description = "The trieve package to use.";
        };
        environmentFile = lib.mkOption {
          type = types.nullOr types.path;
          default = null;
        };
        environment = lib.mkOption {
          type = types.attrsOf (
            types.nullOr (
              types.oneOf [
                types.str
                types.path
                types.package
              ]
            )
          );
          default = { };
        };
        oidc = {
          id = lib.mkOption {
            type = types.str;
            default = "trieve";
          };
          issuer = lib.mkOption {
            type = types.str;
            example = "https://auth.yourdomain.com/realms/trieve";
          };
          auth-redirect = lib.mkOption {
            type = types.str;
            example = "https://auth.yourdomain.com/realms/trieve/protocol/openid-connect/auth";
          };
        };
        port = lib.mkOption {
          type = types.port;
          readOnly = true;
          default = 8090;
        };
        unlimited = lib.mkOption {
          type = types.bool;
          default = false;
          example = true;
        };
        openai-base-url = lib.mkOption {
          type = types.str;
          default = "https://api.openai.com/v1";
        };
        redis-connections = lib.mkOption {
          type = types.ints.positive;
          default = 2;
        };
        quantize-vectors = lib.mkOption {
          type = types.bool;
          default = false;
          example = true;
        };
        replication-factor = lib.mkOption {
          type = types.ints.positive;
          default = 2;
        };
        vector-sizes = lib.mkOption {
          type = types.listOf types.ints.positive;
          default = [
            384
            512
            768
            1024
            1024
            1536
            3072
          ];
        };
        log = lib.mkOption {
          type = types.str;
          default = "INFO";
        };
      };
      domain =
        let
          mkDomainOption =
            name:
            lib.mkOption {
              type = types.str;
              example = "${name}.yourdomain.com";
            };
        in
        {
          dashboard = mkDomainOption "dashboard";
          chat = mkDomainOption "chat";
          search = mkDomainOption "search";
          api = mkDomainOption "api";
        };
    };
  };
  config = lib.mkIf cfg.enable {
    services.tika.enable = true;
    services.caddy.enable = true;
    services.caddy.virtualHosts =
      let
        frontendCaddyConfig = name: ''
          root * ${cfg.frontends.package}/share/trieve/${name}
          templates
          try_files {path} {path}/ =404
          file_server
        '';
      in
      {
        ${cfg.domain.api}.extraConfig = ''
          reverse_proxy localhost:${toString cfg.server.port}
        '';
      }
      // lib.listToAttrs (
        map
          (name: {
            name = cfg.domain.${name};
            value = {
              extraConfig = frontendCaddyConfig name;
            };
          })
          [
            "dashboard"
            "chat"
            "search"
          ]
      );
    services.postgresql.enable = true;
    services.postgresql.ensureDatabases = [ "trieve" ];
    services.postgresql.ensureUsers = [
      {
        name = "trieve";
        ensureDBOwnership = true;
      }
    ];
    services.redis.servers.trieve = {
      enable = true;
      unixSocketPerm = 660;
      port = 0;
    };
    services.qdrant.enable = true;
    services.minio = {
      enable = true;
    };
    services.clickhouse.enable = true;
    services.clickhouse.users.users.trieve = {
      networks.ip = [
        "::1"
        "127.0.0.1"
      ];
    };
    systemd.services.caddy.environment = {
      VITE_API_HOST = "https://${cfg.domain.api}/api";
      VITE_SEARCH_UI_URL = "https://${cfg.domain.search}";
      VITE_CHAT_UI_URL = "https://${cfg.domain.chat}";
      VITE_DASHBOARD_URL = "https://${cfg.domain.dashboard}";
      VITE_SENTRY_DASHBOARD_DSN = "";
      VITE_BM25_ACTIVE = "true";
    };
    systemd.services.trieve =
      let
        dbServices = [
          "postgresql.service"
          "redis-trieve.service"
          "qdrant.service"
          "minio.service"
          "tika.service"
        ];
      in
      {
        description = "Trieve server";
        wantedBy = [ "multi-user.target" ];
        wants = dbServices;
        after = dbServices;
        serviceConfig = {
          DynamicUser = true;
          ExecStart = lib.getExe' cfg.server.package "trieve-server";
          EnvironmentFile = cfg.server.environmentFile;
          SupplementaryGroups = [ redis-cfg.user ];
        };
        environment = {
          DATABASE_URL = "postgresql:///trieve?user=trieve&host=/run/postgresql/&port=${toString config.services.postgresql.settings.port}";
          REDIS_URL = "redis+unix://${redis-cfg.unixSocket}";
          QDRANT_URL =
            let
              inherit (config.services.qdrant.settings) service;
            in
            "http://${service.host}:${toString service.grpc_port}";
          TIKA_URL =
            let
              inherit (config.services) tika;
            in
            "http://${tika.listenAddress}:${toString tika.port}";
          S3_ENDPOINT =
            let
              inherit (config.services) minio;
            in
            "http://${minio.listenAddress}";
          OIDC_CLIENT_ID = cfg.server.oidc.id;
          OIDC_ISSUER_URL = cfg.server.oidc.issuer;
          OIDC_AUTH_REDIRECT_URL = cfg.server.oidc.auth-redirect;
          BASE_SERVER_URL = "https://${cfg.domain.api}";
          REDIS_CONNECTIONS = toString cfg.server.redis-connections;
          UNLIMITED = lib.boolToString cfg.server.unlimited;
          REPLICATION_FACTOR = toString cfg.server.replication-factor;
          VECTOR_SIZES = lib.concatMapStringsSep "," toString (
            lib.sort (a: b: a < b) cfg.server.vector-sizes
          );
          RUST_LOG = cfg.server.log;
          CLICKHOUSE_USER = "trieve";
          CLICKHOUSE_DB = "trieve";
          CLICKHOUSE_URL = "http://localhost:8123"; # TODO: use port from config
        };
      };
  };
}
