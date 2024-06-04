{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {

    lib = {
      getHashSubdomain = nixosCfg :
        let prefixLength = nixpkgs.lib.stringLength "/nix/store/";
            hash = builtins.substring prefixLength 32 nixosCfg.config.system.build.toplevel.drvPath;
        in hash + ".hash.garnix.me";
    };
  };
}
