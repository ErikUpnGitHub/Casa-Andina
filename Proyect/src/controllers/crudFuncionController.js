import conexion from "../database/db.js";

// CREAR FUNCIÓN
export const createFuncion = async (req, res) => {
  const { detalle } = req.body;

  try {
    await conexion.query("CALL CrearFuncion(?)", [detalle]);
    res.redirect("/staff-crud-funcion");
  } catch (err) {
    console.error("Error al crear función:", err.message);
    res.status(500).send("Error al crear función");
  }
};

// LEER TODAS LAS FUNCIONES
export const getFunciones = async (req, res) => {
  try {
    const [rows] = await conexion.query("CALL LeerFunciones()");
    const funciones = rows[0];

    res.render("staff-crud-funcion", {
      title: "Casa Andina",
      layout: "layouts/staff", // Ajusta si usas otro layout
      funciones,
    });
  } catch (err) {
    console.error("Error al obtener funciones:", err.message);
    res.status(500).send("Error al obtener funciones");
  }
};

// LEER UNA FUNCIÓN POR ID
export const getFuncionById = async (req, res) => {
  const { id } = req.params;

  try {
    const [rows] = await conexion.query("CALL LeerFuncionPorID(?)", [id]);
    const funcion = rows[0][0];

    res.render("edit-funcion", {
      title: "Casa Andina",
      layout: "layouts/staff",
      funcion,
    });
  } catch (err) {
    console.error("Error al obtener función:", err.message);
    res.status(500).send("Error al obtener función");
  }
};

// ACTUALIZAR FUNCIÓN
export const updateFuncion = async (req, res) => {
  const { id } = req.params;
  const { detalle } = req.body;

  try {
    await conexion.query("CALL ActualizarFuncion(?, ?)", [id, detalle]);
    res.redirect("/staff-crud-funcion");
  } catch (err) {
    console.error("Error al actualizar función:", err.message);
    res.status(500).send("Error al actualizar función");
  }
};

// ELIMINAR FUNCIÓN
export const deleteFuncion = async (req, res) => {
  const { id } = req.params;

  try {
    await conexion.query("CALL EliminarFuncion(?)", [id]);
    res.redirect("/staff-crud-funcion");
  } catch (err) {
    console.error("Error al eliminar función:", err.message);
    res.status(500).send("Error al eliminar función");
  }
};
