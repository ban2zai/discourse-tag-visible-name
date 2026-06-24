import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { apiInitializer } from "discourse/lib/api";
import { makeArray } from "discourse/lib/helpers";
import { defaultRenderTag } from "discourse/lib/render-tag";
import { escapeExpression } from "discourse/lib/utilities";

const STYLE_CLASS_PREFIX = "tag-visible-name-style--";
const DEFAULT_STYLE = "default";

function tagNameFor(tag) {
  return typeof tag === "string" ? tag : tag?.name;
}

function tagKey(value) {
  return value?.trim().toLowerCase();
}

function visibleNameFor(tagName, names) {
  return names[tagKey(tagName)];
}

function styleFor(tagName, styles) {
  return styles[tagKey(tagName)] || DEFAULT_STYLE;
}

function extraClassFor(style) {
  return style && style !== DEFAULT_STYLE
    ? `${STYLE_CLASS_PREFIX}${style}`
    : null;
}

function joinClasses(...classes) {
  return classes.filter(Boolean).join(" ");
}

function summaryTagHtml(tagName, names, styles) {
  const visibleName = visibleNameFor(tagName, names) || tagName;
  const styleClass = extraClassFor(styleFor(tagName, styles));
  const classes = joinClasses("tag-visible-name-summary-tag", styleClass);

  return `<span class="${classes}" title="${escapeExpression(
    visibleName
  )}"><span class="d-button-label">${escapeExpression(visibleName)}</span></span>`;
}

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings && !siteSettings.tag_visible_name_enabled) {
    return;
  }

  const site = api.container.lookup("service:site");
  const names = site?.tag_visible_names || {};
  const styles = site?.tag_visible_styles || {};

  api.replaceTagRenderer((tag, params = {}) => {
    const tagName = tagNameFor(tag);
    const visibleName = visibleNameFor(tagName, names);
    const styleClass = extraClassFor(styleFor(tagName, styles));

    return defaultRenderTag(tag, {
      ...params,
      displayName: visibleName || params.displayName,
      extraClass: joinClasses(params.extraClass, styleClass),
    });
  });

  api.modifyClass("component:selected-choice", {
    pluginId: "discourse-tag-visible-name-selected-choice",

    itemName: computed("item", function () {
      const tagName = this.getName(this.item);

      return visibleNameFor(tagName, names) || tagName;
    }),

    didReceiveAttrs() {
      this._super(...arguments);

      const tagName = this.getName(this.item);
      const styleClass = extraClassFor(styleFor(tagName, styles));

      if (styleClass || this.extraClass?.startsWith(STYLE_CLASS_PREFIX)) {
        this.set("extraClass", styleClass);
      }
    },
  });

  api.modifyClass("component:multi-select/format-selected-content", {
    pluginId: "discourse-tag-visible-name-format-selected-content",

    formattedContent: computed("content", function () {
      if (this.content) {
        const content = makeArray(this.content)
          .map((item) => {
            const tagName = this.getName(item)?.trim();

            return summaryTagHtml(tagName, names, styles);
          })
          .join("");

        return trustHTML(
          `<span class="tag-visible-name-formatted-selection">${content}</span>`
        );
      } else {
        return this.getName(this.selectKit.noneItem);
      }
    }),
  });

  api.modifyClass("component:selected-name", {
    pluginId: "discourse-tag-visible-name-selected-name",

    didReceiveAttrs() {
      this._super(...arguments);

      const visibleName = visibleNameFor(this.name, names);

      if (visibleName) {
        this.setProperties({
          headerLabel: trustHTML(summaryTagHtml(this.name, names, styles)),
          headerTitle: visibleName,
          name: visibleName,
        });
      }
    },
  });
});
