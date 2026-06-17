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
end

require_relative "lib/discourse_tag_visible_name/engine"
require_relative "lib/discourse_tag_visible_name/tag_visible_name_store"
