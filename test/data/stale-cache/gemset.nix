{
  bundler-audit = {
    dependencies = [ "thor" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "cached_bundler_audit_hash";
      type = "gem";
    };
    version = "0.5.0";
  };
  thor = {
    groups = [ "test" ];
    platforms = [ { engine = "jruby"; } ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "cached_thor_hash";
      type = "gem";
    };
    version = "0.19.4";
  };
}
