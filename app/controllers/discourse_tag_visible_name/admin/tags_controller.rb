# frozen_string_literal: true

module ::DiscourseTagVisibleName
  module Admin
    class TagsController < ::ApplicationController
      requires_plugin ::DiscourseTagVisibleName::PLUGIN_NAME

      before_action :ensure_site_admin

      def index
        render json: { tags: ::DiscourseTagVisibleName::TagVisibleNameStore.list }
      end

      def update
        tag = ::Tag.find(params[:id])
        visible_name =
          ::DiscourseTagVisibleName::TagVisibleNameStore.save!(
            tag,
            params[:visible_name],
          )

        render json: {
                 tag: {
                   id: tag.id,
                   name: tag.name,
                   visible_name: visible_name,
                   topic_count:
                     ::DiscourseTagVisibleName::TagVisibleNameStore.topic_count_for(
                       tag,
                     ),
                 },
               }
      end

      def import
        mapping =
          ::DiscourseTagVisibleName::TagVisibleNameStore.parse_mapping(
            params[:content],
            params[:format],
          )

        render json:
                 ::DiscourseTagVisibleName::TagVisibleNameStore.import_mapping!(
                   mapping,
                 )
      rescue ArgumentError, JSON::ParserError, Psych::Exception => e
        render json: { error: e.message }, status: 422
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
