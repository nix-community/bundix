# frozen_string_literal: true

__END__

require 'minitest/autorun'
require 'bundix'

class TestShellNixContext < Minitest::Test
  def test_commandline_populates_context
    @cli = Bundix::CommandLine.new
    context = @cli.shell_nix_context
    Bundix::ShellNixContext.members.each do |field|
      refute_nil(context[field], "#{field} was nil")
    end
  end
end
