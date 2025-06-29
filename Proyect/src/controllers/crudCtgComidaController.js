import conexion from "../database/db.js";

// CREAR CATEGORÍA DE COMIDA
export const createCategoriaComida = async (req, res) => {
  const { descripcion } = req.body;

  try {
    await conexion.query("CALL CrearCategoriaComida(?)", [descripcion]);
    res.redirect("/staff-crud-categoriacomida");
  } catch (err) {
    console.error("Error al crear categoría:", err.message);
    res.status(500).send("Error al crear categoría");
  }
};

// LEER TODAS LAS CATEGORÍAS ACTIVAS
export const getCategoriasComida = async (req, res) => {
  try {
    const [rows] = await conexion.query("CALL LeerCategoriasComida()");
    const categoriasComida = rows[0];

    res.render("staff-crud-categoriacomida", {
      title: "Casa Andina",
      layout: "layouts/staff",
      categoriasComida, // <- asegúrate de pasar esto
    });
  } catch (err) {
    console.error("Error al obtener categorías de comida:", err.message);
    res.status(500).send("Error al obtener categorías de comida");
  }
};


// LEER CATEGORÍA POR ID
export const getCategoriaComidaById = async (req, res) => {
  const { id } = req.params;

  try {
    const [rows] = await conexion.query("CALL LeerCategoriaComidaPorID(?)", [id]);
    const categoriaComida = rows[0][0]; // Asegúrate de obtener el primer registro

    res.render("edit-categoriacomida", {
      title: "Casa Andina",
      layout: "layouts/staff",
      categoriaComida, // <-- ESTA LÍNEA ES CLAVE
    });
  } catch (err) {
    console.error("Error al obtener categoría de comida:", err.message);
    res.status(500).send("Error al obtener categoría de comida");
  }
};

// ACTUALIZAR CATEGORÍA
export const updateCategoriaComida = async (req, res) => {
  const { id } = req.params;
  const { descripcion } = req.body;

  try {
    await conexion.query("CALL ActualizarCategoriaComida(?, ?)", [id, descripcion]);
    res.redirect("/staff-crud-categoriacomida");
  } catch (err) {
    console.error("Error al actualizar categoría:", err.message);
    res.status(500).send("Error al actualizar categoría");
  }
};

// CAMBIAR ESTADO (ACTIVO/INACTIVO)
export const toggleEstadoCategoriaComida = async (req, res) => {
  const { id } = req.params;

  try {
    await conexion.query("CALL CambiarEstadoCategoriaComida(?)", [id]);
    res.redirect("/staff-crud-categoriacomida");
  } catch (err) {
    console.error("Error al cambiar estado:", err.message);
    res.status(500).send("Error al cambiar estado");
  }
};
