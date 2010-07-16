require 'spec_helper'

describe "ey keys list" do
  given "integration"

  def command_to_run(options)
    cmd = "keys list"
    cmd << " --environment #{options[:env]}" if options[:env]
    cmd
  end

  def verify_ran(scenario)
    @out.should match(/#{scenario[:environment]}/) if scenario[:environment]
  end

  # common behavior
  it_should_behave_like "it takes an environment name"
end
