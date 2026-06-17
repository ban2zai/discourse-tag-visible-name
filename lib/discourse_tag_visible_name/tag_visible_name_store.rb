# frozen_string_literal: true

require "json"
require "yaml"

module ::DiscourseTagVisibleName
  class TagVisibleNameStore
    STORE_KEY = "visible_names"

    class << self
      def list
        count_column = topic_count_column
        columns = [:id, :name]
        columns << count_column if count_column

        tags = ::Tag.order(:name).pluck(*columns)
        visible_names = mapping

        tags.map do |row|
          id, name, topic_count = row

          {
            id: id,
            name: name,
            visible_name: visible_names[name],
            topic_count: topic_count || 0,
          }
        end
      end

      def mapping
        raw = ::PluginStore.get(::DiscourseTagVisibleName::PLUGIN_NAME, STORE_KEY)
        raw.is_a?(Hash) ? raw : {}
      end

      def topic_count_for(tag)
        if tag.respond_to?(:topic_count)
          tag.topic_count || 0
        elsif tag.respond_to?(:public_topic_count)
          tag.public_topic_count || 0
        else
          0
        end
      end

      def visible_name_for(tag)
        return if tag.blank?

        mapping[tag.name].presence
      end

      def save!(tag, visible_name)
        value = visible_name.to_s.strip
        visible_names = mapping.dup

        if value.blank?
          visible_names.delete(tag.name)
          save_mapping!(visible_names)
          return
        end

        visible_names[tag.name] = value
        save_mapping!(visible_names)
        value
      end

      def import_file!(path)
        mapping = read_mapping(path)
        import_mapping!(mapping)
      end

      def parse_mapping(content, format)
        data =
          case format.to_s.downcase
          when "json"
            JSON.parse(content.to_s)
          when "yaml", "yml"
            YAML.safe_load(content.to_s, aliases: false)
          else
            raise ArgumentError, "Неизвестный формат импорта: #{format}"
          end

        if !data.is_a?(Hash)
          raise ArgumentError,
                "Файл импорта должен содержать объект slug: visible_name"
        end

        data
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

      def topic_count_column
        columns = ::Tag.column_names

        if columns.include?("topic_count")
          :topic_count
        elsif columns.include?("public_topic_count")
          :public_topic_count
        end
      end

      def save_mapping!(visible_names)
        clean_mapping =
          visible_names.each_with_object({}) do |(name, visible_name), result|
            value = visible_name.to_s.strip
            result[name.to_s] = value if value.present?
          end

        ::PluginStore.set(
          ::DiscourseTagVisibleName::PLUGIN_NAME,
          STORE_KEY,
          clean_mapping,
        )
      end

      def read_mapping(path)
        raise ArgumentError, "Не указан путь к файлу импорта" if path.blank?
        raise ArgumentError, "Файл импорта не найден: #{path}" if !File.exist?(path)

        content = File.read(path)
        format = File.extname(path).downcase.delete_prefix(".")
        format = "yaml" if format.blank?

        parse_mapping(content, format)
      end
    end
  end
end
