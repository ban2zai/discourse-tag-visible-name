# frozen_string_literal: true

module ::DiscourseTagVisibleName
  class PublicController < ::ApplicationController
    requires_plugin ::DiscourseTagVisibleName::PLUGIN_NAME

    def index
      render json: {
               tag_visible_names: ::DiscourseTagVisibleName::TagVisibleNameStore.mapping,
             }
    end
  end
end
