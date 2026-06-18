import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

const STYLE_CLASS_PREFIX = "tag-visible-name-style--";
const STYLE_IDS = ["default", "area", "section"];

function updateTagElement(element, names, styles) {
  const tagName = element.dataset.tagName?.toLowerCase();
  const visibleName = names[tagName];
  const style = styles[tagName] || "default";

  STYLE_IDS.forEach((styleId) => {
    element.classList.remove(`${STYLE_CLASS_PREFIX}${styleId}`);
  });

  if (style !== "default") {
    element.classList.add(`${STYLE_CLASS_PREFIX}${style}`);
  }

  if (visibleName && element.dataset.visibleNameApplied !== visibleName) {
    element.textContent = visibleName;
    element.title = visibleName;
    element.dataset.visibleNameApplied = visibleName;
  }
}

function updateTagElements(root, names, styles) {
  if (
    !root ||
    (Object.keys(names).length === 0 && Object.keys(styles).length === 0)
  ) {
    return;
  }

  if (root.matches?.("a.discourse-tag[data-tag-name]")) {
    updateTagElement(root, names, styles);
  }

  root.querySelectorAll?.("a.discourse-tag[data-tag-name]").forEach((element) =>
    updateTagElement(element, names, styles)
  );
}

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings && !siteSettings.tag_visible_name_enabled) {
    return;
  }

  let names = {};
  let styles = {};

  ajax("/tag-visible-names.json")
    .then((data) => {
      names = data.tag_visible_names || {};
      styles = data.tag_styles || {};
      updateTagElements(document, names, styles);
    })
    .catch(() => {
      names = {};
      styles = {};
    });

  api.onPageChange(() => updateTagElements(document, names, styles));

  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          updateTagElements(node, names, styles);
        }
      });
    });
  });

  if (document.body) {
    observer.observe(document.body, { childList: true, subtree: true });
  }
});
