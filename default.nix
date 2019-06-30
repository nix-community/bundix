{ pkgs ? import <nixpkgs> { }
  , ruby ? pkgs.ruby_2_6
  , bundler ? (pkgs.bundler.override { inherit ruby; })
  , nix ? pkgs.nix
  , nix-prefetch-git ? pkgs.nix-prefetch-git
  , nix-prefetch-scripts ? pkgs.nix-prefetch-scripts
  , bundlerEnv ? pkgs.bundlerEnv
}:
let
  inherit (builtins) toString map readFile filterSource elemAt;
  inherit (pkgs.lib) all splitString;

  srcWithout = rootPath: ignoredPaths:
    let ignoreStrings = map (path: toString path) ignoredPaths;
    in filterSource (path: type: (all (i: i != path) ignoreStrings)) rootPath;

  version = let
    content = readFile ./lib/bundix/version.rb;
    parts = splitString "'" content;
    in elemAt parts 1;

  app = bundlerEnv {
    inherit ruby;
    name = "bundix-gems";
    gemdir = ./.;
  };
in
pkgs.stdenv.mkDerivation {
  version = "3.0.0";
  pname = "bundix";

  src = srcWithout ./. [ ./.git ./tmp ./result ];

  nativeBuildInputs = [ pkgs.makeWrapper ];
  buildInputs = [ app.wrappedRuby ];

  installPhase = ''
    cp -r $src $out
    chmod -R u+rw $out/bin
    wrapProgram $out/bin/bundix \
      --prefix PATH : "${nix}/bin" \
      --prefix PATH : "${nix-prefetch-scripts}/bin" \
      --prefix PATH : "${nix-prefetch-git}/bin" \
      --prefix PATH : "${app}/bin" \
      --set GEM_PATH "${app}/${app.ruby.gemPath}/gems"
  '';

  postFixup = ''
    $out/bin/bundix -v
  '';

  meta = with pkgs.lib; {
    inherit version;
    description = "Creates Nix packages from Gemfiles";
    longDescription = ''
      This is a tool that converts Gemfile.lock files to nix expressions.

      The output is then usable by the bundlerEnv derivation to list all the
      dependencies of a ruby package.
    '';
    homepage = "https://github.com/manveru/bundix";
    license = "MIT";
    maintainers = with maintainers; [ manveru zimbatm ];
    platforms = platforms.all;
  };
}
