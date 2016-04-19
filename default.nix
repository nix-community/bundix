with (import <nixpkgs> {});
let
  bundix = stdenv.mkDerivation {
    name = "bundix";
    src = ./.;
    phases = "installPhase";
    installPhase = ''
      cp -r $src $out
    '';
    propagatedBuildInputs = [ruby];
  };
in stdenv.mkDerivation {
  name = "bundix";
  buildInputs = [bundler bundix];
}
