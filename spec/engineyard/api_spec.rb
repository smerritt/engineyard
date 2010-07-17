require 'spec_helper'

describe EY::API do
  it "gets the api token from ~/.eyrc if possible" do
    write_yaml({"api_token" => "asdf"}, '~/.eyrc')
    EY::API.new.should == EY::API.new("asdf")
  end

  context "fetching the token from EY cloud" do
    before(:each) do
      FakeWeb.register_uri(:post, "https://cloud.engineyard.com/api/v2/authenticate", :body => %|{"api_token": "asdf"}|, :content_type => 'application/json')
      @token = EY::API.fetch_token("a@b.com", "foo")
    end

    it "returns an EY::API" do
      @token.should == "asdf"
    end

    it "puts the api token into .eyrc" do
      read_yaml('~/.eyrc')["api_token"].should == "asdf"
    end
  end

  describe "saving the token" do
    context "without a custom endpoint" do
      it "saves the api token at the root of the data" do
        EY::API.save_token("asdf")
        read_yaml('~/.eyrc')["api_token"].should == "asdf"
      end
    end

    context "with a custom endpoint" do
      before(:each) do
        write_yaml({"endpoint" => "http://localhost/"}, 'ey.yml')
        EY::API.save_token("asdf")
      end

      it "saves the api token" do
        read_yaml('~/.eyrc').should == {"http://localhost/" => {"api_token" => "asdf"}}
      end

      it "reads the api token" do
        EY::API.read_token.should == "asdf"
      end
    end
  end

  it "raises InvalidCredentials when the credentials are invalid" do
    FakeWeb.register_uri(:post, "https://cloud.engineyard.com/api/v2/authenticate", :status => 401, :content_type => 'application/json')

    lambda {
      EY::API.fetch_token("a@b.com", "foo")
    }.should raise_error(EY::Error)
  end
end

describe EY::API do
  given "integration"

  before(:all) do
    @api = EY::API.new('deadbeef')
  end

  describe "#create_key" do
    before do
      @key_attributes = {
        "name" => 'id_dsa.pub',
        "public_key" => "ssh-dss AAAAB3NzaC1kc3MAAACBAOpTvNnhAZzl/LT7L2Oj2EQ3I4JMP0cwSwu+80zrNiWpChXcyIbLHDBQ76Vc2mFj4zNkV2s9WPSWZ4Pwbuq6FxfldI1tXJkRNFBJxnV8T3Wzxv/lCDXObveArhlMjlUw84juTFv5oQwE1Z3dPYTsytoKKeRlJLtNCic2Trjj6D97AAAAFQDLwRE+7tOTWha2rG5f036+6pYsNwAAAIBXsaU2a606eQxfwWojwiPui3eEM/1OAxOf09Ol1BhaSOSbVgjKrCN6ALfU+vE99oMSTXh1+xYlVXjm/1uyoQTZcj/Tn6r3nsnpdSy4BZHK7GmdLGGXG1SvOPRZShDlKvTKbRbaLojFMJlBWcquWexRrk2RqqtczSOeizESgpEI5AAAAIEApLlM2Hhw49hwydqKIU0yYh3gx30/fgjckwnS21n35sMnFvRIKY83PKBatr3q6t+DWP+b5BAlMDpq4yAl6wR/2x6+NnFqrCliqfXBnSOPqhejaGoGK1CWDcMBT5pOGFtce+QuhvuEn6oZQJID4pGIPL6bMBV22fKFLH38gQwS61c= spam@octavius"
      }
    end

    it "returns a Key model" do
      key = @api.create_key(@key_attributes)
      key.should be_kind_of(EY::Model::Key)
    end

    it "tells cloud about the keypair" do
      lambda { @api.create_key(@key_attributes) }.should change {
        EY::API.new('deadbeef').keys.size
      }.by(1)
    end

    it "doesn't have any stale cache" do
      old_keys = @api.keys    # prime any caches
      @api.create_key(@key_attributes)
      new_keys = @api.keys

      new_keys.size.should_not == old_keys.size
    end

  end
end
