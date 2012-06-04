require 'spec_helper'

describe "Resque::Plugins::Approval" do
  it "is a valid Resque plugin" do
    lambda { Resque::Plugin.lint(Resque::Plugins::Approval) }.should_not raise_error
  end
end
