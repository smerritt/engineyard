require 'spec_helper'

describe "ey help" do
  # help topics are going to be:
  #
  # ey.yml
  # environment variables
  # maintenance pages
  # deploy hook API ?

  it "includes extra help topics" do
    ey "help"
    @out.should include("ey.yml")
  end

  it "shows the help for a particular topic" do
    ey "help ey.yml"
    # yes, testing text is lame, but the whole point of this is to
    # display a bunch of text, so what else can we do?
    @out.should include("Customizing deploys with ey.yml")
  end
end
