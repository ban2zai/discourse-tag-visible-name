# frozen_string_literal: true

module ::DiscourseTagVisibleName
  module Admin
    class TagsController < ::ApplicationController
      requires_plugin ::DiscourseTagVisibleName::PLUGIN_NAME

      before_action :ensure_site_admin

      def index
        render json: ::DiscourseTagVisibleName::TagVisibleNameStore.list
      end

      def update
        ::DiscourseTagVisibleName::TagVisibleNameStore.save_all!(
          tags: params[:tags] || [],
          tag_group_styles: params[:tag_group_styles] || {},
          tag_styles: params[:tag_styles] || {},
        )

        render json: ::DiscourseTagVisibleName::TagVisibleNameStore.list
      end

      private

      def ensure_site_admin
        if guardian.respond_to?(:ensure_can_admin_site!)
          guardian.ensure_can_admin_site!
        elsif !current_user&.admin?
          raise Discourse::InvalidAccess.new
        end
      end
    end
  end
end
