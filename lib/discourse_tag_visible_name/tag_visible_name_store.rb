# frozen_string_literal: true

require "json"
require "set"
require "yaml"

module ::DiscourseTagVisibleName
  class TagVisibleNameStore
    STORE_KEY = "visible_names"
    STYLE_STORE_KEY = "styles"
    DEFAULT_STYLE = "default"
    STYLE_IDS = [DEFAULT_STYLE, "area", "section"].freeze

    class << self
      def list
        grouped_tags
      end

      def mapping
        raw = ::PluginStore.get(::DiscourseTagVisibleName::PLUGIN_NAME, STORE_KEY)
        raw.is_a?(Hash) ? raw : {}
      end

      def style_mapping
        raw =
          ::PluginStore.get(
            ::DiscourseTagVisibleName::PLUGIN_NAME,
            STYLE_STORE_KEY,
          )
        return { "tag_group_styles" => {}, "tag_styles" => {} } if !raw.is_a?(Hash)

        {
          "tag_group_styles" => normalize_style_hash(raw["tag_group_styles"]),
          "tag_styles" => normalize_style_hash(raw["tag_styles"]),
        }
      end

      def public_style_mapping
        grouped = grouped_tags
        styles = {}

        grouped[:tag_groups].each do |group|
          group[:tags].each { |tag| styles[tag[:name]] = tag[:effective_style] }
        end

        grouped[:ungrouped_tags].each do |tag|
          styles[tag[:name]] = tag[:effective_style]
        end

        styles
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

      def save_all!(tags:, tag_group_styles:, tag_styles:)
        tags = normalize_tag_params(tags)
        tag_by_id =
          ::Tag
            .where(id: tags.map { |tag| tag[:id] || tag["id"] })
            .index_by(&:id)
        visible_names = mapping.dup

        tags.each do |tag_params|
          tag = tag_by_id[(tag_params[:id] || tag_params["id"]).to_i]
          next if !tag

          value =
            (tag_params[:visible_name] || tag_params["visible_name"]).to_s.strip

          if value.blank?
            visible_names.delete(tag.name)
          else
            visible_names[tag.name] = value
          end
        end

        save_mapping!(visible_names)
        save_styles!(tag_group_styles, tag_styles)
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

      def styles
        [
          { id: DEFAULT_STYLE, name: "tag_visible_name.admin.styles.default" },
          { id: "area", name: "tag_visible_name.admin.styles.area" },
          { id: "section", name: "tag_visible_name.admin.styles.section" },
        ]
      end

      def grouped_tags
        visible_names = mapping
        style_settings = style_mapping
        tag_group_styles = style_settings["tag_group_styles"]
        tag_styles = style_settings["tag_styles"]
        tag_payloads = tag_payloads(visible_names, tag_styles)
        used_tag_ids = Set.new

        tag_groups =
          ::TagGroup
            .includes(:tags)
            .order(:name)
            .map do |tag_group|
              group_style =
                valid_style_id(tag_group_styles[tag_group.id.to_s]) ||
                  DEFAULT_STYLE
              tags =
                tag_group
                  .tags
                  .sort_by(&:name)
                  .filter_map do |tag|
                    next if used_tag_ids.include?(tag.id)

                    used_tag_ids << tag.id
                    payload = tag_payloads[tag.id]
                    next if !payload

                    payload.merge(
                      group_style: group_style,
                      effective_style:
                        effective_style(payload[:style], group_style),
                    )
                  end

              {
                id: tag_group.id,
                name: tag_group.name,
                style: group_style,
                tags: tags,
              }
            end
            .select { |group| group[:tags].any? }

        ungrouped_tags =
          tag_payloads
            .values
            .reject { |tag| used_tag_ids.include?(tag[:id]) }
            .sort_by { |tag| tag[:name] }
            .map do |tag|
              tag.merge(
                group_style: DEFAULT_STYLE,
                effective_style: effective_style(tag[:style], DEFAULT_STYLE),
              )
            end

        {
          styles: styles(),
          tag_groups: tag_groups,
          ungrouped_tags: ungrouped_tags,
        }
      end

      private

      def tag_payloads(visible_names, tag_styles)
        count_column = topic_count_column
        columns = [:id, :name]
        columns << count_column if count_column

        ::Tag.order(:name).pluck(*columns).each_with_object({}) do |row, result|
          id, name, topic_count = row

          result[id] = {
            id: id,
            name: name,
            visible_name: visible_names[name],
            style: valid_style_id(tag_styles[name]),
            topic_count: topic_count || 0,
          }
        end
      end

      def effective_style(tag_style, group_style)
        tag_style = valid_style_id(tag_style)
        return tag_style if tag_style

        valid_style_id(group_style) || DEFAULT_STYLE
      end

      def normalize_style_hash(styles)
        styles = styles.to_unsafe_h if styles.respond_to?(:to_unsafe_h)
        styles = styles.to_h if styles.respond_to?(:to_h) && !styles.is_a?(Hash)
        return {} if !styles.is_a?(Hash)

        styles.each_with_object({}) do |(key, style_id), result|
          style_id = valid_style_id(style_id)
          result[key.to_s] = style_id if style_id
        end
      end

      def save_styles!(tag_group_styles, tag_styles)
        clean_group_styles = normalize_style_hash(tag_group_styles)
        clean_tag_styles = normalize_style_hash(tag_styles)

        ::PluginStore.set(
          ::DiscourseTagVisibleName::PLUGIN_NAME,
          STYLE_STORE_KEY,
          {
            "tag_group_styles" => clean_group_styles,
            "tag_styles" => clean_tag_styles,
          },
        )
      end

      def valid_style_id(style_id)
        style_id = style_id.to_s
        return if style_id.blank? || style_id == "inherit"

        STYLE_IDS.include?(style_id) ? style_id : nil
      end

      def normalize_tag_params(tags)
        tags = tags.to_unsafe_h if tags.respond_to?(:to_unsafe_h)
        tags = tags.values if tags.is_a?(Hash)
        Array(tags)
      end

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
