document.querySelectorAll("[data-limo-publication-tabs]").forEach((tabSet) => {
  const topicButtons = Array.from(tabSet.querySelectorAll("[data-limo-publication-filter]"));
  const featuredToggle = tabSet.querySelector("[data-limo-publication-featured]");
  const lists = Array.from(tabSet.querySelectorAll("ol.bibliography"));
  const emptyMessage = tabSet.querySelector("[data-limo-publication-empty]");
  const countMessage = tabSet.querySelector("[data-limo-publication-count]");
  const supportedTopics = topicButtons.map((button) => button.dataset.limoPublicationFilter);

  let activeTopic = "all";
  let featuredOnly = false;

  const matches = (publication) => {
    const categories = (publication.dataset.limoCategories || "").split(/\s+/);
    const matchesTopic = activeTopic === "all" || categories.includes(activeTopic);
    const matchesFeatured = !featuredOnly || publication.dataset.limoSelected === "true";
    return matchesTopic && matchesFeatured;
  };

  const updateUrl = () => {
    const url = new URL(window.location.href);

    if (activeTopic === "all") url.searchParams.delete("topic");
    else url.searchParams.set("topic", activeTopic);

    if (featuredOnly) url.searchParams.set("featured", "1");
    else url.searchParams.delete("featured");

    window.history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`);
  };

  const applyFilters = ({ syncUrl = true } = {}) => {
    let visibleCount = 0;

    topicButtons.forEach((button) => {
      button.setAttribute("aria-pressed", (button.dataset.limoPublicationFilter === activeTopic).toString());
    });

    if (featuredToggle) featuredToggle.checked = featuredOnly;

    lists.forEach((list) => {
      let visibleInYear = 0;
      list.querySelectorAll(":scope > li").forEach((item) => {
        const publication = item.querySelector("[data-limo-publication]");
        const visible = publication && matches(publication);
        item.hidden = !visible;
        if (visible) visibleInYear += 1;
      });

      list.hidden = visibleInYear === 0;
      const yearHeading = list.previousElementSibling;
      if (yearHeading?.classList.contains("bibliography")) yearHeading.hidden = visibleInYear === 0;
      visibleCount += visibleInYear;
    });

    if (emptyMessage) emptyMessage.hidden = visibleCount !== 0;
    if (countMessage) countMessage.textContent = `${visibleCount} publication${visibleCount === 1 ? "" : "s"} shown`;
    if (syncUrl) updateUrl();
  };

  topicButtons.forEach((button) => {
    button.addEventListener("click", () => {
      activeTopic = button.dataset.limoPublicationFilter;
      applyFilters();
    });
  });

  featuredToggle?.addEventListener("change", () => {
    featuredOnly = featuredToggle.checked;
    applyFilters();
  });

  const params = new URLSearchParams(window.location.search);
  const requestedTopic = params.get("topic");
  if (requestedTopic && supportedTopics.includes(requestedTopic)) activeTopic = requestedTopic;
  featuredOnly = ["1", "true"].includes(params.get("featured"));
  applyFilters({ syncUrl: false });
});
