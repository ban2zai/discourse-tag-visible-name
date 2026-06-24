# frozen_string_literal: true

# name: discourse-tag-visible-name
# about: Adds editable display names for Discourse tags.
# version: 0.1.0
# authors: ban2zai
# url: https://github.com/ban2zai/discourse-tag-visible-name
# required_version: 3.3.0

enabled_site_setting :tag_visible_name_enabled
register_asset "stylesheets/common/tag-visible-name-admin.scss"
add_admin_route "tag_visible_name.admin.title", "tag-visible-names"

module ::DiscourseTagVisibleName
  PLUGIN_NAME = "discourse-tag-visible-name"
  CUSTOM_FIELD_NAME = "visible_name"

  def self.serializer_tag_name(object)
    if object.respond_to?(:name)
      object.name
    elsif object.respond_to?(:[])
      object[:name] || object["name"] || object[:id] || object["id"]
    end
  end

  def self.visible_tag_fields(name, visible_names:, tag_styles:)
    {
      visible_name:
        ::DiscourseTagVisibleName::TagVisibleNameStore.visible_name_for_name(
          name,
          visible_names,
        ),
      visible_style:
        ::DiscourseTagVisibleName::TagVisibleNameStore.visible_style_for_name(
          name,
          tag_styles,
        ),
    }
  end

  def self.add_visible_fields_to_tag_payload(tag_payload, visible_names:, tag_styles:)
    tag_name = serializer_tag_name(tag_payload)
    return tag_payload if tag_name.blank?

    visible_fields =
      visible_tag_fields(
        tag_name,
        visible_names: visible_names,
        tag_styles: tag_styles,
      )

    if tag_payload.respond_to?(:merge)
      tag_payload.merge(visible_fields.stringify_keys)
    else
      tag_payload
    end
  end
end

require_relative "lib/discourse_tag_visible_name/engine"
require_relative "lib/discourse_tag_visible_name/tag_visible_name_store"

after_initialize do
  add_to_serializer(:site, :tag_visible_names) do
    if SiteSetting.tag_visible_name_enabled
      ::DiscourseTagVisibleName::TagVisibleNameStore.mapping
    else
      {}
    end
  end

  add_to_serializer(:site, :tag_visible_styles) do
    if SiteSetting.tag_visible_name_enabled
      ::DiscourseTagVisibleName::TagVisibleNameStore.public_style_mapping
    else
      {}
    end
  end
end
