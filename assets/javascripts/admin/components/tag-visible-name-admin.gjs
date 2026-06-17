import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class TagVisibleNameAdmin extends Component {
  @tracked filter = "";
  @tracked loading = true;
  @tracked loadError = null;
  @tracked tags = [];

  constructor() {
    super(...arguments);
    this.load();
  }

  get filteredTags() {
    const query = this.filter.trim().toLowerCase();

    if (!query) {
      return this.tags;
    }

    return this.tags.filter((tag) => {
      return (
        tag.name.toLowerCase().includes(query) ||
        tag.draftVisibleName.toLowerCase().includes(query)
      );
    });
  }

  buildTag(tag) {
    return {
      ...tag,
      draftVisibleName: tag.visible_name || "",
      dirty: false,
      saving: false,
      saveDisabled: true,
      error: null,
    };
  }

  updateSaveState(tag) {
    tag.saveDisabled = tag.saving || !tag.dirty;
  }

  async load() {
    this.loading = true;
    this.loadError = null;

    try {
      const data = await ajax("/admin/plugins/tag-visible-names/tags");
      this.tags = data.tags.map((tag) => this.buildTag(tag));
    } catch {
      this.loadError = i18n("tag_visible_name.admin.load_error");
    } finally {
      this.loading = false;
    }
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value;
  }

  @action
  updateVisibleName(tag, event) {
    tag.draftVisibleName = event.target.value;
    tag.dirty = tag.draftVisibleName.trim() !== (tag.visible_name || "");
    tag.error = null;
    this.updateSaveState(tag);
    this.tags = [...this.tags];
  }

  @action
  async save(tag) {
    tag.saving = true;
    tag.error = null;
    this.updateSaveState(tag);
    this.tags = [...this.tags];

    try {
      const data = await ajax(`/admin/plugins/tag-visible-names/tags/${tag.id}`, {
        type: "PUT",
        data: {
          visible_name: tag.draftVisibleName,
        },
      });

      tag.visible_name = data.tag.visible_name || "";
      tag.draftVisibleName = tag.visible_name;
      tag.dirty = false;
    } catch {
      tag.error = i18n("tag_visible_name.admin.save_error");
    } finally {
      tag.saving = false;
      this.updateSaveState(tag);
      this.tags = [...this.tags];
    }
  }

  <template>
    <section class="tag-visible-name-admin">
      <div class="tag-visible-name-admin__header">
        <div>
          <h2>{{i18n "tag_visible_name.admin.title"}}</h2>
          <p>{{i18n "tag_visible_name.admin.description"}}</p>
        </div>

        <input
          class="tag-visible-name-admin__search"
          value={{this.filter}}
          placeholder={{i18n "tag_visible_name.admin.search_placeholder"}}
          {{on "input" this.updateFilter}}
        />
      </div>

      {{#if this.loading}}
        <p>{{i18n "tag_visible_name.admin.loading"}}</p>
      {{else if this.loadError}}
        <div class="alert alert-error">{{this.loadError}}</div>
      {{else}}
        <table class="tag-visible-name-admin__table">
          <thead>
            <tr>
              <th>{{i18n "tag_visible_name.admin.slug"}}</th>
              <th>{{i18n "tag_visible_name.admin.visible_name"}}</th>
              <th>{{i18n "tag_visible_name.admin.topic_count"}}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {{#each this.filteredTags as |tag|}}
              <tr>
                <td>
                  <code>{{tag.name}}</code>
                </td>
                <td>
                  <input
                    value={{tag.draftVisibleName}}
                    placeholder={{tag.name}}
                    {{on "input" (fn this.updateVisibleName tag)}}
                  />
                  {{#if tag.error}}
                    <div class="tag-visible-name-admin__error">{{tag.error}}</div>
                  {{/if}}
                </td>
                <td>{{tag.topic_count}}</td>
                <td>
                  <button
                    type="button"
                    class="btn btn-primary"
                    disabled={{tag.saveDisabled}}
                    {{on "click" (fn this.save tag)}}
                  >
                    {{#if tag.saving}}
                      {{i18n "tag_visible_name.admin.saving"}}
                    {{else}}
                      {{i18n "tag_visible_name.admin.save"}}
                    {{/if}}
                  </button>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{/if}}
    </section>
  </template>
}
