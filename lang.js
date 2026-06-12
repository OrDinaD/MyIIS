function setLang(lang) {
  document.querySelectorAll("[data-lang]").forEach((el) => {
    el.classList.toggle("hidden", el.getAttribute("data-lang") !== lang);
  });

  document.querySelectorAll(".lang-btn").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.targetLang === lang);
  });

  localStorage.setItem("myiis_lang", lang);
}

document.addEventListener("DOMContentLoaded", () => {
  const preferred = localStorage.getItem("myiis_lang") || "ru";
  setLang(preferred);

  document.querySelectorAll(".lang-btn").forEach((btn) => {
    btn.addEventListener("click", () => setLang(btn.dataset.targetLang));
  });
});
