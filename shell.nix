with import <nixpkgs> { };
let
  inherit (lib) all;
  inherit (builtins) filterSource;

  gems = bundlerEnv {
    ruby = ruby_2_6;
    name = "bundix-gems";
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };

in mkShell {
  buildInputs = [
    gems.wrappedRuby
    gems
    nix-prefetch-scripts
  ];

  TERM = "xterm";
}
