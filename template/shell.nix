with (import <nixpkgs> {});
let
  env = bundlerEnv {
    name = "<%= project %>-bundler-env";
    inherit <%= ruby %>;
    gemfile  = <%= gemfile_path %>;
    lockfile = <%= lockfile_path %>;
    gemset   = <%= gemset_path %>;
  };
in stdenv.mkDerivation {
  name = "<%= project %>";
  buildInputs = [ env ];
}
