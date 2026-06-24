import { apiInitializer } from "discourse/lib/api";
import { defaultRenderTag } from "discourse/lib/render-tag";

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
});
