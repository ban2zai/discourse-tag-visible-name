# frozen_string_literal: true

namespace :tag_visible_names do
  desc "Import tag visible names from YAML or JSON: rake tag_visible_names:import[path]"
  task :import, [:path] => :environment do |_task, args|
    result = ::DiscourseTagVisibleName::TagVisibleNameStore.import_file!(args[:path])

    puts "Импортировано: #{result[:imported].size}"

    if result[:skipped].any?
      puts "Пропущены неизвестные теги:"
      result[:skipped].each { |tag_name| puts "  - #{tag_name}" }
    end
  end
end
