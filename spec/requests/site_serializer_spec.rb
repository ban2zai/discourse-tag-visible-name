# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tag visible names site serializer" do
  fab!(:tag) { Fabricate(:tag, name: "tech") }

  before { SiteSetting.tag_visible_name_enabled = true }

  it "serializes visible name and style mappings for the frontend boot payload" do
    ::DiscourseTagVisibleName::TagVisibleNameStore.save!(tag, "Technology")
    ::DiscourseTagVisibleName::TagVisibleNameStore.save_all!(
      tags: [{ id: tag.id, style: "area" }],
    )

    get "/site.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["tag_visible_names"]).to eq("tech" => "Technology")
    expect(response.parsed_body["tag_visible_styles"]).to eq("tech" => "area")
  end

  it "serializes empty mappings when the plugin setting is disabled" do
    ::DiscourseTagVisibleName::TagVisibleNameStore.save!(tag, "Technology")
    ::DiscourseTagVisibleName::TagVisibleNameStore.save_all!(
      tags: [{ id: tag.id, style: "area" }],
    )
    SiteSetting.tag_visible_name_enabled = false

    get "/site.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["tag_visible_names"]).to eq({})
    expect(response.parsed_body["tag_visible_styles"]).to eq({})
  end
end
