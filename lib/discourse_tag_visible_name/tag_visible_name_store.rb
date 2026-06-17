# frozen_string_literal: true

require "json"
require "yaml"

module ::DiscourseTagVisibleName
  class TagVisibleNameStore
    class << self
      def list
        tags = ::Tag.order(:name).pluck(:id, :name, :topic_count)
        visible_names = visible_names_by_tag_id(tags.map(&:first))

        tags.map do |id, name, topic_count|
          {
            id: id,
            name: name,
            visible_name: visible_names[id],
            topic_count: topic_count || 0,
          }
        end
      end

      def mapping
        ::TagCustomField
          .joins("INNER JOIN tags ON tags.id = tag_custom_fields.tag_id")
          .where(name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME)
          .where.not(value: [nil, ""])
          .pluck("tags.name", "tag_custom_fields.value")
          .to_h
      end

      def visible_name_for(tag)
        return if tag.blank?

        ::TagCustomField.find_by(
          tag_id: tag.id,
          name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME,
        )&.value
      end

      def save!(tag, visible_name)
        value = visible_name.to_s.strip

        if value.blank?
          ::TagCustomField.where(
            tag_id: tag.id,
            name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME,
          ).delete_all
          tag.custom_fields.delete(::DiscourseTagVisibleName::CUSTOM_FIELD_NAME) if tag.respond_to?(:custom_fields)
          return nil
        end

        field =
          ::TagCustomField.find_or_initialize_by(
            tag_id: tag.id,
            name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME,
          )
        field.value = value
        field.save!
        tag.custom_fields[::DiscourseTagVisibleName::CUSTOM_FIELD_NAME] = value if tag.respond_to?(:custom_fields)
        value
      end

      def import_file!(path)
        mapping = read_mapping(path)
        import_mapping!(mapping)
      end

      def import_mapping!(mapping)
        imported = []
        skipped = []

        mapping.each do |name, visible_name|
          tag = ::Tag.find_by(name: name.to_s)

          if tag
            save!(tag, visible_name)
            imported << name.to_s
          else
            skipped << name.to_s
          end
        end

        { imported: imported, skipped: skipped }
      end

      private

      def visible_names_by_tag_id(tag_ids)
        return {} if tag_ids.blank?

        ::TagCustomField
          .where(tag_id: tag_ids, name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME)
          .where.not(value: [nil, ""])
          .pluck(:tag_id, :value)
          .to_h
      end

      def read_mapping(path)
        raise ArgumentError, "Не указан путь к файлу импорта" if path.blank?
        raise ArgumentError, "Файл импорта не найден: #{path}" if !File.exist?(path)

        content = File.read(path)
        data =
          if File.extname(path).downcase == ".json"
            JSON.parse(content)
          else
            YAML.safe_load(content, aliases: false)
          end

        raise ArgumentError, "Файл импорта должен содержать объект slug: visible_name" if !data.is_a?(Hash)

        data
      end
    end
  end
end
