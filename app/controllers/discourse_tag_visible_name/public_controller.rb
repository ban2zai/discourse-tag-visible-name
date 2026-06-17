# frozen_string_literal: true

module ::DiscourseTagVisibleName
  class PublicController < ::ApplicationController
    requires_plugin ::DiscourseTagVisibleName::PLUGIN_NAME

    def index
      render json: {
               tag_visible_names: ::DiscourseTagVisibleName::TagVisibleNameStore.mapping,
               tag_styles:
                 ::DiscourseTagVisibleName::TagVisibleNameStore.public_style_mapping,
             }
    end
  end
end
