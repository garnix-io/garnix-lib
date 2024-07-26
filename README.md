# garnix-lib

Nix helpers for `garnix` users


## `lib.getHashSubdomain`

*Type*: `nixosConfiguration` -> `string`

Gets the domain for a `nixosConfiguration` deployed with garnix (*without* persistence enabled). Use this to communicate between machines.

## nixosModules.garnix

Type: module

Sets necessary parameters for a server deployed with garnix, and provides
options for persistence. To use it, you must set `garnix.enable = true` (and,
if desired, `garnix.persistence.enable = true`) in addition to importing it.
