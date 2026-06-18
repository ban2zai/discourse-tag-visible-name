# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tag visible names tags mapping API" do
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

  it "copies tags.json and adds visible fields without replacing tag slug fields" do
    get "/tags.json"

    expect(response.status).to eq(200)

    core_payload = response.parsed_body

    get "/tags_mapping_name.json"

    expect(response.status).to eq(200)
    expect(strip_visible_fields(response.parsed_body)).to eq(core_payload)

    tags = serialized_tags(response.parsed_body)
    serialized_tag = find_serialized_tag(tags, tag.name)
    serialized_plain_tag = find_serialized_tag(tags, plain_tag.name)

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

  it "is available to anonymous users" do
    get "/tags_mapping_name.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to include("tags", "extras")
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

  def strip_visible_fields(value)
    case value
    when Array
      value.map { |item| strip_visible_fields(item) }
    when Hash
      value
        .except("visible_name", "visible_style")
        .transform_values { |item| strip_visible_fields(item) }
    else
      value
    end
  end
end
