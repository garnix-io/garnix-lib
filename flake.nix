{
  description = "Nix helpers for garnix users";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    nixosModules.garnix = { lib, config, ... }:
      let
        cfg = config.garnix.server;
      in
      {
        options.garnix = {
          server = {
            enable = lib.mkEnableOption "Turn on default settings for servers running on Garnix hardware.";

            persistence = {
              enable = lib.mkEnableOption "Turn this machine into a persistent machine in garnix deploys";

              name = lib.mkOption {
                type = lib.types.str;
                description = "A unique name to identify this persistent nixos configuration. If a subsequent deploy defines a server with the same persistence name, it'll reuse the same machine, including disks.";
              };
            };
          };
        };

        config = lib.mkMerge [
          (lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = config.fileSystems."/".device == "/dev/sda1";
                message = "garnix.server needs the fileSystems.\"/\".device to be \"/dev/sda1\"";
              }
              {
                assertion = config.fileSystems."/".fsType == "ext4";
                message = "garnix.server needs the fileSystems.\"/\".fsType to be \"ext4\"";
              }
              {
                assertion = config.boot.loader.grub.device == "/dev/sda";
                message = "garnix.server needs the boot.loader.grub.device to be \"/dev/sda\"";
              }
            ];

            fileSystems."/" = {
              device = "/dev/sda1";
              fsType = "ext4";
            };
            boot.loader.grub.device = "/dev/sda";
          })

          (lib.mkIf cfg.persistence.enable {
            assertions = [
              {
                assertion = config.garnix.server.enable;
                message = "garnix.server.enable needs to be set to \"true\" for persistence to work.";
              }
              {
                assertion = config.garnix.server.persistence.name != "";
                message = "garnix.server.persistence.name must be non-empty.";
              }
              {
                assertion = config.security.sudo.enable;
                message = "garnix.server.persistence needs security.sudo enabled, but some other module forced the value to 'false'";
              }
              {
                assertion = config.security.sudo.execWheelOnly;
                message = "garnix.server.persistence needs security.sudo.execWheelOnly enabled, but some other module forced the value to 'false'";
              }
              {
                assertion = !config.security.sudo.wheelNeedsPassword;
                message = "garnix.server.persistence needs security.sudo.wheelNeedsPassword disabled, but some other module forced the value to 'true'";
              }
              {
                assertion = lib.elem "garnix" config.nix.settings.trusted-users;
                message = "garnix.server.persistence needs the user 'garnix' to be present in 'nix.settings.trusted-users', but some other module forced it out.";
              }
              {
                assertion = lib.elem "garnix" (lib.attrNames config.users.users);
                message = "garnix.server.persistence needs the user 'garnix' to be present in 'users.users', but some other module forced it out.";
              }
            ];

            services.openssh.enable = true;

            security.sudo = {
              enable = true;
              execWheelOnly = true;
              wheelNeedsPassword = false;
            };

            nix.settings.trusted-users = [ "garnix" ];

            users.users.garnix = {
              description = "A user garnix uses for redeploying ${cfg.persistence.name}";
              isNormalUser = true;
              createHome = false;
              openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJTPguYAuqp6qCU43u8g2hgWz4MLCEPPyoVPYO53qB+t garnixServer@garnix.io"
              ];
              extraGroups = [ "wheel" ];
            };
          })
        ];
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

    nixosConfigurations.sampleConfig = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.garnix
        {
          garnix.server.enable = true;
          garnix.server.persistence.enable = true;
          garnix.server.persistence.name = "sampleConfig";
        }
      ];
    };
  };
}
