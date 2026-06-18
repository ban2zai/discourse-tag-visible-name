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

    def tags_mapping_name
      status, headers, response = ::TagsController.action(:index).call(tags_json_env)
      self.status = status

      headers.each do |key, value|
        next if key.to_s.downcase == "content-length"

        self.headers[key] = value
      end

      render json: enrich_tags_payload(parse_response_body(response))
    ensure
      response&.close if response.respond_to?(:close)
    end

    private

    def tags_json_env
      request.env.merge(
        "PATH_INFO" => "/tags.json",
        "REQUEST_PATH" => "/tags.json",
        "action_dispatch.request.path_parameters" => {
          controller: "tags",
          action: "index",
          format: :json,
        },
      )
    end

    def parse_response_body(response)
      body = +""
      response.each { |part| body << part.to_s }
      JSON.parse(body)
    end

    def enrich_tags_payload(value)
      case value
      when Array
        value.map { |item| enrich_tags_payload(item) }
      when Hash
        enriched =
          value.transform_values { |item| enrich_tags_payload(item) }

        if tag_payload?(enriched)
          ::DiscourseTagVisibleName.add_visible_fields_to_tag_payload(enriched)
        else
          enriched
        end
      else
        value
      end
    end

    def tag_payload?(payload)
      payload.key?("count") && (payload.key?("name") || payload.key?("text"))
    end
  end
end
