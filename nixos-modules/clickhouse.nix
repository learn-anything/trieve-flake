{
  self,
  nixpkgs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.clickhouse;
  inherit (lib) types;
  inherit (self.lib.clickhouse) toClickhouseXml;
  interval =
    let
      mkLimitOption =
        description:
        lib.mkOption {
          type = types.ints.unsigned;
          default = 0;
          inherit description;
        };
    in
    types.submodule {
      options = {
        duration = lib.mkOption {
          type = types.ints.unsigned;
          description = "Length of interval";
        };
        queries = mkLimitOption "The total number of requests.";
        query_selects = mkLimitOption "The total number of select requests.";
        query_inserts = mkLimitOption "The total number of insert requests.";
        errors = mkLimitOption "The number of queries that threw an exception.";
        result_rows = mkLimitOption "The total number of rows given as a result.";
        read_rows = mkLimitOption "The total number of source rows read from tables for running the query on all remote servers.";
        execution_time = mkLimitOption "The total query execution time, in seconds (wall time).";
      };
    };
  quota = types.submodule {
    options.intervals = lib.mkOption {
      type = types.listOf interval;
      default = [ ];
    };
  };
  profile = types.submodule {
    options.readonly = lib.mkOption {
      type = types.bool;
      default = false;
      example = true;
    };
  };
  user = types.submodule (
    { name, ... }:
    {
      options = {
        password = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "User password in plaintext format";
        };
        passwordSha256 = lib.mkOption {
          type = types.nullOr (types.strMatching "[0-9a-fA-F]{64}");
          default = null;
          description = ''
            User password SHA-256 hash.
            Use the following to generate it:
            ```sh
            printf "%s" "$PASSWORD" | sha256sum | tr -d '-'
            ```
          '';
        };
        passwordDoubleSha1 = lib.mkOption {
          type = types.nullOr (types.strMatching "[0-9a-f-A-F]{40}");
          default = null;
          description = ''
            User password double SHA-1 hash.
            Use the following to generate it:
            ```sh
            printf "%s" "$PASSWORD" | sha1sum | tr -d '-' | xxd -r -p | sha1sum | tr -d '-'
            ```
          '';
        };
        kerberos = {
          # TODO
        };
        ldap = {
          # TODO
        };
        ssh_keys = {
          # TODO
        };
        networks = {
          ip = lib.mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
          host = lib.mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
          host_regexp = lib.mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
        };
        profile = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Settings profile for user.";
        };
        quota = lib.mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Quota for user.";
        };
        access_management = lib.mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Allow the user to create other users and grant rights to them";
        };
        named_collection_control = lib.mkOption {
          type = types.nullOr types.bool;
          default = null;
          example = true;
          description = "Allow the user to manipulate named collections";
        };
        allow_databases = lib.mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          example = [ name ];
        };
        grants = lib.mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          description = "List of GRANT queries without a grantee specified to run for this user";
        };
      };
    }
  );
in
{
  disabledModules = [ "${nixpkgs}/nixos/modules/services/databases/clickhouse.nix" ];
  options = {
    services.clickhouse = {
      enable = lib.mkEnableOption "ClickHouse database server";
      package = lib.mkPackageOption pkgs "clickhouse" { };
      users = {
        profiles = lib.mkOption {
          type = types.attrsOf profile;
          default = {
            default = { };
            readonly = {
              readonly = true;
            };
          };
        };
        users = lib.mkOption {
          type = types.attrsOf user;
          default = {
            default = {
              password = "";
              networks = {
                ip = [ "::/0" ];
              };
              profile = "default";
              quota = "default";
              access_management = true;
              named_collection_control = true;
            };
          };
        };
        quotas = lib.mkOption {
          type = types.attrsOf quota;
          default = {
            default = {
              intervals = [
                {
                  duration = 3600;
                  queries = 0;
                  errors = 0;
                  result_rows = 0;
                  read_rows = 0;
                  execution_time = 0;
                }
              ];
            };
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (
        let
          badUsers = lib.filterAttrs (
            _: x:
            x.grants != null
            && (x.access_management != null || x.named_collection_control != null || x.allow_databases != null)
          ) cfg.users.users;
        in
        {
          assertion = badUsers == { };
          message = "`grants` can not be used with `access_management` `named_collection_control` and `allow_databases` (users: ${lib.concatStringsSep ", " (lib.attrNames badUsers)})";
        }
      )
    ];
    users.users.clickhouse = {
      name = "clickhouse";
      uid = config.ids.uids.clickhouse;
      group = "clickhouse";
      description = "ClickHouse server user";
    };

    users.groups.clickhouse.gid = config.ids.gids.clickhouse;

    systemd.services.clickhouse = {
      description = "ClickHouse server";

      wantedBy = [ "multi-user.target" ];

      after = [ "network.target" ];

      serviceConfig = {
        Type = "notify";
        User = "clickhouse";
        Group = "clickhouse";
        ConfigurationDirectory = "clickhouse-server";
        AmbientCapabilities = "CAP_SYS_NICE";
        StateDirectory = "clickhouse";
        LogsDirectory = "clickhouse";
        ExecStart = "${cfg.package}/bin/clickhouse-server --config-file=/etc/clickhouse-server/config.xml";
        TimeoutStartSec = "infinity";
      };

      environment = {
        # Switching off watchdog is very important for sd_notify to work correctly.
        CLICKHOUSE_WATCHDOG_ENABLE = "0";
      };
    };

    environment.etc = {
      "clickhouse-server/config.xml" = {
        source = "${cfg.package}/etc/clickhouse-server/config.xml";
      };

      "clickhouse-server/users.xml" = {
        # source = "${cfg.package}/etc/clickhouse-server/users.xml";
        text = toClickhouseXml { boolToString = x: if x then "1" else "0"; } {
          profiles = cfg.users.profiles;
          quotas = cfg.users.quotas;
          users = lib.mapAttrs (
            _: x:
            lib.filterAttrs (_: p: p != null) {
              password_sha256_hex = x.passwordSha256;
              password_double_sha1_hex = x.passwordDoubleSha1;
              inherit (x)
                password
                networks
                profile
                quota
                access_management
                named_collection_control
                ;
              allow_databases = lib.mapNullable (database: { inherit database; }) x.allow_databases;
              grants = lib.mapNullable (query: { inherit query; }) x.grants;
            }
          ) cfg.users.users;
        };
      };
    };

    environment.systemPackages = [ cfg.package ];

    # startup requires a `/etc/localtime` which only exists if `time.timeZone != null`
    time.timeZone = lib.mkDefault "UTC";
  };
}
