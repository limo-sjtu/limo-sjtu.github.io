(() => {
  const initializePublicationDisclosures = () => {
    document.querySelectorAll("[data-limo-publication-toggle]").forEach((button) => {
      if (button.dataset.limoDisclosureReady === "true") return;
      button.dataset.limoDisclosureReady = "true";

      button.addEventListener("click", () => {
        const publication = button.closest("[data-limo-publication]");
        const panelId = button.getAttribute("aria-controls");
        const panel = publication ? Array.from(publication.querySelectorAll(".limo-publication-panel")).find(({ id }) => id === panelId) : null;
        if (!publication || !panel) return;

        const willOpen = panel.hidden;
        publication.querySelectorAll("[data-limo-publication-toggle]").forEach((otherButton) => {
          otherButton.setAttribute("aria-expanded", "false");
        });
        publication.querySelectorAll(".limo-publication-panel").forEach((otherPanel) => {
          otherPanel.hidden = true;
        });

        panel.hidden = !willOpen;
        button.setAttribute("aria-expanded", willOpen.toString());
      });
    });

    document.querySelectorAll("[data-limo-more-authors]").forEach((button) => {
      if (button.dataset.limoAuthorsReady === "true") return;
      button.dataset.limoAuthorsReady = "true";

      button.addEventListener("click", () => {
        const expanded = button.getAttribute("aria-expanded") === "true";
        button.setAttribute("aria-expanded", (!expanded).toString());
        button.querySelector("[data-limo-more-authors-collapsed]").hidden = !expanded;
        button.querySelector("[data-limo-more-authors-expanded]").hidden = expanded;
      });
    });
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initializePublicationDisclosures, { once: true });
  } else {
    initializePublicationDisclosures();
  }
})();
