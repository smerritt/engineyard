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

end
