{ pkgs ? (import <nixpkgs> {})
, ruby ? pkgs.ruby_2_6
, bundler ? (pkgs.bundler.override { inherit ruby; })
, nix ? pkgs.nix
, nix-prefetch-git ? pkgs.nix-prefetch-git
, rake ? pkgs.rubyPackages.rake
, minitest ? pkgs.rubyPackages.minitest
, nix-prefetch-scripts ? pkgs.nix-prefetch-scripts
}:
let
 srcWithout = rootPath: ignoredPaths:
   let
     ignoreStrings = map (path: toString path ) ignoredPaths;
   in
    builtins.filterSource (path: type: (builtins.all (i: i != path) ignoreStrings)) rootPath;
in pkgs.stdenv.mkDerivation rec {
  version = "2.5.0";
  name = "bundix";
  src = srcWithout ./. [ ./.git ./tmp ./result ];
  installPhase = ''
    mkdir -p $out
    makeWrapper $src/bin/bundix $out/bin/bundix \
      --prefix PATH : "${nix.out}/bin" \
      --prefix PATH : "${nix-prefetch-git.out}/bin" \
      --prefix PATH : "${bundler.out}/bin" \
      --set GEM_PATH "${bundler}/${bundler.ruby.gemPath}"
  '';

  nativeBuildInputs = [ pkgs.makeWrapper ];
  buildInputs = [ ruby bundler ];

  checkInputs = [
    rake
    minitest

    nix-prefetch-scripts
    nix
  ];

  doCheck = true;
  checkPhase = ''
    NIX_STATE_DIR=$TMPDIR/var HOME=$TMPDIR rake test
  '';

  meta = {
    inherit version;
    description = "Creates Nix packages from Gemfiles";
    longDescription = ''
      This is a tool that converts Gemfile.lock files to nix expressions.

      The output is then usable by the bundlerEnv derivation to list all the
      dependencies of a ruby package.
    '';
    homepage = "https://github.com/manveru/bundix";
    license = "MIT";
    maintainers = with pkgs.lib.maintainers; [ manveru zimbatm ];
    platforms = pkgs.lib.platforms.all;
  };
}
