# frozen_string_literal: true

Discourse::Application.routes.append do
  get "/tag-visible-names" => "discourse_tag_visible_name/public#index",
      defaults: {
        format: :json,
      }

  get "/admin/plugins/tag-visible-names" => "admin/plugins#index",
      constraints: StaffConstraint.new

  get "/admin/plugins/tag-visible-names/tags" =>
        "discourse_tag_visible_name/admin/tags#index",
      defaults: {
        format: :json,
      }

  put "/admin/plugins/tag-visible-names/tags/:id" =>
        "discourse_tag_visible_name/admin/tags#update",
      defaults: {
        format: :json,
      }
end
