import conexion from "../database/db.js";

export const getServiciosAsignados = async (req, res) => {
  const idUsuario = req.session.idUsuario;
  const roleId = req.session.rol?.id;
  const allowedRoleIds = [3, 4, 5, 6, 7];

  if (!idUsuario) {
    return res.redirect("/login");
  }

  if (!allowedRoleIds.includes(roleId)) {
    return res.render("access-denied", {
      title: "Casa Andina",
      layout: "layouts/staff",
      locale: req.getLocale(),
    });
  }

  try {
    const [results] = await conexion.query("CALL ObtenerServiciosPorCuenta(?)", [
      idUsuario,
    ]);

    const serviciosAsignados = results[0] || [];
    const productosComida = results[1] || [];

    res.render("staff-task", {
      title: "Casa Andina",
      layout: "layouts/staff",
      locale: req.getLocale(),
      servicios: serviciosAsignados,
      productosComida: productosComida,
    });
  } catch (error) {
    console.error("Error al obtener servicios asignados:", error);
    res.status(500).send("Error al obtener los servicios asignados");
  }
};

export const cambiarEstadoServicio = async (req, res) => {
  const { idServicio, nuevoEstado } = req.body;

  try {
    await conexion.query("CALL CambiarEstadoServicio(?, ?)", [idServicio, nuevoEstado]);
    res.status(200).json({ mensaje: "Estado actualizado correctamente." });
  } catch (error) {
    console.error("Error al cambiar estado del servicio:", error);
    res.status(500).json({ mensaje: "Error al cambiar estado del servicio." });
  }
};
