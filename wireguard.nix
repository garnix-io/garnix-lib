{ pkgs, lib, config, ... }: {
  options.garnix.wireguard = {
    enable = lib.mkEnableOption "Enable cross-host wireguard communication";

    port = lib.mkOption {
      description = "What UDP port wireguard should listen on";
      type = lib.types.port;
      default = 51820;
    };

    ip = lib.mkOption {
      description = "The IP address of this port on the wireguard network. These IPs can be any valid RFC1918 address you want. They just need to fall into the same /24 subnet as the machines they dial to/from.";
      example = "10.100.0.5";
      type = lib.types.str;
    };

    publicKey = lib.mkOption {
      description = "The wireguard public key for this host, generated with `wg pubkey`";
      type = lib.types.str;
    };

    privateKeyFile = lib.mkOption {
      description = "A file containing the wireguard private key of this host - typically encrypted and added to the machines with agenix or sopsnix";
      type = lib.types.path;
    };

    dialsTo = lib.mkOption {
      description = "A list of garnix nixos configurations this host should be able to dial out to. These must form a directed acyclic graph.";
      example =  lib.literalExpression "self.nixosConfigurations.my-host";
      type = lib.types.listOf lib.types.unspecified;
      default = [];
    };

    dialsFrom = lib.mkOption {
      description = "A list of garnix nixos configurations this host should be connectable from.";
      example =  lib.literalExpression "self.nixosConfigurations.my-host";
      type = lib.types.listOf lib.types.unspecified;
      default = [];
    };

    endpoint = lib.mkOption {
      description = "(Temporary for now.) This should be the FQDN ending in `raw.garnix.me` pointing to this server. In the future this will be automated with hash domains and this option will be removed.";
      example = "hostname.branch.repo.owner.raw.garnix.me";
      type = lib.types.strMatching "([^.]+\\.){4}raw\\.garnix\\.me";
    };
  };

  config = let
    cfg = config.garnix.wireguard;

    dialsToCfgs = lib.listToAttrs (
      map (nixosCfg: let
          err = "${myHostName} dials to ${dialToHostName}, but ${dialToHostName} does not enable garnix.wireguard";
          myHostName = config.networking.hostName;
          dialToHostName = nixosCfg.config.networking.hostName;
          dialToHostCfg = nixosCfg.config.garnix.wireguard or (throw err);
        in
          if dialToHostCfg.enable then
            { name = dialToHostName; value = dialToHostCfg; }
          else throw err
      ) cfg.dialsTo
    );

    dialsFromCfgs = lib.listToAttrs (
      map (nixosCfg: let
          err = "${myHostName} dials from ${dialFromHostName}, but ${dialFromHostName} does not enable garnix.wireguard";
          myHostName = config.networking.hostName;
          dialFromHostName = nixosCfg.config.networking.hostName;
          dialFromHostCfg = nixosCfg.config.garnix.wireguard or (throw err);
        in
          if dialFromHostCfg.enable then
            { name = dialFromHostName; value = dialFromHostCfg; }
          else throw err
      ) cfg.dialsFrom
    );
  in lib.mkIf cfg.enable {
    # Set up /etc/hosts file to dial to other peers
    networking.hosts = lib.mapAttrs' (hostName: { ip, ... }: {
      name = ip;
      value = [ hostName ];
    }) dialsToCfgs;

    # garnix will fail a deploy if systemd units fail, but nixos wireguard
    # units rely on retry to reconnect until successful. However, on a fresh
    # deploy, the domain won't be available immediately. This causes the deploy
    # to fail. So to fix this, we wait to start the unit until the domain
    # resolves.
    #
    # TODO: we want to swap this out to use the hash-domains, but at the moment
    # they are made available only *after* the full deploy finishes, we need to
    # update them to become available as soon as the host is fully deployed.
    systemd.services = lib.mapAttrs' (hostName: { endpoint, ... }: {
      name = "wireguard-wg0-peer-${hostName}-refresh";
      value.preStart = lib.getExe (pkgs.writeShellApplication {
        name = "wait-for-dns";
        runtimeInputs = [ pkgs.host ];
        text = ''
          DOMAIN=${lib.escapeShellArg endpoint}
          while ! host -t A "$DOMAIN"; do
            echo "Waiting for $DOMAIN..."
            sleep 5
          done
        '';
      });
    }) dialsToCfgs;

    networking.firewall.allowedUDPPorts = [ cfg.port ];
    networking.wireguard.interfaces.wg0 = {
      ips = [ "${cfg.ip}/24" ];
      listenPort = cfg.port;
      privateKeyFile = cfg.privateKeyFile;
      peers =
        # outbound connections
        lib.mapAttrsToList (name: { endpoint, publicKey, ip, port, ... }: {
          inherit name publicKey;
          allowedIPs = [ "${ip}/32" ];
          dynamicEndpointRefreshSeconds = 30;
          endpoint = "${endpoint}:${toString port}";
        }) dialsToCfgs
        ++
        # inbound connections
        lib.mapAttrsToList (name: { publicKey, ip, ... }: {
          inherit name publicKey;
          allowedIPs = [ "${ip}/32" ];
        }) dialsFromCfgs;
    };
  };
}
