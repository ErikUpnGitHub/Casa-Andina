import conexion from "../database/db.js";

export const renderDashboard = async (req, res) => {
  try {
    const [
      [habitaciones],
      [clientes],
      [servicios],
      [empleados],
      [productos],
      [horarios],
      [inscripciones],
      [reservas],
    ] = await Promise.all([
      conexion.query("SELECT * FROM vista_estado_habitaciones"),
      conexion.query("SELECT * FROM vista_resumen_clientes"),
      conexion.query("SELECT * FROM vista_servicios_estado_categoria"),
      conexion.query("SELECT * FROM vista_empleados_funcion"),
      conexion.query("SELECT * FROM vista_productos_categoria"),
      conexion.query("SELECT * FROM vista_horarioactividad_estado_hoy"),
      conexion.query("SELECT * FROM vista_inscripciones_estado"),
      conexion.query("SELECT * FROM vista_reservas_estado_fecha"),
    ]);

    //console.log("habitaciones:", habitaciones);
    //console.log("Es array?", Array.isArray(habitaciones));

    res.render("staff-dashboard", {
      title: "Dashboard - Casa Andina",
      layout: "layouts/staff",
      habitaciones,
      clientes,
      servicios,
      empleados,
      productos,
      horarios,
      inscripciones,
      reservas,
    });
  } catch (error) {
    console.error("Error al cargar el dashboard:", error);
    res.status(500).render("error", {
      message: "Ocurrió un error al cargar el panel",
      error,
    });
  }
};
