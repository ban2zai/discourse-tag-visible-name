import { apiInitializer } from "discourse/lib/api";

function visibleNameMap(api) {
  return api.container.lookup("service:site")?.tag_visible_names || {};
}

function updateTagElement(element, names) {
  const tagName = element.dataset.tagName;
  const visibleName = names[tagName];

  if (!visibleName || element.dataset.visibleNameApplied === visibleName) {
    return;
  }

  element.textContent = visibleName;
  element.title = visibleName;
  element.dataset.visibleNameApplied = visibleName;
}

function updateTagElements(root, names) {
  if (!root || Object.keys(names).length === 0) {
    return;
  }

  if (root.matches?.("a.discourse-tag[data-tag-name]")) {
    updateTagElement(root, names);
  }

  root.querySelectorAll?.("a.discourse-tag[data-tag-name]").forEach((element) =>
    updateTagElement(element, names)
  );
}

export default apiInitializer("1.8.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  if (siteSettings && !siteSettings.tag_visible_name_enabled) {
    return;
  }

  const names = visibleNameMap(api);

  updateTagElements(document, names);
  api.onPageChange(() => updateTagElements(document, names));

  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          updateTagElements(node, names);
        }
      });
    });
  });

  if (document.body) {
    observer.observe(document.body, { childList: true, subtree: true });
  }
});
