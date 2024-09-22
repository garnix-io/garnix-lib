<a href="https://garnix.io/repo/garnix-io/garnix-lib"><img alt="built with garnix" src="https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fgarnix.io%2Fapi%2Fbadges%2Fgarnix-io%2Fgarnix-lib"></a>

# garnix-lib

Nix helpers for `garnix` users


## `lib.getHashSubdomain`

*Type*: `nixosConfiguration` -> `string`

Gets the domain for a `nixosConfiguration` deployed with garnix (*without* persistence enabled). Use this to communicate between machines.

## nixosModules.garnix

Type: module

Sets necessary parameters for a server deployed with garnix. To use it, import the module into your nix configuration, then set `garnix.server.enable` to `true`.

Additionally provides the `garnix.server.persistence` option.
