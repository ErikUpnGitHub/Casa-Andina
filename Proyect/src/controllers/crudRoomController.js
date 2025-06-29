import conexion from "../database/db.js";

// LISTAR HABITACIONES
export const getHabitaciones = async (req, res) => {
  try {
    const [rows] = await conexion.query("CALL sp_listar_habitaciones()");
    res.render("staff-crud-habitacion", {
      title: "Casa Andina",
      layout: "layouts/staff",
      habitaciones: rows[0],
    });
  } catch (err) {
    console.error("Error al obtener habitaciones:", err.message);
    res.status(500).send("Error interno");
  }
};

// FORMULARIO REGISTRO
export const renderFormCrearHabitacion = async (req, res) => {
  try {
    const [tipos] = await conexion.query("CALL sp_listar_tipohabitaciones()");
    res.render("register-habitacion", {
      title: "Casa Andina",
      layout: "layouts/staff",
      tiposHabitacion: tipos[0],
    });
  } catch (err) {
    console.error("Error al cargar formulario:", err.message);
    res.status(500).send("Error interno");
  }
};

// CREAR HABITACIÓN
export const createHabitacion = async (req, res) => {
  const { idTipoHbt, numero, estado } = req.body;

  try {
    await conexion.query("CALL sp_registrar_habitacion(?, ?, ?)", [
      idTipoHbt,
      numero,
      estado,
    ]);
    res.redirect("/staff-crud-habitacion");
  } catch (err) {
    console.error("Error al registrar habitación:", err.message);
    res.status(500).send("Error al registrar habitación");
  }
};

// FORMULARIO EDICIÓN
export const getHabitacionById = async (req, res) => {
  const { id } = req.params;

  try {
    const [habitacionRows] = await conexion.query("CALL sp_obtener_habitacion_por_id(?)", [id]);
    const habitacion = habitacionRows[0][0];

    const [tiposRows] = await conexion.query("CALL sp_listar_tipohabitaciones()");
    const tiposHabitacion = tiposRows[0];

    res.render("edit-habitacion", {
      title: "Casa Andina",
      layout: "layouts/staff",
      habitacion,
      tiposHabitacion,
    });
  } catch (err) {
    console.error("Error al obtener habitación:", err.message);
    res.status(500).send("Error al obtener habitación");
  }
};


// ACTUALIZAR HABITACIÓN
export const updateHabitacion = async (req, res) => {
  const { id } = req.params;
  const { idTipoHbt, numero, estado } = req.body;

  try {
    await conexion.query("CALL sp_actualizar_habitacion(?, ?, ?, ?)", [
      id,
      idTipoHbt,
      numero,
      estado,
    ]);
    res.redirect("/staff-crud-habitacion");
  } catch (err) {
    console.error("Error al actualizar habitación:", err.message);
    res.status(500).send("Error al actualizar habitación");
  }
};

// CAMBIAR ESTADO
export const cambiarEstadoHabitacion = async (req, res) => {
  const { id } = req.params;
  const { nuevoEstado } = req.body;

  try {
    await conexion.query("CALL sp_cambiar_estado_habitacion(?, ?)", [id, nuevoEstado]);
    res.redirect("/staff-crud-habitacion");
  } catch (err) {
    console.error("Error al cambiar estado:", err.message);
    res.status(500).send("Error al cambiar estado de habitación");
  }
};
