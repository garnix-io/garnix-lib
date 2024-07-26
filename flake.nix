{
  description = "Nix helpers for garnix users";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    nixosModules.garnix = { lib, config, ... }:
      let
        cfg = config.garnix;
      in
      {

        options.garnix = {
          enable = lib.mkEnableOption "Set options required for deploying to garnix";
          persistence = {
            enable = lib.mkEnableOption "Turn this machine into a persistent machine in garnix deploys";

            name = lib.mkOption {
              type = lib.types.str;
              description = "A unique name to identify this persistent nixos configuration. If a subsequent deploy defines a server with the same persistence name, it'll reuse the same machine, including disks.";
            };
          };
        };

        config = lib.mkIf cfg.enable {
          assertions = lib.mkIf cfg.persistence.enable [
            {
              assertion = config.security.sudo.enable;
              message = "garnix.persistence needs security.sudo enabled, but some other module forced the value to 'false'";
            }
            {
              assertion = config.security.sudo.execWheelOnly;
              message = "garnix.persistence needs security.sudo.execWheelOnly enabled, but some other module forced the value to 'false'";
            }
            {
              assertion = !config.security.sudo.wheelNeedsPassword;
              message = "garnix.persistence needs security.sudo.wheelNeedsPassword disabled, but some other module forced the value to 'true'";
            }
            {
              assertion = lib.elem "garnix" config.nix.settings.trusted-users;
              message = "garnix.persistence needs the user 'garnix' to be present in 'nix.settings.trusted-users', but some other module forced it out.";
            }
            {
              assertion = lib.elem "garnix" (lib.attrNames config.users.users);
              message = "garnix.persistence needs the user 'garnix' to be present in 'users.users', but some other module forced it out.";
            }
          ];
          fileSystems."/" = {
            device = "/dev/sda1";
            fsType = "ext4";
          };
          boot.loader.grub.device = "/dev/sda";

          services.openssh.enable = lib.mkIf cfg.persistence.enable true;

          security.sudo = lib.mkIf cfg.persistence.enable {
            enable = true;
            execWheelOnly = true;
            wheelNeedsPassword = false;
          };

          nix.settings.trusted-users = lib.mkIf cfg.persistence.enable [ "garnix" ];

          users.users.garnix = lib.mkIf cfg.persistence.enable {
            description = "A user garnix uses for redeploying ${cfg.persistence.name}";
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

    checks.x86_64-linux.main = nixpkgs.legacyPackages.x86_64-linux.haskellPackages.callCabal2nix "tests" ./tests {};
  };
}
