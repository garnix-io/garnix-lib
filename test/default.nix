{ pkgs
, self
}:
pkgs.lib.debug.runTests {
  "the garnix persistence module" = {
    "throws an error if 'enable' is true but 'name' is not set" = {
      expr = "bar";
      expected = "foo";
    };
  };
}
