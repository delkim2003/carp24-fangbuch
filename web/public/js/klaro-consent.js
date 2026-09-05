(function () {
  var banner = document.getElementById("klaro-banner");
  if (!banner) return;

  // Matomo-Consent synchronisieren (DSGVO: kein Tracking vor Consent)
  function syncMatomo() {
    if (!window._paq) return;
    var mode = "essential";
    try { mode = localStorage.getItem("klaro-consent") || "essential"; } catch (e) {}
    if (mode === "all") {
      window._paq.push(["setConsentGiven"]);
    } else {
      window._paq.push(["forgetConsentGiven"]);
    }
  }

  try {
    if (localStorage.getItem("klaro-consent")) {
      banner.style.display = "none";
      syncMatomo();
      return;
    }
  } catch (e) {}

  banner.addEventListener("click", function (ev) {
    var t = ev.target.closest("[data-klaro]");
    if (!t) return;
    try { localStorage.setItem("klaro-consent", t.getAttribute("data-klaro")); } catch (e) {}
    banner.style.display = "none";
    syncMatomo();
  });
})();