# About

Bundix is a tool that bridges the gap between [Bundler](http://bundler.io/) (the
Ruby dependency manager) and [Nix](http://nixos.org/nix/) (the package manager
and build system). It does this by automating the generation of Nix expressions
for each Ruby gem in `Gemfile.lock`.

The end result is that Gems will load from `/nix/store/...` in a declarative
manner, rather then from wherever `bundle install` may have put them.

## Installation

Installing from this repo:

    nix-env -iA bundix

Please note that in order to actually use this gem you must have Nix installed.

## Basic Usage

I recommend first reading the
[nixpkgs manual entry for Ruby](http://nixos.org/nixpkgs/manual/#sec-language-ruby)
as this README might become outdated, it's a short read right now, so you won't
regret it.

1. Making a gemset.nix

   Change to your project's directory and run this:

       bundix -l

   This will generate a `gemset.nix` file that you then can use in your
   `bundlerEnv` expression like this:

2. Using `nix-shell`

   To try your package in `nix-shell`, create a `default.nix` like this:

   ```nix
   with (import <nixpkgs> {});
   let
     gems = bundlerEnv {
       name = "your-package";
       inherit ruby;
       gemdir = ./.;
     };
   in stdenv.mkDerivation {
     name = "your-package";
     buildInputs = [gems ruby];
   }
   ```

   and then simply run `nix-shell`.

3. Proper packages

   To make a package for nixpkgs, you can try something like this:

   ```nix
   { stdenv, bundlerEnv, ruby }:
   let
     gems = bundlerEnv {
       name = "your-package";
       inherit ruby;
       gemdir  = ./.;
     };
   in stdenv.mkDerivation {
     name = "your-package";
     src = ./.;
     buildInputs = [gems ruby];
     installPhase = ''
       mkdir -p $out
       cp -r $src $out
     '';
   }
   ```

## How & Why

I'd usually just tell you to read the code yourself, but the big picture is
that bundix tries to fetch a hash for each of your bundle dependencies and
store them all together in a format that Nix can understand and is then used by
`bundlerEnv`.

I wrote this new version of bundix because I became frustrated with the poor
performance of the old bundix, and wanted to save both time and bandwidth, as
well as learn more about Nix.

For each gem, it first tries to look for an existing gem in the bundler cache
(usually generated via `bundle package`), and if that fails it goes through
each remote and tries to fetch the gem from there. If the remote happens to be
[rubygems.org](http://rubygems.org/) we ask the API first for a hash of the
gem, and then ask the Nix store whether we have this version already. Only if
that also fails do we download the gem.

As an added bonus I also implemented parsing the `gemset.nix` if it already
exists, and get hashes from there directly, that way updating an existing
`gemset.nix` only takes a few seconds.

The output from bundix should be as stable as possible, to make auditing diffs
easier, that's why I also implemented a pretty printer for the `gemset.nix`.

I hope you enjoy using bundix as much as I do, and if you don't, let me know.

## Closing words

For any questions or suggestions, please file an issue on Github or ask in
`#nixos` on [Freenode](http://freenode.net/).

Big thanks go out to
[Charles Strahan](http://www.cstrahan.com/) for his awesome work bringing Ruby to Nix,
[zimbatm](https://zimbatm.com/) for being a good rubber duck and tester, and
[Alexander Flatter](https://github.com/aflatter) for the original bundix. I
couldn't have done this without you guys.
