import conexion from "../database/db.js";
import fs from "fs";
import path, { join } from "path";

// CREAR TIPO HABITACIÓN
export const createTipoHabitacion = async (req, res) => {
  const { nombre, descripcion, tamano, cama, adultos, ninos, precio } =
    req.body;
  const imagen = req.file; // Si estás usando multer para manejar archivos

  try {
    const [rows] = await conexion.query(
      "CALL sp_registrar_tipohabitacion(?, ?, ?, ?, ?, ?, ?)",
      [nombre, descripcion, tamano, cama, adultos, ninos, precio]
    );

    const nuevoId = rows[0][0].nuevoId;

    if (imagen) {
      const dir = path.join(
        "src",
        "public",
        "img",
        "rooms",
        nuevoId.toString()
      );
      fs.mkdirSync(dir, { recursive: true }); // Crea la carpeta si no existe

      const ext = path.extname(imagen.originalname);
      const rutaDestino = path.join(dir, `1${ext}`);

      fs.renameSync(imagen.path, rutaDestino); // Mueve la imagen
    }

    res.redirect("/staff-crud-tipo-habitacion");
  } catch (err) {
    console.error("Error al registrar tipo de habitación:", err.message);
    res.status(500).send("Error al registrar tipo de habitación");
  }
};

// LEER TODOS LOS TIPOS DE HABITACIÓN
export const getTiposHabitacion = async (req, res) => {
  try {
    const [tipos] = await conexion.query("CALL sp_listar_tipohabitaciones()");
    res.render("staff-crud-tipo-habitacion", {
      title: "Tipos de Habitación",
      layout: "layouts/staff",
      tiposHabitacion: tipos[0],
    });
  } catch (err) {
    console.error("Error al obtener tipos de habitación:", err.message);
    res.status(500).send("Error interno");
  }
};

// LEER TIPO DE HABITACIÓN POR ID
export const getTipoHabitacionById = async (req, res) => {
  const { id } = req.params;

  try {
    const [rows] = await conexion.query(
      "CALL sp_obtener_tipohabitacion_por_id(?)",
      [id]
    );
    const tipoHabitacion = rows[0][0];

    res.render("edit-tipo-habitacion", {
      title: "Editar Tipo de Habitación",
      layout: "layouts/staff",
      tipoHabitacion,
    });
  } catch (err) {
    console.error("Error al obtener tipo de habitación:", err.message);
    res.status(500).send("Error al obtener tipo de habitación");
  }
};

// ACTUALIZAR TIPO DE HABITACIÓN
export const updateTipoHabitacion = async (req, res) => {
  const { id } = req.params;
  const { nombre, descripcion, tamano, cama, adultos, ninos, precio } = req.body;

  try {
    // Actualizar datos en BD
    await conexion.query(
      "CALL sp_actualizar_tipohabitacion(?, ?, ?, ?, ?, ?, ?, ?)",
      [id, nombre, descripcion, tamano, cama, adultos, ninos, precio]
    );

    // Si se subió una nueva imagen, reemplazar
    if (req.file) {
      const dirPath = join("src", "public", "img", "rooms", id);
      const imgPath = join(dirPath, "1.png");

      // Crear carpeta si no existe
      if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
      }

      // Mover la nueva imagen
      fs.renameSync(req.file.path, imgPath);
    }

    res.redirect("/staff-crud-tipo-habitacion");
  } catch (err) {
    console.error("Error al actualizar tipo de habitación:", err.message);
    res.status(500).send("Error al actualizar tipo de habitación");
  }
};

// FORMULARIO PARA REGISTRAR
export const renderFormCrearTipoHabitacion = (req, res) => {
  res.render("register-tipo-habitacion", {
    title: "Registrar Tipo de Habitación",
    layout: "layouts/staff",
  });
};
