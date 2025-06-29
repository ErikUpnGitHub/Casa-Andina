import conexion from "../database/db.js";

export const getActiveServiceCategories = async (req, res) => {
  try {
    const [categorias] = await conexion.execute(
      "CALL listarCategoriasServicioActivas()"
    );
    const categoriasActivas = categorias[0];
    res.render("services", {
      title: "Casa Andina",
      layout: "layouts/main",
      categorias: categoriasActivas,
    });
  } catch (error) {
    console.error("Error al obtener categorías activas:", error);
    res.status(500).send("Error del servidor");
  }
};

export const postInsertarServicio = async (req, res) => {
  const { idCtgServicio } = req.body;
  const idUsuario = req.session.idUsuario;

  console.log("ID de usuario en sesión:", idUsuario);

  if (!idUsuario) {
    return res.redirect("/login");
  }

  try {
    await conexion.execute("CALL insertarServicio(?, ?)", [
      idUsuario,
      idCtgServicio,
    ]);

    res.redirect(
      `/register-service-request?status=success&idUsuario=${idUsuario}&idCtgServicio=${idCtgServicio}`
    );
  } catch (error) {
    console.error("Error al insertar el servicio:", error.message);
    res.status(500).send("Error al registrar el servicio");
  }
};

// GET para mostrar la confirmación de la solicitud del servicio
export const getRegistrarSolicitud = (req, res) => {
  const { idUsuario, idCtgServicio, status } = req.query;

  res.render("register-service-request", {
    title: "Casa Andina",
    layout: "layouts/main",
    idUsuario,
    idCtgServicio,
    status,
  });
};

export const postSuccessfulFood = async (req, res) => {
  const { idCtgServicio, carrito } = req.body;
  const idUsuario = req.session.idUsuario;

  if (!idUsuario) {
    return res.redirect("/login");
  }

  try {
    const productosCarrito = JSON.parse(carrito);

    // Ejecutar procedimiento y obtener resultado
    const [rows] = await conexion.execute("CALL insertarServicio(?, ?)", [
      idUsuario,
      idCtgServicio,
    ]);

    const idServicioInsertado = rows[0][0].idServicio;

    console.log("ID servicio insertado:", idServicioInsertado);

    if (!idServicioInsertado) {
      throw new Error("No se pudo obtener idServicio insertado");
    }

    // Insertar productos en serviciocomida
    for (const item of productosCarrito) {
      await conexion.execute("CALL insertarServicioComida(?, ?, ?, ?)", [
        item.id,
        idServicioInsertado,
        item.cantidad,
        item.precio,
      ]);
    }

    res.redirect(
      `/register-service-request?status=success&idUsuario=${idUsuario}&idCtgServicio=${idCtgServicio}&idServicio=${idServicioInsertado}`
    );
  } catch (error) {
    console.error("Error al procesar compra:", error);
    res.status(500).send("Error al procesar la compra");
  }
};

export const getClientRequestData = async (req, res) => {
  const idUsuario = req.session.idUsuario;

  if (!idUsuario) {
    return res.redirect("login");
  }

  try {
    const [results] = await conexion.query("CALL obtenerDatosCliente(?)", [
      idUsuario,
    ]);

    const reservas = results[0];
    const servicios = results[1];
    const inscripciones = results[2];
    const productosComida = results[3];

    servicios.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

    res.render("request", {
      title: "Casa Andina",
      layout: "layouts/main",
      reservas,
      servicios,
      inscripciones,
      productosComida,
    });
  } catch (error) {
    console.error("Error al obtener datos del cliente:", error);
    res.status(500).send("Error al obtener la información del cliente");
  }
};

export const getRegistrarResenia = (req, res) => {
  const { idServicio } = req.params;
  const idUsuario = req.session.idUsuario;

  if (!idUsuario) {
    return res.redirect("/login");
  }

  res.render("registrar-resenia", {
    title: "Casa Andina",
    layout: "layouts/main",
    idServicio,
  });
};

export const postRegistrarResenia = async (req, res) => {
  const { idServicio, calificacion, comentario } = req.body;
  const idUsuario = req.session.idUsuario;

  if (!idUsuario) {
    return res.redirect("/login");
  }

  try {
    const [reseniaResult] = await conexion.execute(
      "CALL sp_buscar_resenia_por_idServicio(?)",
      [idServicio]
    );
    const reseñaExistente = reseniaResult[0].length > 0;

    if (reseñaExistente) {
      // Editar reseña existente
      await conexion.execute("CALL sp_editar_resenia(?, ?, ?)", [
        idServicio,
        calificacion,
        comentario,
      ]);
    } else {
      // Registrar nueva reseña
      await conexion.execute("CALL sp_registrar_resenia(?, ?, ?)", [
        idServicio,
        calificacion,
        comentario,
      ]);
    }

    res.redirect("/request?status=resenia_success");
  } catch (error) {
    console.error("Error al registrar o editar reseña:", error);
    res.status(500).send("Error al procesar la reseña");
  }
};
