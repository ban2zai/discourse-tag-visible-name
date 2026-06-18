# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::DiscourseTagVisibleName::TagVisibleNameStore do
  fab!(:tag) { Fabricate(:tag, name: "бгу") }
  fab!(:uppercase_tag) { Fabricate(:tag, name: "Техно") }
  fab!(:tag_group) { Fabricate(:tag_group, name: "Участки", tag_names: [tag.name]) }
  fab!(:consulting_group) do
    Fabricate(:tag_group, name: "Консультирование", tag_names: [uppercase_tag.name])
  end
  fab!(:areas_group) { Fabricate(:tag_group, name: "Участки 2", tag_names: [uppercase_tag.name]) }
  fab!(:ungrouped_tag) { Fabricate(:tag, name: "без-группы") }

  before { SiteSetting.tag_visible_name_enabled = true }

  describe ".save!" do
    it "trims and stores visible names" do
      described_class.save!(tag, " БГУ ")

      expect(described_class.mapping).to eq("бгу" => "БГУ")
    end

    it "stores visible names by lowercase tag keys" do
      described_class.save!(uppercase_tag, " Техно ")

      expect(described_class.mapping).to include("техно" => "Техно")
      expect(described_class.visible_name_for(uppercase_tag)).to eq("Техно")
    end

    it "deletes custom fields for blank values" do
      described_class.save!(tag, "БГУ")
      described_class.save!(tag, "")

      expect(described_class.mapping).to eq({})
    end
  end

  describe ".import_mapping!" do
    it "imports existing tags and skips unknown tags" do
      result =
        described_class.import_mapping!(
          {
            "бгу" => "БГУ",
            "нет-такого-тега" => "Нет такого тега",
          },
        )

      expect(result[:imported]).to eq(["бгу"])
      expect(result[:skipped]).to eq(["нет-такого-тега"])
      expect(described_class.mapping).to eq("бгу" => "БГУ")
    end

    it "imports tags case-insensitively" do
      result = described_class.import_mapping!("техно" => "Техно")

      expect(result[:imported]).to eq(["техно"])
      expect(result[:skipped]).to eq([])
      expect(described_class.visible_name_for(uppercase_tag)).to eq("Техно")
    end
  end

  describe ".parse_mapping" do
    it "parses YAML objects" do
      expect(described_class.parse_mapping("бгу: БГУ", "yaml")).to eq(
        "бгу" => "БГУ",
      )
    end

    it "parses JSON objects" do
      expect(described_class.parse_mapping({ "бгу" => "БГУ" }.to_json, "json")).to eq(
        "бгу" => "БГУ",
      )
    end

    it "rejects non-object payloads" do
      expect { described_class.parse_mapping(["бгу"].to_json, "json") }.to raise_error(
        ArgumentError,
      )
    end

    it "rejects unknown formats" do
      expect { described_class.parse_mapping("бгу: БГУ", "txt") }.to raise_error(
        ArgumentError,
      )
    end
  end

  describe ".save_all!" do
    it "keeps visible names compatible with the existing store key" do
      described_class.save_all!(
        tags: [{ id: tag.id, visible_name: " БГУ " }],
        tag_group_styles: {},
        tag_styles: {},
      )

      expect(described_class.mapping).to eq("бгу" => "БГУ")
    end

    it "stores group and tag style settings" do
      described_class.save_all!(
        tags: [],
        tag_group_styles: { tag_group.id => "area" },
        tag_styles: { uppercase_tag.name => "section" },
      )

      expect(described_class.style_mapping).to eq(
        "tag_group_styles" => { tag_group.id.to_s => "area" },
        "tag_styles" => { "техно" => "section" },
      )
    end
  end

  describe ".grouped_tags" do
    it "uses tag style overrides before group styles" do
      described_class.save_all!(
        tags: [],
        tag_group_styles: { tag_group.id => "area" },
        tag_styles: { tag.name => "section" },
      )

      grouped_tag =
        described_class
          .grouped_tags
          .fetch(:tag_groups)
          .find { |group| group[:id] == tag_group.id }
          .fetch(:tags)
          .find { |item| item[:id] == tag.id }

      expect(grouped_tag[:effective_style]).to eq("section")
    end

    it "uses group styles when tag override is inherited" do
      described_class.save_all!(
        tags: [],
        tag_group_styles: { tag_group.id => "area" },
        tag_styles: { tag.name => "inherit" },
      )

      grouped_tag =
        described_class
          .grouped_tags
          .fetch(:tag_groups)
          .find { |group| group[:id] == tag_group.id }
          .fetch(:tags)
          .find { |item| item[:id] == tag.id }

      expect(grouped_tag[:effective_style]).to eq("area")
    end

    it "uses default style for ungrouped tags without overrides" do
      ungrouped =
        described_class
          .grouped_tags
          .dig(:ungrouped_tags)
          .find { |item| item[:id] == ungrouped_tag.id }

      expect(ungrouped[:effective_style]).to eq("default")
    end

    it "shows tags in every tag group membership" do
      groups_with_tag =
        described_class
          .grouped_tags
          .fetch(:tag_groups)
          .select do |group|
            group.fetch(:tags).any? { |item| item[:id] == uppercase_tag.id }
          end

      expect(groups_with_tag.map { |group| group[:name] }).to contain_exactly(
        "Консультирование",
        "Участки 2",
      )
    end

    it "excludes grouped tags from ungrouped tags" do
      ungrouped_ids =
        described_class.grouped_tags.fetch(:ungrouped_tags).map { |item| item[:id] }

      expect(ungrouped_ids).to include(ungrouped_tag.id)
      expect(ungrouped_ids).not_to include(uppercase_tag.id)
    end

    it "uses area group styles before section group styles for public styles" do
      described_class.save_all!(
        tags: [],
        tag_group_styles: {
          consulting_group.id => "section",
          areas_group.id => "area",
        },
        tag_styles: {},
      )

      expect(described_class.public_style_mapping["техно"]).to eq("area")
    end
  end
end
