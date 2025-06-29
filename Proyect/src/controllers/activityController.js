import db from "../database/db.js";

export const listActivities = async (req, res) => {
  try {
    const [rows] = await db.query("CALL ListarActividades()");
    const activities = rows[0];

    res.render("activity", {
      title: "Casa Andina",
      layout: "layouts/main",
      activities,
    });
  } catch (err) {
    console.error("Error al listar actividades:", err.message, err);
    res.status(500).send("Error al obtener actividades");
  }
};

export const showActivitySchedule = async (req, res) => {
  const idActividad = req.params.id;

  try {
    // Llamada a actividad y horarios
    const [actividadResult] = await db.query("CALL ObtenerActividadPorID(?)", [
      idActividad,
    ]);
    const [horariosResult] = await db.query(
      "CALL ObtenerHorariosHoyPorActividad(?)",
      [idActividad]
    );

    const actividad = actividadResult[0][0];
    const horarios = horariosResult[0];

    // Para cada horario, obtener cupos restantes
    const horariosConCupos = await Promise.all(
      horarios.map(async (horario) => {
        const [cuposResult] = await db.query("CALL obtenerCuposRestantes(?)", [
          horario.idHraActividad,
        ]);
        const cuposRestantes = cuposResult[0][0].cuposRestantes;
        return { ...horario, cuposRestantes };
      })
    );

    // Renderizar con cupos incluidos
    res.render("activity-schedule", {
      title: "Casa Andina",
      layout: "layouts/main",
      actividad,
      horarios: horariosConCupos,
    });
  } catch (err) {
    console.error("Error al obtener horarios:", err.message, err);
    res.status(500).send("Error al cargar los horarios de la actividad");
  }
};

export const registrarInscripcion = async (req, res) => {
  const { idHraActividad, cantidad } = req.body;
  const idCliente = req.session.idUsuario;

  console.log('ID de usuario en sesión:', req.session.idUsuario);

  if (!idCliente) {
    return res.redirect("/login"); // Asegúrate de que haya sesión
  }

  try {
    let exitosas = 0;

    for (let i = 0; i < cantidad; i++) {
      const [resultado] = await db.query("CALL insertarInscripcion(?, ?)", [
        idHraActividad,
        idCliente,
      ]);
      const insercion = resultado[0][0]?.insercionExitosa;

      if (insercion === 1) exitosas++;
    }

    if (exitosas === 0) {
      return res.send(
        "No se pudo registrar ninguna inscripción. Verifica los cupos disponibles."
      );
    }

    res.redirect("/activity-inscription");
  } catch (error) {
    console.error("Error al registrar inscripción:", error.message);
    res.status(500).send("Error al procesar la inscripción");
  }
};

export const mostrarInscripcionExitosa = (req, res) => {
  res.render('activity-inscription', {
    title: 'Inscripción confirmada',
    layout: 'layouts/main',
  });
};
