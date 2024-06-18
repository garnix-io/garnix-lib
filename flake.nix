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
            description = "A unique name to identify this persistence.";
          };
        };

        config = lib.mkIf cfg.enable {
          services.openssh.enable = true;

          security.sudo = {
            enable = true;
            execWheelOnly = true;
            wheelNeedsPassword = false;
          };

          users.users.garnix = {
            description = "A user garnix uses for redeploying ${cfg.name}";
            isNormalUser = true;
            createHome = false;
            openssh.authorizedKeys.keys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJTPguYAuqp6qCU43u8g2hgWz4MLCEPPyoVPYO53qB+t garnixServer@garnix.io"
            ];
            extraGroups = [ "wheel" ];
          };
        };
      };

    lib = rec {
      getHash = nixosCfg:
        let
          prefixLength = nixpkgs.lib.stringLength "/nix/store/";
          hash = builtins.substring prefixLength 32 nixosCfg.config.system.build.toplevel.drvPath;
        in
        hash + ".hash.garnix.me";
      getHashSubdomain = nixosCfg:
        if nixosCfg.config.garnix.persistence.enable
        then nixosCfg.config.garnix.persistence.name + ".persistent.garnix.me"
        else getHash nixosCfg;
    };
  };
}
