# About

Bundix makes it easy to package your [Bundler](http://bundler.io/)-enabled Ruby
applications with the [Nix](http://nixos.org/nix/) package manager.

This is a fork of the official [bundix](https://github.com/nix-community/bundix), used by [ruby-nix](https://github.com/sagittaros/ruby-nix).

## How & Why

"I'd usually just tell you to read the code yourself, but the big picture is
that bundix tries to fetch a hash for each of your bundle dependencies and
store them all together in a format that Nix can understand"

## Closing words

For any questions or suggestions, please file an issue on Github or ask in
`#nixos` on [Freenode](http://freenode.net/).

Big thanks go out to
[Charles Strahan](http://www.cstrahan.com/) for his awesome work bringing Ruby to Nix,
[zimbatm](https://zimbatm.com/) for being a good rubber duck and tester, and
[Alexander Flatter](https://github.com/aflatter) for the original bundix. I
couldn't have done this without you guys.
