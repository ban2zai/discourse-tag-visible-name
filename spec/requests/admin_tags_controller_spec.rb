# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tag visible names admin API" do
  fab!(:admin)
  fab!(:user)
  fab!(:tag) { Fabricate(:tag, name: "бгу") }
  fab!(:ungrouped_tag) { Fabricate(:tag, name: "без-группы") }
  fab!(:tag_group) { Fabricate(:tag_group, name: "Участки", tag_names: [tag.name]) }

  before do
    SiteSetting.tag_visible_name_enabled = true

    if ::Tag.column_names.include?("topic_count")
      tag.update_column(:topic_count, 2)
      ungrouped_tag.update_column(:topic_count, 1)
    elsif ::Tag.column_names.include?("public_topic_count")
      tag.update_column(:public_topic_count, 2)
      ungrouped_tag.update_column(:public_topic_count, 1)
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

    it "returns grouped tags for admins" do
      sign_in(admin)
      ::DiscourseTagVisibleName::TagVisibleNameStore.save!(tag, "БГУ")

      get "/admin/plugins/tag-visible-names/tags.json"

      expect(response.status).to eq(200)

      payload = response.parsed_body
      group = payload["tag_groups"].find { |item| item["id"] == tag_group.id }

      expect(payload["styles"]).to include(
        hash_including("id" => "default"),
        hash_including("id" => "area"),
        hash_including("id" => "section"),
      )
      expect(group).to include("name" => "Участки", "style" => "default")
      expect(group["tags"]).to include(
        hash_including(
          "id" => tag.id,
          "name" => "бгу",
          "visible_name" => "БГУ",
          "topic_count" => 2,
          "effective_style" => "default",
        ),
      )
      expect(payload["ungrouped_tags"]).to include(
        hash_including("id" => ungrouped_tag.id, "name" => "без-группы"),
      )
    end
  end

  describe "PUT /admin/plugins/tag-visible-names/tags" do
    it "rejects anonymous users" do
      put "/admin/plugins/tag-visible-names/tags.json",
          params: {
            tags: [{ id: tag.id, visible_name: "БГУ" }],
          }

      expect(response.status).to eq(403)
    end

    it "rejects regular users" do
      sign_in(user)

      put "/admin/plugins/tag-visible-names/tags.json",
          params: {
            tags: [{ id: tag.id, visible_name: "БГУ" }],
          }

      expect(response.status).to eq(403)
    end

    it "saves visible names and styles in bulk" do
      sign_in(admin)

      put "/admin/plugins/tag-visible-names/tags.json",
          params: {
            tag_group_styles: {
              tag_group.id => "area",
            },
            tag_styles: {
              tag.name => "section",
              ungrouped_tag.name => "area",
            },
            tags: [
              { id: tag.id, visible_name: " БГУ " },
              { id: ungrouped_tag.id, visible_name: " " },
            ],
          }

      expect(response.status).to eq(200)
      expect(::DiscourseTagVisibleName::TagVisibleNameStore.visible_name_for(tag)).to eq("БГУ")
      expect(::DiscourseTagVisibleName::TagVisibleNameStore.visible_name_for(ungrouped_tag)).to be_nil

      styles = ::DiscourseTagVisibleName::TagVisibleNameStore.style_mapping
      expect(styles["tag_group_styles"]).to include(tag_group.id.to_s => "area")
      expect(styles["tag_styles"]).to include(
        tag.name => "section",
        ungrouped_tag.name => "area",
      )
    end
  end
end
