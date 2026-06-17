# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tag visible names admin API" do
  fab!(:admin)
  fab!(:user)
  fab!(:tag) { Fabricate(:tag, name: "бгу") }

  before do
    SiteSetting.tag_visible_name_enabled = true

    if ::Tag.column_names.include?("topic_count")
      tag.update_column(:topic_count, 2)
    elsif ::Tag.column_names.include?("public_topic_count")
      tag.update_column(:public_topic_count, 2)
    end
  end

  describe "GET /admin/plugins/tag-visible-names/tags" do
    it "rejects anonymous users" do
      get "/admin/plugins/tag-visible-names/tags.json"

      expect(response.status).to eq(403)
    end

    it "rejects regular users" do
      sign_in(user)

      get "/admin/plugins/tag-visible-names/tags.json"

      expect(response.status).to eq(403)
    end

    it "returns tags for admins" do
      sign_in(admin)
      ::DiscourseTagVisibleName::TagVisibleNameStore.save!(tag, "БГУ")

      get "/admin/plugins/tag-visible-names/tags.json"

      expect(response.status).to eq(200)

      payload = response.parsed_body
      expect(payload["tags"]).to include(
        hash_including(
          "id" => tag.id,
          "name" => "бгу",
          "visible_name" => "БГУ",
          "topic_count" => 2,
        ),
      )
    end
  end

  describe "PUT /admin/plugins/tag-visible-names/tags/:id" do
    it "saves a visible name" do
      sign_in(admin)

      put "/admin/plugins/tag-visible-names/tags/#{tag.id}.json",
          params: {
            visible_name: " БГУ ",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("tag", "visible_name")).to eq("БГУ")
      expect(::DiscourseTagVisibleName::TagVisibleNameStore.visible_name_for(tag)).to eq("БГУ")
    end

    it "removes a visible name when value is blank" do
      sign_in(admin)
      ::DiscourseTagVisibleName::TagVisibleNameStore.save!(tag, "БГУ")

      put "/admin/plugins/tag-visible-names/tags/#{tag.id}.json",
          params: {
            visible_name: " ",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("tag", "visible_name")).to be_nil
      expect(::DiscourseTagVisibleName::TagVisibleNameStore.visible_name_for(tag)).to be_nil
    end
  end
end
