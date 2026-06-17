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
        rows =
          ::DB.query_hash(
            <<~SQL,
              SELECT tags.name AS tag_name, tag_custom_fields.value
              FROM tag_custom_fields
              INNER JOIN tags ON tags.id = tag_custom_fields.tag_id
              WHERE tag_custom_fields.name = :field_name
                AND tag_custom_fields.value IS NOT NULL
                AND tag_custom_fields.value <> ''
            SQL
            field_name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME,
          )

        rows.to_h { |row| [row["tag_name"], row["value"]] }
      end

      def visible_name_for(tag)
        return if tag.blank?

        ::DB
          .query_single(
            <<~SQL,
              SELECT value
              FROM tag_custom_fields
              WHERE tag_id = :tag_id
                AND name = :field_name
              LIMIT 1
            SQL
            tag_id: tag.id,
            field_name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME,
          )
          .first
          .presence
      end

      def save!(tag, visible_name)
        value = visible_name.to_s.strip

        ::DB.exec(
          <<~SQL,
            DELETE FROM tag_custom_fields
            WHERE tag_id = :tag_id
              AND name = :field_name
          SQL
          tag_id: tag.id,
          field_name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME,
        )

        if value.blank?
          return nil
        end

        ::DB.exec(
          <<~SQL,
            INSERT INTO tag_custom_fields (tag_id, name, value, created_at, updated_at)
            VALUES (:tag_id, :field_name, :value, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          SQL
          tag_id: tag.id,
          field_name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME,
          value: value,
        )

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

        rows =
          ::DB.query_hash(
            <<~SQL,
              SELECT tag_id, value
              FROM tag_custom_fields
              WHERE name = :field_name
                AND tag_id IN (:tag_ids)
                AND value IS NOT NULL
                AND value <> ''
            SQL
            field_name: ::DiscourseTagVisibleName::CUSTOM_FIELD_NAME,
            tag_ids: tag_ids,
          )

        rows.to_h { |row| [row["tag_id"], row["value"]] }
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
