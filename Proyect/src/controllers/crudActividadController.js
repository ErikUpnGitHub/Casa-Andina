import conexion from "../database/db.js";
import fs from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// LISTAR ACTIVIDADES
export const getActividades = async (req, res) => {
  try {
    const [actividades] = await conexion.query("CALL sp_listar_actividades()");
    res.render("staff-crud-actividad", {
      title: "Casa Andina",
      layout: "layouts/staff",
      actividades: actividades[0],
    });
  } catch (err) {
    console.error("Error al obtener actividades:", err.message);
    res.status(500).send("Error al obtener actividades");
  }
};

// FORMULARIO DE REGISTRO
export const renderFormCrearActividad = (req, res) => {
  res.render("register-actividad", {
    title: "Casa Andina",
    layout: "layouts/staff",
  });
};

// CREAR ACTIVIDAD
export const createActividad = async (req, res) => {
  const { detalle, descripcion, duracion, precio } = req.body;

  try {
    const [rows] = await conexion.query(
      "CALL sp_registrar_actividad(?, ?, ?, ?)",
      [detalle, descripcion, duracion, precio]
    );

    const nuevoId = rows[0][0].nuevoId;

    // Guardar imagen si se subió
    if (req.file) {
      const rutaDestino = join(__dirname, "../public/img/activity", `${nuevoId}.png`);
      fs.renameSync(req.file.path, rutaDestino);
    }

    res.redirect("/staff-crud-actividad");
  } catch (err) {
    console.error("Error al registrar actividad:", err.message);
    res.status(500).send("Error al registrar actividad");
  }
};

// FORMULARIO DE EDICIÓN
export const getActividadById = async (req, res) => {
  const { id } = req.params;

  try {
    const [actividadData] = await conexion.query("CALL sp_obtener_actividad_por_id(?)", [id]);
    res.render("edit-actividad", {
      title: "Casa Andina",
      layout: "layouts/staff",
      actividad: actividadData[0][0],
    });
  } catch (err) {
    console.error("Error al obtener actividad:", err.message);
    res.status(500).send("Error al obtener actividad");
  }
};

// ACTUALIZAR ACTIVIDAD
export const updateActividad = async (req, res) => {
  const { id } = req.params;
  const { detalle, descripcion, duracion, precio } = req.body;

  try {
    await conexion.query("CALL sp_actualizar_actividad(?, ?, ?, ?, ?)", [
      id,
      detalle,
      descripcion,
      duracion,
      precio,
    ]);

    if (req.file) {
      const rutaDestino = join(__dirname, "../public/img/activity", `${id}.png`);
      fs.renameSync(req.file.path, rutaDestino);
    }

    res.redirect("/staff-crud-actividad");
  } catch (err) {
    console.error("Error al actualizar actividad:", err.message);
    res.status(500).send("Error al actualizar actividad");
  }
};

// CAMBIAR ESTADO
export const toggleEstadoActividad = async (req, res) => {
  const { id } = req.params;

  try {
    await conexion.query("CALL sp_cambiar_estado_actividad(?)", [id]);
    res.redirect("/staff-crud-actividad");
  } catch (err) {
    console.error("Error al cambiar estado:", err.message);
    res.status(500).send("Error al cambiar estado de la actividad");
  }
};

// Mostrar formulario
export const renderFormEvento = (req, res) => {
  const { id } = req.params;
  res.render("configurar-evento", {
    title: "Configurar Evento",
    layout: "layouts/staff",
    idActividad: id,
  });
};

// Crear o actualizar evento
export const crearOActualizarEvento = async (req, res) => {
  const { id } = req.params;
  const { horaInicio, horaFin, duracion } = req.body;

  try {
    const nombreEvento = `generar_horario_id${id}`;
    const hoy = new Date().toISOString().split("T")[0];

    const sql = `
      CREATE EVENT IF NOT EXISTS ${nombreEvento}
      ON SCHEDULE EVERY 1 DAY
      STARTS '${hoy} ${horaInicio}'
      ON COMPLETION PRESERVE
      DO
        CALL GenerarHorariosDiarios(${id}, 5, CURDATE(), '${horaInicio}', '${horaFin}', ${duracion});
    `;

    await conexion.query(`DROP EVENT IF EXISTS ${nombreEvento}`);
    await conexion.query(sql);

    res.redirect("/staff-crud-actividad");
  } catch (err) {
    console.error("Error configurando evento:", err.message);
    res.status(500).send("Error configurando evento");
  }
};
