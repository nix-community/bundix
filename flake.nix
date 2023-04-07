{
  description = "Bundix makes it easy to package your Bundler-enabled Ruby applications with the Nix package manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        packages = {
          default = import ./default.nix {
            inherit pkgs;

            # The ruby_2_7 attribute is used here because the ruby_2_6 attribute used in
            # default.nix is no longer available in more recent versions of Nixpkgs
            ruby = pkgs.ruby_2_7;
          };
        };
      }
    );
}