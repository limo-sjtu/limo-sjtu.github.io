document.querySelectorAll("[data-limo-publication-tabs]").forEach((tabSet) => {
  const topicButtons = Array.from(tabSet.querySelectorAll("[data-limo-publication-filter]"));
  const featuredToggle = tabSet.querySelector("[data-limo-publication-featured]");
  const searchInput = tabSet.querySelector("[data-limo-publication-search]");
  const yearNavigation = tabSet.querySelector("[data-limo-publication-years]");
  const lists = Array.from(tabSet.querySelectorAll("ol.bibliography"));
  const emptyMessage = tabSet.querySelector("[data-limo-publication-empty]");
  const countMessage = tabSet.querySelector("[data-limo-publication-count]");
  const supportedTopics = topicButtons.map((button) => button.dataset.limoPublicationFilter);
  const searchIndex = new WeakMap();

  let activeTopic = "all";
  let featuredOnly = false;
  let searchQuery = "";

  const normalize = (value) =>
    (value || "")
      .toLocaleLowerCase()
      .normalize("NFKD")
      .replace(/[\u0300-\u036f]/g, "")
      .trim();

  const searchableText = (publication) => {
    if (!searchIndex.has(publication)) {
      const title = publication.querySelector(".title")?.textContent || publication.dataset.limoTitle;
      const authors = publication.querySelector(".author")?.textContent || publication.dataset.limoAuthors;
      const venue = Array.from(publication.querySelectorAll(".periodical"))
        .map((element) => element.textContent)
        .join(" ");
      searchIndex.set(publication, normalize(`${title} ${authors} ${venue}`));
    }
    return searchIndex.get(publication);
  };

  const matches = (publication) => {
    const categories = (publication.dataset.limoCategories || "").split(/\s+/);
    const matchesTopic = activeTopic === "all" || categories.includes(activeTopic);
    const matchesHighlighted = !featuredOnly || publication.dataset.limoSelected === "true";
    const matchesSearch = !searchQuery || searchableText(publication).includes(searchQuery);
    return matchesTopic && matchesHighlighted && matchesSearch;
  };

  const publicationPeriod = (year) => {
    const numericYear = Number.parseInt(year, 10);
    if (numericYear >= 2011 && numericYear <= 2020) {
      return { key: "2010s", label: "2010s", ariaLabel: "2010s: jump to publications from 2011 to 2020" };
    }
    if (numericYear >= 2004 && numericYear <= 2010) {
      return { key: "2000s", label: "2000s", ariaLabel: "2000s: jump to publications from 2004 to 2010" };
    }
    return { key: year, label: year, ariaLabel: `Jump to publications from ${year}` };
  };

  const yearGroups = lists.map((list) => {
    const heading = list.previousElementSibling?.classList.contains("bibliography") ? list.previousElementSibling : null;
    if (!heading) return { list, heading: null, period: null, visible: false };

    const year = heading.textContent.trim();
    heading.id = `publications-year-${year.replace(/[^0-9a-z]+/gi, "-").replace(/^-|-$/g, "")}`;
    return { list, heading, period: publicationPeriod(year), visible: false };
  });

  const navigationGroups = [];
  const navigationGroupsByKey = new Map();

  yearGroups.forEach((yearGroup) => {
    if (!yearNavigation || !yearGroup.heading || !yearGroup.period) return;

    let navigationGroup = navigationGroupsByKey.get(yearGroup.period.key);
    if (!navigationGroup) {
      const link = document.createElement("a");
      link.textContent = yearGroup.period.label;
      link.setAttribute("aria-label", yearGroup.period.ariaLabel);
      yearNavigation.append(link);
      navigationGroup = { link, yearGroups: [] };
      navigationGroupsByKey.set(yearGroup.period.key, navigationGroup);
      navigationGroups.push(navigationGroup);
    }
    navigationGroup.yearGroups.push(yearGroup);
  });

  if (yearNavigation) yearNavigation.hidden = !yearNavigation.childElementCount;

  const updateUrl = () => {
    const url = new URL(window.location.href);

    if (activeTopic === "all") url.searchParams.delete("topic");
    else url.searchParams.set("topic", activeTopic);

    if (featuredOnly) url.searchParams.set("featured", "1");
    else url.searchParams.delete("featured");

    if (searchQuery) url.searchParams.set("q", searchInput?.value.trim() || searchQuery);
    else url.searchParams.delete("q");

    window.history.replaceState({}, "", `${url.pathname}${url.search}${url.hash}`);
  };

  const applyFilters = ({ syncUrl = true } = {}) => {
    let visibleCount = 0;

    topicButtons.forEach((button) => {
      button.setAttribute("aria-pressed", (button.dataset.limoPublicationFilter === activeTopic).toString());
    });

    if (featuredToggle) featuredToggle.checked = featuredOnly;

    yearGroups.forEach((yearGroup) => {
      const { list, heading } = yearGroup;
      let visibleInYear = 0;
      Array.from(list.children).forEach((item) => {
        const publication = item.querySelector("[data-limo-publication]");
        const visible = publication && matches(publication);
        item.hidden = !visible;
        if (visible) visibleInYear += 1;
      });

      const showYear = visibleInYear > 0;
      yearGroup.visible = showYear;
      list.hidden = !showYear;
      if (heading) heading.hidden = !showYear;
      visibleCount += visibleInYear;
    });

    let visibleNavigationGroups = 0;
    navigationGroups.forEach(({ link, yearGroups: groupedYears }) => {
      const firstVisibleYear = groupedYears.find((yearGroup) => yearGroup.visible && yearGroup.heading);
      link.hidden = !firstVisibleYear;
      if (firstVisibleYear) {
        link.href = `#${firstVisibleYear.heading.id}`;
        visibleNavigationGroups += 1;
      }
    });

    if (yearNavigation) yearNavigation.hidden = visibleNavigationGroups === 0;
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

  let searchTimer;
  searchInput?.addEventListener("input", () => {
    window.clearTimeout(searchTimer);
    searchTimer = window.setTimeout(() => {
      searchQuery = normalize(searchInput.value);
      applyFilters();
    }, 150);
  });

  const params = new URLSearchParams(window.location.search);
  const requestedTopic = params.get("topic");
  if (requestedTopic && supportedTopics.includes(requestedTopic)) activeTopic = requestedTopic;
  featuredOnly = ["1", "true"].includes(params.get("featured"));
  if (searchInput && params.get("q")) {
    searchInput.value = params.get("q");
    searchQuery = normalize(searchInput.value);
  }
  applyFilters({ syncUrl: false });
});
