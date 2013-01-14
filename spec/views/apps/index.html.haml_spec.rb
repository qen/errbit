require 'spec_helper'

describe "apps/index.html.haml" do
  before do
    deploy = Fabricate(:deploy, :created_at => Time.now, :revision => "123456789abcdef")
    app = Fabricate(:app_with_deploys, :deploys => [deploy])
    assign :apps, [app]
    controller.stub(:current_user) { stub_model(User) }
  end

  describe "deploy column" do
    it "should show the first 7 characters of the revision in parentheses" do
      render
      rendered.should match(/\(1234567\)/)
    end
  end
end

