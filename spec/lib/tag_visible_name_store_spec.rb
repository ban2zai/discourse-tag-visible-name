# frozen_string_literal: true

require "rails_helper"

RSpec.describe ::DiscourseTagVisibleName::TagVisibleNameStore do
  fab!(:tag) { Fabricate(:tag, name: "бгу") }

  before { SiteSetting.tag_visible_name_enabled = true }

  describe ".save!" do
    it "trims and stores visible names" do
      described_class.save!(tag, " БГУ ")

      expect(described_class.mapping).to eq("бгу" => "БГУ")
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
  end
end
