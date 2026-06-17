# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tag visible names public API" do
  fab!(:tag) { Fabricate(:tag, name: "бгу") }

  before { SiteSetting.tag_visible_name_enabled = true }

  describe "GET /tag-visible-names" do
    it "returns visible name mapping" do
      ::DiscourseTagVisibleName::TagVisibleNameStore.save!(tag, "БГУ")

      get "/tag-visible-names.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["tag_visible_names"]).to eq("бгу" => "БГУ")
    end
  end
end
