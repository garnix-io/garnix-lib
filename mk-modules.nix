flakeInputs: mkModulesOpts:
let
  lib = flakeInputs.nixpkgs.lib;

  systems = mkModulesOpts.systems or [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];

  flakeSchemaModule.options = {
    apps = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.str;
      default = { };
    };

    checks = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.package;
      default = { };
    };

    devShells = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.package;
      default = { };
    };

    packages = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.package;
      default = { };
    };

    nixosConfigurations = lib.mkOption {
      # This type will be checked by lib.nixosSystem below
      type = lib.types.lazyAttrsOf (lib.types.listOf lib.types.unspecified);
      default = { };
    };

    garnix = {
      deployBranch = lib.mkOption {
        type = lib.types.str;
        description = "The branch that garnix will automatically deploy servers from on push";
      };

      config.servers = lib.mkOption {
        # This type is checked by garnix CI on push
        # See https://garnix.io/docs/yaml_config for documentation
        type = lib.types.listOf lib.types.unspecified;
        default = [ ];
      };
    };
  };

  evalModules = system: lib.evalModules {
    specialArgs = {
      pkgs = import flakeInputs.nixpkgs { inherit system; };
      inherit system;
    };
    modules = [
      flakeSchemaModule
      (mkModulesOpts.config or { })
    ] ++ (mkModulesOpts.modules or [ ]);
  };

  evaledModulesForSystem = builtins.listToAttrs (map (system: { name = system; value = evalModules system; }) systems);
in
{
  apps = builtins.mapAttrs
    (_: evaled:
      builtins.mapAttrs (_: program: { type = "app"; inherit program; }) evaled.config.apps
    )
    evaledModulesForSystem;

  packages = builtins.mapAttrs (_: evaled: evaled.config.packages) evaledModulesForSystem;

  checks = builtins.mapAttrs (_: evaled: evaled.config.checks) evaledModulesForSystem;

  devShells = builtins.mapAttrs
    (_: evaled: evaled.config.devShells // {
      # combine all defined devshells into a single "default" devshell
      default =
        let pkgs = evaled._module.specialArgs.pkgs;
        in pkgs.mkShell {
          inputsFrom = builtins.attrValues evaled.config.devShells;
        };
    })
    evaledModulesForSystem;

  nixosConfigurations = builtins.mapAttrs
    (name: nixosModules: lib.nixosSystem {
      modules = [
        flakeInputs.self.nixosModules.garnix
        {
          # This sets up networking and filesystems in a way that works with garnix hosting.
          garnix.server.enable = true;

          # This is currently the only allowed value.
          nixpkgs.hostPlatform = "x86_64-linux";

          # Settings to improve nixos vm debuggability
          virtualisation.vmVariant = {
            virtualisation.graphics = false;
            users.users.root.password = "";
          };
        }
      ] ++ nixosModules;
    })
    evaledModulesForSystem.x86_64-linux.config.nixosConfigurations;

  garnix.config.servers =
    let
      config = evaledModulesForSystem.x86_64-linux.config;
    in
    lib.lists.concatMap
      (nixosConfigName: [
        {
          configuration = nixosConfigName;
          deployment = {
            type = "on-branch";
            branch = config.garnix.deployBranch;
          };
        }
        {
          configuration = nixosConfigName;
          deployment = {
            type = "on-pull-request";
          };
        }
      ])
      (builtins.attrNames config.nixosConfigurations);
}
