require 'spec_helper'

describe EY::Model::Key do
  given "it has an api"

  context "#environments" do
    before do
      @key = described_class.from_hash("id" => 12345, :api => @api)

      FakeWeb.register_uri(
        :get,
        "https://cloud.engineyard.com/api/v2/keypairs/#{@key.id}/environments",
        :content_type => 'application/json',
        :body => {
          "environments" => [{
              "id" => 222,
              "name" => "production",
            }, {
              "id" => 333,
              "name" => "staging",
            }]
          }.to_json
        )
    end

    it "returns the key's environments" do
      @key.environments.size.should == 2
      @key.environments.map {|e| e.id}.sort.should == [222, 333]
    end

    it "returns a smart collection, not a dumb array" do
      @key.environments.match_one('prod').should_not be_nil
    end
  end

  context "#associate" do
    before do
      @key = described_class.from_hash("id" => 1122, :api => @api)
      @environment = EY::Model::Environment.from_hash("id" => 3344, :api => @api)

      FakeWeb.register_uri(
        :put,
        "https://cloud.engineyard.com/api/v2/environments/#{@environment.id}/keypairs/#{@key.id}",
        :body => '',
        :status => 204,
        :content_type => 'application/json'
        )
    end

    it "links the key with the environment" do
      @key.associate(@environment)

      FakeWeb.should have_requested(:put,
        "https://cloud.engineyard.com/api/v2/environments/3344/keypairs/1122")
    end

    it "invalidates any caches laying around" do
      FakeWeb.register_uri(
        :get,
        "https://cloud.engineyard.com/api/v2/keypairs/#{@key.id}/environments",
        :content_type => 'application/json',
        :body => {"environments" => []}.to_json
        )

      @key.environments.should == []
      @key.associate(@environment)

      FakeWeb.register_uri(
        :get,
        "https://cloud.engineyard.com/api/v2/keypairs/#{@key.id}/environments",
        :content_type => 'application/json',
        :body => {"environments" => [{"id" => @environment.id}]}.to_json
        )
      @key.environments.should == [@environment]
    end
  end

end
