import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class TagVisibleNameAdmin extends Component {
  @tracked dirty = false;
  @tracked filter = "";
  @tracked loadError = null;
  @tracked loading = true;
  @tracked saveError = null;
  @tracked saveMessage = null;
  @tracked saving = false;
  @tracked styles = [];
  @tracked tagGroups = [];
  @tracked ungroupedTags = [];

  constructor() {
    super(...arguments);
    this.load();
  }

  get allTags() {
    return [
      ...this.tagGroups.flatMap((group) => group.tags),
      ...this.ungroupedTags,
    ];
  }

  get filteredTagGroups() {
    const query = this.normalizedFilter;

    return this.tagGroups
      .map((group) => {
        if (!query || group.name.toLowerCase().includes(query)) {
          return group;
        }

        return {
          ...group,
          tags: group.tags.filter((tag) => this.tagMatches(tag, query)),
        };
      })
      .filter((group) => group.tags.length > 0);
  }

  get filteredUngroupedTags() {
    const query = this.normalizedFilter;

    if (!query) {
      return this.ungroupedTags;
    }

    return this.ungroupedTags.filter((tag) => this.tagMatches(tag, query));
  }

  get hasUngroupedTags() {
    return this.filteredUngroupedTags.length > 0;
  }

  get normalizedFilter() {
    return this.filter.trim().toLowerCase();
  }

  get saveDisabled() {
    return this.saving || !this.dirty;
  }

  buildTag(tag) {
    return {
      ...tag,
      draftStyle: tag.style || "inherit",
      draftVisibleName: tag.visible_name || "",
      error: null,
    };
  }

  buildGroup(group) {
    return {
      ...group,
      draftStyle: group.style || "default",
      tags: group.tags.map((tag) => this.buildTag(tag)),
    };
  }

  tagMatches(tag, query) {
    return (
      tag.name.toLowerCase().includes(query) ||
      tag.draftVisibleName.toLowerCase().includes(query)
    );
  }

  applyPayload(data) {
    this.styles = data.styles || [];
    this.tagGroups = (data.tag_groups || []).map((group) =>
      this.buildGroup(group)
    );
    this.ungroupedTags = (data.ungrouped_tags || []).map((tag) =>
      this.buildTag(tag)
    );
    this.dirty = false;
  }

  async load() {
    this.loading = true;
    this.loadError = null;

    try {
      this.applyPayload(await ajax("/admin/plugins/tag-visible-names/tags"));
    } catch {
      this.loadError = i18n("tag_visible_name.admin.load_error");
    } finally {
      this.loading = false;
    }
  }

  markDirty() {
    this.dirty = true;
    this.saveError = null;
    this.saveMessage = null;
  }

  refreshCollections() {
    this.tagGroups = [...this.tagGroups];
    this.ungroupedTags = [...this.ungroupedTags];
  }

  syncTagDrafts(tag, fields) {
    this.allTags
      .filter((item) => item.id === tag.id)
      .forEach((item) => {
        Object.assign(item, fields);
        item.error = null;
      });
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value;
  }

  @action
  updateGroupStyle(group, event) {
    const targetGroup =
      this.tagGroups.find((item) => item.id === group.id) || group;

    targetGroup.draftStyle = event.target.value;
    this.markDirty();
    this.tagGroups = [...this.tagGroups];
  }

  @action
  updateTagStyle(tag, event) {
    this.syncTagDrafts(tag, { draftStyle: event.target.value });
    this.markDirty();
    this.refreshCollections();
  }

  @action
  updateVisibleName(tag, event) {
    this.syncTagDrafts(tag, { draftVisibleName: event.target.value });
    this.markDirty();
    this.refreshCollections();
  }

  @action
  async saveChanges() {
    this.saving = true;
    this.saveError = null;
    this.saveMessage = null;

    const tagGroupStyles = {};
    this.tagGroups.forEach((group) => {
      tagGroupStyles[group.id] = group.draftStyle;
    });

    const tagStyles = {};
    this.allTags.forEach((tag) => {
      tagStyles[tag.name] = tag.draftStyle;
    });

    try {
      const data = await ajax("/admin/plugins/tag-visible-names/tags", {
        type: "PUT",
        data: {
          tag_group_styles: tagGroupStyles,
          tag_styles: tagStyles,
          tags: this.allTags.map((tag) => ({
            id: tag.id,
            visible_name: tag.draftVisibleName,
          })),
        },
      });

      this.applyPayload(data);
      this.saveMessage = i18n("tag_visible_name.admin.save_success");
    } catch {
      this.saveError = i18n("tag_visible_name.admin.save_error");
    } finally {
      this.saving = false;
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
        {{#each this.filteredTagGroups as |group|}}
          <section class="tag-visible-name-admin__group">
            <div class="tag-visible-name-admin__group-header">
              <h3>{{group.name}}</h3>

              <label>
                <span>{{i18n "tag_visible_name.admin.group_style"}}</span>
                <select
                  value={{group.draftStyle}}
                  {{on "change" (fn this.updateGroupStyle group)}}
                >
                  {{#each this.styles as |style|}}
                    <option value={{style.id}}>{{i18n style.name}}</option>
                  {{/each}}
                </select>
              </label>
            </div>

            <table class="tag-visible-name-admin__table">
              <thead>
                <tr>
                  <th>{{i18n "tag_visible_name.admin.slug"}}</th>
                  <th>{{i18n "tag_visible_name.admin.visible_name"}}</th>
                  <th>{{i18n "tag_visible_name.admin.style"}}</th>
                  <th>{{i18n "tag_visible_name.admin.topic_count"}}</th>
                </tr>
              </thead>
              <tbody>
                {{#each group.tags as |tag|}}
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
                    </td>
                    <td>
                      <select
                        value={{tag.draftStyle}}
                        {{on "change" (fn this.updateTagStyle tag)}}
                      >
                        <option value="inherit">
                          {{i18n "tag_visible_name.admin.styles.inherit"}}
                        </option>
                        {{#each this.styles as |style|}}
                          <option value={{style.id}}>{{i18n style.name}}</option>
                        {{/each}}
                      </select>
                    </td>
                    <td>{{tag.topic_count}}</td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </section>
        {{/each}}

        {{#if this.hasUngroupedTags}}
          <section class="tag-visible-name-admin__group">
            <div class="tag-visible-name-admin__group-header">
              <h3>{{i18n "tag_visible_name.admin.ungrouped"}}</h3>
            </div>

            <table class="tag-visible-name-admin__table">
              <thead>
                <tr>
                  <th>{{i18n "tag_visible_name.admin.slug"}}</th>
                  <th>{{i18n "tag_visible_name.admin.visible_name"}}</th>
                  <th>{{i18n "tag_visible_name.admin.style"}}</th>
                  <th>{{i18n "tag_visible_name.admin.topic_count"}}</th>
                </tr>
              </thead>
              <tbody>
                {{#each this.filteredUngroupedTags as |tag|}}
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
                    </td>
                    <td>
                      <select
                        value={{tag.draftStyle}}
                        {{on "change" (fn this.updateTagStyle tag)}}
                      >
                        <option value="inherit">
                          {{i18n "tag_visible_name.admin.styles.inherit"}}
                        </option>
                        {{#each this.styles as |style|}}
                          <option value={{style.id}}>{{i18n style.name}}</option>
                        {{/each}}
                      </select>
                    </td>
                    <td>{{tag.topic_count}}</td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </section>
        {{/if}}

        <div class="tag-visible-name-admin__footer">
          <button
            type="button"
            class="btn btn-primary"
            disabled={{this.saveDisabled}}
            {{on "click" this.saveChanges}}
          >
            {{#if this.saving}}
              {{i18n "tag_visible_name.admin.saving"}}
            {{else}}
              {{i18n "tag_visible_name.admin.save_all"}}
            {{/if}}
          </button>

          {{#if this.saveMessage}}
            <span class="tag-visible-name-admin__save-message">
              {{this.saveMessage}}
            </span>
          {{/if}}
        </div>

        {{#if this.saveError}}
          <div class="alert alert-error">{{this.saveError}}</div>
        {{/if}}
      {{/if}}
    </section>
  </template>
}
