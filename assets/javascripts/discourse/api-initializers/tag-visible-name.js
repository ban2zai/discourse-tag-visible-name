import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

const STYLE_CLASS_PREFIX = "tag-visible-name-style--";
const STYLE_IDS = ["default", "area", "section"];
const TAG_SELECTOR =
  "a.discourse-tag[data-tag-name], .discourse-tags .discourse-tag[data-tag-name]";
const TAG_SELECT_KIT_SELECTOR = 'details.select-kit[class*="tag"]';
const SELECTED_CHOICE_SELECTOR = `${TAG_SELECT_KIT_SELECTOR} .selected-choice[data-name]`;
const FORMATTED_SELECTION_SELECTOR = `${TAG_SELECT_KIT_SELECTOR} summary .formatted-selection`;
const TAG_FILTER_PLACEHOLDER = "Теги";

function tagKey(value) {
  return value?.trim().toLowerCase();
}

function visibleNameFor(value, names) {
  return names[tagKey(value)];
}

function styleFor(value, styles) {
  return styles[tagKey(value)] || "default";
}

function applyStyleClass(element, style) {
  STYLE_IDS.forEach((styleId) => {
    element.classList.remove(`${STYLE_CLASS_PREFIX}${styleId}`);
  });

  if (style !== "default") {
    element.classList.add(`${STYLE_CLASS_PREFIX}${style}`);
  }
}

function updateTagElement(element, names, styles) {
  const tagName = element.dataset.tagName;
  const visibleName = visibleNameFor(tagName, names);
  const style = styleFor(tagName, styles);

  applyStyleClass(element, style);

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

  if (root.matches?.(TAG_SELECTOR)) {
    updateTagElement(root, names, styles);
  }

  root.querySelectorAll?.(TAG_SELECTOR).forEach((element) =>
    updateTagElement(element, names, styles)
  );
}

function updateSelectedChoice(choice, names, styles) {
  const tagName = choice.dataset.name;
  const visibleName = visibleNameFor(tagName, names);
  const style = styleFor(tagName, styles);

  applyStyleClass(choice, style);

  if (!visibleName) {
    return;
  }

  const label = choice.querySelector(".d-button-label");

  if (label && choice.dataset.visibleNameApplied !== visibleName) {
    label.textContent = visibleName;
    choice.dataset.visibleNameApplied = visibleName;
  }

  choice.title = visibleName;

  const ariaLabel = choice.getAttribute("aria-label");

  if (ariaLabel) {
    if (!choice.dataset.originalAriaLabel) {
      choice.dataset.originalAriaLabel = ariaLabel;
    }

    choice.setAttribute(
      "aria-label",
      choice.dataset.originalAriaLabel.replace(tagName, visibleName)
    );
  }
}

function buildFormattedSelectionTag(tagName, names, styles) {
  const trimmedName = tagName.trim();
  const visibleName = visibleNameFor(trimmedName, names) || trimmedName;
  const tag = document.createElement("span");

  tag.classList.add("discourse-tag", "box", "tag-visible-name-summary-tag");
  tag.dataset.tagName = trimmedName;
  tag.textContent = visibleName;
  tag.title = visibleName;
  applyStyleClass(tag, styleFor(trimmedName, styles));

  return { element: tag, visibleName };
}

function resetFormattedSelection(selection) {
  const summary = selection.closest("summary");
  const selectKit = selection.closest(TAG_SELECT_KIT_SELECTOR);
  const placeholder =
    summary?.dataset.name?.trim() ||
    (selectKit?.classList.contains("native-tag-filter-chooser")
      ? TAG_FILTER_PLACEHOLDER
      : "");

  selection.classList.remove("tag-visible-name-formatted-selection");
  delete selection.dataset.visibleNameApplied;
  selection.removeAttribute("title");

  if (
    selection.querySelector(".tag-visible-name-summary-tag") ||
    selection.textContent.trim() === ""
  ) {
    selection.textContent = placeholder;
  }
}

function updateFormattedSelection(selection, names, styles) {
  const summary = selection.closest("summary");
  const tagValues = summary?.dataset.value
    ?.split(",")
    .map((tagValue) => tagValue.trim())
    .filter(Boolean);
  const tagNames = summary?.dataset.name
    ?.split(",")
    .map((tagName) => tagName.trim())
    .filter(Boolean);

  if (!tagValues?.length || !tagNames?.length) {
    resetFormattedSelection(selection);
    return;
  }

  const renderedTags = tagNames.map((tagName) =>
    buildFormattedSelectionTag(tagName, names, styles)
  );
  const visibleNames = renderedTags.map((tag) => tag.visibleName);
  const formattedText = visibleNames.join(", ");

  if (
    selection.dataset.visibleNameApplied === formattedText &&
    selection.querySelector(".tag-visible-name-summary-tag")
  ) {
    return;
  }

  const fragment = document.createDocumentFragment();
  renderedTags.forEach((tag) => fragment.appendChild(tag.element));

  selection.textContent = "";
  selection.appendChild(fragment);
  selection.title = formattedText;
  selection.dataset.visibleNameApplied = formattedText;
  selection.classList.add("tag-visible-name-formatted-selection");
}

function updateTagSelectKitElements(root, names, styles) {
  if (!root) {
    return;
  }

  if (root.matches?.(SELECTED_CHOICE_SELECTOR)) {
    updateSelectedChoice(root, names, styles);
  }

  root.querySelectorAll?.(SELECTED_CHOICE_SELECTOR).forEach((element) =>
    updateSelectedChoice(element, names, styles)
  );

  if (root.matches?.(FORMATTED_SELECTION_SELECTOR)) {
    updateFormattedSelection(root, names, styles);
  }

  root.querySelectorAll?.(FORMATTED_SELECTION_SELECTOR).forEach((element) =>
    updateFormattedSelection(element, names, styles)
  );
}

function updateVisibleTagNames(root, names, styles) {
  if (
    !root ||
    (Object.keys(names).length === 0 && Object.keys(styles).length === 0)
  ) {
    return;
  }

  updateTagElements(root, names, styles);
  updateTagSelectKitElements(root, names, styles);
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
      updateVisibleTagNames(document, names, styles);
    })
    .catch(() => {
      names = {};
      styles = {};
    });

  api.onPageChange(() => updateVisibleTagNames(document, names, styles));

  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      if (mutation.type === "attributes") {
        updateVisibleTagNames(mutation.target, names, styles);
      } else {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === Node.ELEMENT_NODE) {
            updateVisibleTagNames(node, names, styles);
          }
        });
      }
    });
  });

  if (document.body) {
    observer.observe(document.body, {
      attributeFilter: ["data-name"],
      attributes: true,
      childList: true,
      subtree: true,
    });
  }
});
