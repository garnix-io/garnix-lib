{
  description = "Nix helpers for garnix users";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    nixosModules.garnix = { lib, config, ... }:
      let cfg = config.garnix.persistence;
      in {

        options.garnix.persistence = {
          enable = lib.mkEnableOption "Enable persistence in garnix deploys";

          name = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "A unique name to identify this persistence." ;
          };
        };

        config = lib.mkIf cfg.enable {
          assertion = [
            { assertion = cfg.name != "";
              message = ''
                `garnix.persistence.name` must be set, and not the empty string, if
                persistence is enabled.
              '';
            }
          ];
          users.users.garnix = {
            description = "A user garnix uses for redeploying";
            isNormalUser = true;
            createHome = false;
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJTPguYAuqp6qCU43u8g2hgWz4MLCEPPyoVPYO53qB+t garnixServer@garnix.io"
            ];
            extraGroups = [ "wheel" ];
          };
        };
      };

    lib = {
      getHashSubdomain = nixosCfg :
        let prefixLength = nixpkgs.lib.stringLength "/nix/store/";
            hash = builtins.substring prefixLength 32 nixosCfg.config.system.build.toplevel.drvPath;
        in hash + ".hash.garnix.me";
    };

    checks.x86_64-linux.default = import ./test {
      inherit self;
      pkgs = nixpkgs;
    };
  };
}
