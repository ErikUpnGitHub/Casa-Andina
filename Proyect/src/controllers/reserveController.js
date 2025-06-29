import conexion from "../database/db.js";

export const getAvailableRoomTypes = async (req, res) => {
  const { adultos, ninos } = req.query;

  try {
    const [tipos] = await conexion.execute(
      "CALL obtener_tipos_habitacion_disponibles(?, ?)",
      [adultos, ninos]
    );
    const tiposHabitacion = tipos[0];

    res.render("reserveStep2", {
      title: "Casa Andina",
      layout: "layouts/main",
      adultos,
      ninos,
      tiposHabitacion,
    });
  } catch (error) {
    console.error("Error al obtener tipos de habitación:", error);
    res.status(500).send("Error del servidor");
  }
};

export const getReserveStep3 = async (req, res) => {
  const { idTipoHbt, adultos, ninos } = req.query;

  try {
    const [diasOcupacionTotal] = await conexion.execute(
      "CALL obtener_dias_ocupacion_total(?)",
      [idTipoHbt]
    );
    const [checkoutsOcupacionTotal] = await conexion.execute(
      "CALL obtener_checkouts_ocupacion_total(?)",
      [idTipoHbt]
    );

    res.render("reserveStep3", {
      title: "Casa Andina",
      layout: "layouts/main",
      idTipoHbt,
      adultos,
      ninos,
      checkinDisponible: diasOcupacionTotal[0],
      checkoutDisponible: checkoutsOcupacionTotal[0],
    });
  } catch (error) {
    console.error("Error al obtener datos para Step 3:", error);
    res.status(500).send("Error del servidor");
  }
};

export const getReserveStep4 = async (req, res) => {
  const { idTipoHbt, adultos, ninos, fechaEntrada, fechaSalida } = req.query;

  try {
    const [resultado] = await conexion.execute(
      "CALL calcular_monto_total(?, ?, ?)",
      [idTipoHbt, fechaEntrada, fechaSalida]
    );

    const montoTotal = parseFloat(resultado[0][0]?.monto_total) || 0;

    console.log("Sesión idUsuario:", req.session.idUsuario);

    const [resultadoHabitacion] = await conexion.execute(
      "CALL obtener_tipo_habitacion(?)",
      [idTipoHbt]
    );

    const tipoHabitacion = resultadoHabitacion[0][0];

    res.render("reserveStep4", {
      title: "Casa Andina",
      layout: "layouts/main",
      idTipoHbt,
      adultos,
      ninos,
      fechaEntrada,
      fechaSalida,
      montoTotal,
      tipoHabitacion,
    });
  } catch (error) {
    console.error("Error al calcular monto total:", error);
    res.status(500).send("Error del servidor");
  }
};

// POST para crear la reserva
export const postReserveStep5 = async (req, res) => {
  console.log("Datos recibidos en postReserveStep5:", req.body);
  const { idUsuario, idTipoHbt, fechaEntrada, fechaSalida } = req.body;

  try {
    await conexion.execute("CALL sp_reservar_habitacion(?, ?, ?, ?)", [
      idUsuario,
      idTipoHbt,
      fechaEntrada,
      fechaSalida,
    ]);

    res.redirect(
      `/reserveStep5?status=success&idUsuario=${idUsuario}&idTipoHbt=${idTipoHbt}&fechaEntrada=${fechaEntrada}&fechaSalida=${fechaSalida}`
    );
  } catch (error) {
    console.error("Error al registrar la reserva:", error);
    res.status(500).send("Error al procesar la reserva");
  }
};

// GET para mostrar confirmación
export const getReserveStep5 = (req, res) => {
  const { idUsuario, idTipoHbt, fechaEntrada, fechaSalida, status } = req.query;

  res.render("reserveStep5", {
    title: "Casa Andina",
    layout: "layouts/main",
    idUsuario,
    idTipoHbt,
    fechaEntrada,
    fechaSalida,
    status,
  });
};

