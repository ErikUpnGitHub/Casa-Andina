import dotenv from "dotenv";
import express from "express";
import session from "express-session";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import expressLayouts from "express-ejs-layouts";
import i18n from "i18n";
import cookieParser from "cookie-parser";
import indexRoutes from "./routes/index.js";
import { getResponse } from './chat/chatbotResponse.js';

dotenv.config();

const app = express();
const __dirname = dirname(fileURLToPath(import.meta.url));

// VIEWS
app.set("views", join(__dirname, "views"));
app.set("view engine", "ejs");

// LAYOUT
app.use(expressLayouts);
app.set("layout", join("layouts", "main"));

// LANGUAGE
i18n.configure({
  locales: ["en", "es"],
  directory: join(__dirname, "locales"),
  defaultLocale: "en",
  //queryParameter: "lang",
  cookie: "locale",
  autoReload: true,
  syncFiles: true,
});

app.use(i18n.init);

app.use(cookieParser());

app.use(
  session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false,
    cookie: {
      maxAge: 1000 * 60 * 60,
    },
  })
);

// MIDDLEWARE
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(i18n.init);

app.use((req, res, next) => {
  res.locals.__ = res.__;
  res.locals.idUsuario = req.session.idUsuario;
  res.locals.rolUsuario = req.session.rol || { id: null, nombre: "invitado" };
  res.locals.locale = req.getLocale();
  res.locals.js = {
    darkmode: res.__("sb-mode-dark"),
    lightmode: res.__("sb-mode-light"),
  };
  next();
});

// CHATBOT
app.post('/chat', (req, res) => {
  const { message } = req.body;
  const response = getResponse(message);
  res.json(response);
});

// ROUTES
app.use(indexRoutes);

// STATIC FILES
app.use(express.static(join(__dirname, "public")));

app.listen(3000);
