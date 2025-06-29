function getLangFromURL() {
  const params = new URLSearchParams(window.location.search);
  return params.get("lang") || "es";
}

const lang = getLangFromURL();

const body = document.querySelector("body"),
  sidebar = body.querySelector(".sidebar"),
  toggle = body.querySelector(".toggle"),
  modeSwitch = body.querySelector(".toggle-switch"),
  modeText = body.querySelector(".mode-text");

// Aplica el modo guardado al cargar
const savedMode = localStorage.getItem("mode");
if (savedMode === "dark") {
  body.classList.add("dark");
  if (modeText) modeText.innerText = darkmodeText;
} else {
  body.classList.remove("dark");
  if (modeText) modeText.innerText = lightmodeText;
}

if (modeSwitch && body && modeText && darkmodeText && lightmodeText) {
  modeSwitch.addEventListener("click", () => {
    body.classList.toggle("dark");

    if (body.classList.contains("dark")) {
      modeText.innerText = darkmodeText;
      localStorage.setItem("mode", "dark");
    } else {
      modeText.innerText = lightmodeText;
      localStorage.setItem("mode", "light");
    }
  });
}


if (toggle && sidebar) {
  toggle.addEventListener("click", () => {
    sidebar.classList.toggle("close");
  });
} else {
  //console.log('Toggle Sidebar : Elementos necesarios no definidos');
}

document.addEventListener("DOMContentLoaded", async () => {
  const select = document.getElementById("nationality");

  const langMap = {
    es: "spa",
    en: "eng",
  };

  // Usa la función para obtener el idioma actual de la URL
  const currentLang = getLangFromURL();

  const lang = langMap[currentLang] || "eng";

  console.log("Lang para API:", lang);

  try {
    const response = await fetch("https://restcountries.com/v3.1/all?fields=name,translations");
    const countries = await response.json();

    select.innerHTML =
      '<option value="">' +
      (currentLang === "es"
        ? "Seleccione una nacionalidad"
        : "Select a nationality") +
      "</option>";

    countries.sort((a, b) => {
      const nameA = a.translations?.[lang]?.common || a.name.common;
      const nameB = b.translations?.[lang]?.common || b.name.common;
      return nameA.localeCompare(nameB);
    });

    countries.forEach((country) => {
      const name = country.translations?.[lang]?.common || country.name.common;
      const option = document.createElement("option");
      option.value = name;
      option.textContent = name;
      select.appendChild(option);
    });
  } catch (error) {
    console.error("Error al cargar países:", error);
    select.innerHTML =
      '<option value="">' +
      (currentLang === "es" ? "Error al cargar" : "Error loading") +
      "</option>";
  }
});



document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("a[data-link]").forEach((link) => {
    link.addEventListener("click", async (e) => {
      e.preventDefault();
      const url = new URL(link.getAttribute("href"), window.location.origin);
      url.searchParams.set("lang", lang);
      const res = await fetch(url.toString());
      const html = await res.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");
      const newContent = doc.querySelector("#main-content");
      document.querySelector("#main-content").innerHTML = newContent.innerHTML;
      history.pushState(null, "", url);
    });
  });
});

const input = document.querySelector("#phone");
const iti = window.intlTelInput(input, {
  initialCountry: "auto",
  preferredCountries: ["pe", "es", "us", "mx", "co"],
  separateDialCode: true,
  utilsScript:
    "https://cdnjs.cloudflare.com/ajax/libs/intl-tel-input/17.0.19/js/utils.js",
  geoIpLookup: function (callback) {
    fetch("https://ipapi.co/json")
      .then((res) => res.json())
      .then((data) => callback(data.country_code))
      .catch(() => callback("us"));
  },
});

document.querySelector("form").addEventListener("submit", function () {
  input.value = iti.getNumber();
});

