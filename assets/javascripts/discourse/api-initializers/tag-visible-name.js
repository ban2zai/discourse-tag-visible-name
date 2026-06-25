import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { apiInitializer } from "discourse/lib/api";
import { makeArray } from "discourse/lib/helpers";
import { defaultRenderTag } from "discourse/lib/render-tag";
import { escapeExpression } from "discourse/lib/utilities";

const STYLE_CLASS_PREFIX = "tag-visible-name-style--";
const DEFAULT_STYLE = "default";
const PROBE_COMPAT_STYLE_ID = "tag-visible-name-probe-compat";

function tagNameFor(tag) {
  return typeof tag === "string" ? tag : tag?.name;
}

function tagKey(value) {
  if (value === null || value === undefined) {
    return null;
  }

  return String(value).trim().toLowerCase();
}

function visibleNameFor(tagName, names) {
  const key = tagKey(tagName);

  return key ? names[key] : null;
}

function styleFor(tagName, styles) {
  const key = tagKey(tagName);

  return key ? styles[key] || DEFAULT_STYLE : DEFAULT_STYLE;
}

function hasVisibleTagConfig(tagName, names, styles) {
  const key = tagKey(tagName);

  return Boolean(key && (names[key] || styles[key]));
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
  const label = String(visibleName ?? "");
  const styleClass = extraClassFor(styleFor(tagName, styles));
  const classes = joinClasses("tag-visible-name-summary-tag", styleClass);

  return `<span class="${classes}" title="${escapeExpression(
    label
  )}"><span class="d-button-label">${escapeExpression(label)}</span></span>`;
}

function cssString(value) {
  return String(value ?? "")
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\r?\n/g, "\\A ");
}

function installProbeCompatCss(names) {
  if (typeof document === "undefined") {
    return;
  }

  const rules = Object.entries(names)
    .filter(([, visibleName]) => visibleName)
    .map(
      ([tagName, visibleName]) =>
        `a.discourse-tag[data-tag-name="${cssString(
          tagName
        )}"][style*="-9999px"]::before{content:"${cssString(visibleName)}";}`
    )
    .join("\n");

  let style = document.getElementById(PROBE_COMPAT_STYLE_ID);

  if (!rules) {
    style?.remove();
    return;
  }

  if (!style) {
    style = document.createElement("style");
    style.id = PROBE_COMPAT_STYLE_ID;
    document.head.appendChild(style);
  }

  style.textContent = rules;
}

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings && !siteSettings.tag_visible_name_enabled) {
    return;
  }

  const site = api.container.lookup("service:site");
  const names = site?.tag_visible_names || {};
  const styles = site?.tag_visible_styles || {};

  installProbeCompatCss(names);

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
        const items = makeArray(this.content);

        if (
          !items.some((item) =>
            hasVisibleTagConfig(this.getName(item), names, styles)
          )
        ) {
          return items
            .map((item) => {
              const name = this.getName(item);

              return name === null || name === undefined
                ? ""
                : String(name).trim();
            })
            .join(", ");
        }

        const content = items
          .map((item) => {
            const tagName = this.getName(item);

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
