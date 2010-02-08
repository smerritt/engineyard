require 'spec_helper'
require 'cli'

describe EY::CLI::Environments do
  context "with a valid token" do
    before(:each) do
      File.open(File.expand_path("~/.eyrc"), "w") do |fp|
        fp.write(YAML.dump({"api_token" => "asdf"}))
      end
      app_json = JSON.dump({"apps" => [{
        "name" => "engineyard",
        "repository_uri" => "git://github.com/foo/bar",
        "environments" => [{
          "name" => "engineyard_production",
          "app_master" => {"status" => "running", "ip_address" => "174.129.254.251"},
          "instances_count" => 1
        }, {
          "name" => "engineyard_staging",
          "app_master" => {"status" => "running", "ip_address" => "174.129.254.252"},
          "instances_count" => 3
        }]
      }]})
      FakeWeb.register_uri(
        :get, "https://cloud.engineyard.com/api/v2/apps",
        :body => app_json)
      EY::CLI::Environments.stub!(:repo_url).and_return("git://github.com/foo/bar")
    end

    it "prints the environments on the commmand line" do
      out = capture_stdout do
        EY::CLI::Environments.run(nil)
      end

      out.should include("engineyard_staging, 3 instances")
      out.should include("engineyard_production, 1 instance")
    end
  end

end