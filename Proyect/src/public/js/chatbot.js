let isChatOpen = false;

function toggleChatbox() {
  const chatbox = document.getElementById("chatbox");
  isChatOpen = !isChatOpen;
  chatbox.style.display = isChatOpen ? "block" : "none";
}

function sendMessage() {
  const input = document.getElementById("userInput");
  const message = input.value.trim();
  if (!message) return;

  showMessage("user", message);

  fetch("/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message })
  })
    .then(res => res.json())
    .then(data => {
      if (!data || !data.text) {
        showMessage("bot", "⚠ Error: no se pudo obtener una respuesta.");
        return;
      }

      let botText = data.text;
      if (data.link) {
        botText += `<br><a href="${data.link}" class="chat-link">Ir ahora</a>`;
      }

      showMessage("bot", botText);
      input.value = "";
    })
    .catch(err => {
      showMessage("bot", "❌ Ocurrió un error al enviar tu mensaje.");
      console.error(err);
    });
}

function showMessage(sender, text) {
  const messages = document.getElementById("messages");
  const div = document.createElement("div");
  div.className = "msg " + sender;
  div.innerHTML = text;
  messages.appendChild(div);
  messages.scrollTop = messages.scrollHeight;
}

document.addEventListener("DOMContentLoaded", function () {
  document.getElementById("sendBtn").addEventListener("click", sendMessage);
  document.getElementById("userInput").addEventListener("keypress", function (e) {
    if (e.key === "Enter") {
      e.preventDefault();
      sendMessage();
    }
  });
});
