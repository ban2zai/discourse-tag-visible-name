# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tag visible names in tags API" do
  fab!(:tag) { Fabricate(:tag, name: "Техно") }
  fab!(:plain_tag) { Fabricate(:tag, name: "обычный-тег") }
  fab!(:tag_group) do
    Fabricate(:tag_group, name: "API tags", tag_names: [tag.name, plain_tag.name])
  end

  before do
    SiteSetting.tagging_enabled = true if SiteSetting.respond_to?(:tagging_enabled=)
    SiteSetting.tag_visible_name_enabled = true

    ::DiscourseTagVisibleName::TagVisibleNameStore.save!(tag, "Красивое техно")
    ::DiscourseTagVisibleName::TagVisibleNameStore.save_all!(
      tags: [{ id: tag.id, style: "area" }],
    )

    if ::Tag.column_names.include?("topic_count")
      tag.update_column(:topic_count, 1)
      plain_tag.update_column(:topic_count, 1)
    elsif ::Tag.column_names.include?("public_topic_count")
      tag.update_column(:public_topic_count, 1)
      plain_tag.update_column(:public_topic_count, 1)
    end
  end

  it "adds visible fields without replacing tag slug fields" do
    get "/tags.json"

    expect(response.status).to eq(200)

    tags = serialized_tags(response.parsed_body)
    serialized_tag = find_serialized_tag(tags, tag.name)
    serialized_plain_tag =
      find_serialized_tag(tags, plain_tag.name)

    expect(serialized_tag).to be_present
    expect(serialized_tag["visible_name"]).to eq("Красивое техно")
    expect(serialized_tag["visible_style"]).to eq("area")
    expect(serialized_tag["id"]).not_to eq("Красивое техно") if serialized_tag.key?("id")
    expect(serialized_tag["name"]).not_to eq("Красивое техно") if serialized_tag.key?("name")
    expect(serialized_tag["text"]).not_to eq("Красивое техно") if serialized_tag.key?("text")

    expect(serialized_plain_tag).to be_present
    expect(serialized_plain_tag["visible_name"]).to be_nil
    expect(serialized_plain_tag["visible_style"]).to eq("default")
  end

  it "does not include visible fields when plugin setting is disabled" do
    SiteSetting.tag_visible_name_enabled = false

    get "/tags.json"

    expect(response.status).to eq(200)

    tags = serialized_tags(response.parsed_body)
    serialized_tag = find_serialized_tag(tags, tag.name)

    expect(serialized_tag).to be_present
    expect(serialized_tag).not_to have_key("visible_name")
    expect(serialized_tag).not_to have_key("visible_style")
  end

  def find_serialized_tag(tags, name)
    key = name.downcase

    tags.find do |item|
      [item["id"], item["name"], item["text"]]
        .compact
        .map { |value| value.to_s.downcase }
        .include?(key)
    end
  end

  def serialized_tags(payload)
    Array(payload["tags"]) +
      Array(payload.dig("extras", "tag_groups")).flat_map do |tag_group|
        Array(tag_group["tags"])
      end
  end
end
