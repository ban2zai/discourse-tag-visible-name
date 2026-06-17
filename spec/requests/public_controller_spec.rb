# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tag visible names public API" do
  fab!(:tag) { Fabricate(:tag, name: "бгу") }

  before { SiteSetting.tag_visible_name_enabled = true }

  describe "GET /tag-visible-names" do
    it "returns visible name and style mappings" do
      ::DiscourseTagVisibleName::TagVisibleNameStore.save!(tag, "БГУ")
      ::DiscourseTagVisibleName::TagVisibleNameStore.save_all!(
        tags: [],
        tag_group_styles: {},
        tag_styles: {
          tag.name => "area",
        },
      )

      get "/tag-visible-names.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["tag_visible_names"]).to eq("бгу" => "БГУ")
      expect(response.parsed_body["tag_styles"]).to eq("бгу" => "area")
    end
  end
end
