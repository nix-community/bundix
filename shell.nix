with (import <nixpkgs> {});
let
  minitest = buildRubyGem {
    inherit ruby;
    gemName = "minitest";
    type = "gem";
    version = "5.10.1";
    source.sha256 = "1yk2m8sp0p5m1niawa3ncg157a4i0594cg7z91rzjxv963rzrwab";
    gemPath = [];
  };

  rake = buildRubyGem {
    inherit ruby;
    gemName = "rake";
    type = "gem";
    version = "12.0.0";
    source.sha256 = "01j8fc9bqjnrsxbppncai05h43315vmz9fwg28qdsgcjw9ck1d7n";
    gemPath = [];
  };
in
  stdenv.mkDerivation {
  name = "bundix";
  src = ./.;
  phases = "installPhase";
  installPhase = ''
    mkdir -p $out
    makeWrapper $src/bin/bundix $out/bin/bundix \
      --prefix PATH : "${nix.out}/bin" \
      --prefix PATH : "${nix-prefetch-git.out}/bin" \
      --set GEM_PATH "${bundler}/${bundler.ruby.gemPath}"
  '';

  nativeBuildInputs = [makeWrapper];

  buildInputs = [bundler ruby minitest rake nix-prefetch-scripts];
}
