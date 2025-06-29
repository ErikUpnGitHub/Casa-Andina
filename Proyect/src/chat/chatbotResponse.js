import fs from 'fs';
import path from 'path';

const __dirname = path.resolve();
const intentsPath = path.join(__dirname, 'src', 'chat', 'intents.json');
const intents = JSON.parse(fs.readFileSync(intentsPath, 'utf-8'));

function cleanText(text) {
  return text.toLowerCase().replace(/[^\w\s]/gi, '');
}

export function getResponse(userInput) {
  const cleanedInput = cleanText(userInput);

  for (const intent of intents.intents) {
    for (const pattern of intent.patterns) {
      if (cleanedInput.includes(cleanText(pattern))) {
        const response = intent.responses[Math.floor(Math.random() * intent.responses.length)];

        if (intent.tag === "reserva") {
          return {
            text: response,
            link: "/reserveStep1"
          };
        }
        if (intent.tag === "ordenar_comida") {
          return {
            text: response,
            link: "/order-food"
          };
        }
        if (intent.tag === "actividad") {
          return {
            text: response,
            link: "/activity"
          };
        }
        if (intent.tag === "servicio") {
          return {
            text: response,
            link: "/services"
          };
        }

        return { text: response };
      }
    }
  }

  return { text: "Lo siento, no entendí eso. ¿Podrías repetirlo?" };
}