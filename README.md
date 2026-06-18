# discourse-tag-visible-name

Плагин добавляет редактируемые отображаемые имена и стили для тегов Discourse.

Системный slug тега не меняется: URL, `data-tag-name`, tag groups и composer продолжают работать с настоящим именем тега. Плагин хранит настройки в `PluginStore`.

## Возможности

- Админская страница: `/admin/plugins/tag-visible-names`.
- API для админки:
  - `GET /admin/plugins/tag-visible-names/tags`
  - `PUT /admin/plugins/tag-visible-names/tags`
- Публичный endpoint: `GET /tag-visible-names.json`.
- Публичная копия `tags.json` с отображаемыми именами и стилями: `GET /tags_mapping_name.json`.
- Публичная подмена текста тегов `a.discourse-tag[data-tag-name]` и `.discourse-tags .discourse-tag[data-tag-name]`.
- Импорт YAML/JSON mapping через rake.

## Импорт текущих названий

```bash
bundle exec rake tag_visible_names:import[plugins/discourse-tag-visible-name/config/tag_visible_names.example.yml]
```

Формат файла:

```yaml
бгу: "БГУ"
банк-касса-платежки-поступления-возвраты: "Банк, касса (платежки, поступления, возвраты)"
```

Неизвестные slug не создаются автоматически, а выводятся как пропущенные.
