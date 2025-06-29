import bcrypt from "bcrypt";
import db from "../database/db.js";

// REGISTRAR USUARIO
export const registerUser = async (req, res) => {
  const {
    firstName,
    lastName,
    email,
    password,
    confirmPassword,
    phone,
    docNumber,
    nationality,
  } = req.body;

  const docType = req.body.docType;

  if (password !== confirmPassword) {
    const [rows] = await db.query("CALL sp_get_tipo_documento()");
    const docTypes = rows[0];

    return res.render("register", {
      title: "Casa Andina",
      layout: "layouts/access",
      locale: req.getLocale(),
      docTypes,
      error: "Las contraseñas no coinciden",
    });
  }

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const connection = await db;

    const sql = `CALL sp_registrar_cliente_usuario(?, ?, ?, ?, ?, ?, ?, ?)`;

    await connection.query(sql, [
      firstName,
      lastName,
      email,
      phone,
      docType,
      docNumber,
      nationality,
      hashedPassword,
    ]);

    res.redirect("/login?success=Usuario registrado correctamente");
  } catch (err) {
    console.error("Error detallado:", err.message, err);

    const [rows] = await db.query("CALL sp_get_tipo_documento()");
    const docTypes = rows[0];

    res.render("register", {
      title: "Casa Andina",
      layout: "layouts/access",
      locale: req.getLocale(),
      docTypes,
      error: "Error al registrar usuario y cliente",
    });
  }
};


// INICIAR SESION
export const loginUser = async (req, res) => {
  const { email, password } = req.body;

  try {
    const [results] = await db.query("CALL sp_login_usuario(?)", [email]);

    const cliente = results[0][0];
    const empleado = results[1][0];
    const user = cliente || empleado;

    if (!user) {
      return res.render("login", {
        title: "Casa Andina",
        layout: "layouts/access",
        locale: req.getLocale(),
        error: "Usuario no encontrado o inactivo",
      });
    }

    if (user.tipo === "cliente") {
      const match = await bcrypt.compare(password, user.contrasenia);
      if (!match) {
        return res.render("login", {
          title: "Casa Andina",
          layout: "layouts/access",
          locale: req.getLocale(),
          error: "Contraseña incorrecta",
        });
      }
    } else if (user.tipo === "empleado") {
      if (password !== user.contrasenia) {
        return res.render("login", {
          title: "Casa Andina",
          layout: "layouts/access",
          locale: req.getLocale(),
          error: "Contraseña incorrecta",
        });
      }
    }

    req.session.idUsuario = user.idCuenta;
    req.session.tipoUsuario = user.tipo;

    if (user.tipo === "empleado") {
      const [funcionResults] = await db.query(
        "CALL ObtenerFuncionPorCuenta(?)",
        [user.idCuenta]
      );
      const funcion = funcionResults[0][0];

      if (funcion) {
        req.session.rol = {
          id: funcion.idFuncion,
          nombre: funcion.detalle,
        };
        console.log("Rol guardado en sesión:", req.session.rol);
      }

      return res.redirect("/staff-home");
    } else {
      return res.redirect("/home");
    }
  } catch (err) {
    console.error("Error en login:", err.message, err);
    res.render("login", {
      title: "Casa Andina",
      layout: "layouts/access",
      locale: req.getLocale(),
      error: "Error interno del servidor",
    });
  }
};


// OBTENER TIPOS DE DOCUMENTO
export const getDocType = async (req, res) => {
  try {
    const [rows] = await db.query("CALL sp_get_tipo_documento()");
    const docTypes = rows[0];

    res.render("register", {
      title: "Casa Andina",
      layout: "layouts/access",
      locale: req.getLocale(),
      docTypes,
    });
  } catch (err) {
    console.error("Error obteniendo tipos de documento:", err.message);
    res.status(500).send("Error al cargar tipos de documento");
  }
};
