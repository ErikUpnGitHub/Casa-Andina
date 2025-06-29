import conexion from "../database/db.js";
import fs from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// CREAR CATEGORÍA DE SERVICIO
export const createCategoriaServicio = async (req, res) => {
  const { detalle, descripcion, precio } = req.body;

  try {
    const [result] = await conexion.query(
      "CALL sp_registrar_categoriaservicio(?, ?, ?)",
      [detalle, descripcion, precio]
    );

    const nuevoId = result[0][0].nuevoId;

    if (req.file) {
      const tempPath = req.file.path;
      const targetPath = join(__dirname, "../public/img/category-service", `${nuevoId}.png`);
      fs.renameSync(tempPath, targetPath);
    }

    res.redirect("/staff-crud-categoriaservicio");
  } catch (err) {
    console.error("Error al registrar categoría:", err.message);
    res.status(500).send("Error al registrar categoría");
  }
};

// LISTAR CATEGORÍAS DE SERVICIO
export const getCategoriasServicio = async (req, res) => {
  try {
    const [categorias] = await conexion.query("CALL sp_listar_categoriaservicio()");
    res.render("staff-crud-categoriaservicio", {
      title: "Casa Andina",
      layout: "layouts/staff",
      categorias: categorias[0],
    });
  } catch (err) {
    console.error("Error al obtener categorías:", err.message);
    res.status(500).send("Error al obtener categorías");
  }
};

// FORMULARIO PARA REGISTRO
export const renderFormCrearCategoria = async (req, res) => {
  try {
    res.render("register-categoriaservicio", {
      title: "Casa Andina",
      layout: "layouts/staff",
    });
  } catch (err) {
    console.error("Error al cargar formulario:", err.message);
    res.status(500).send("Error al cargar formulario");
  }
};

// OBTENER CATEGORÍA POR ID
export const getCategoriaServicioById = async (req, res) => {
  const { id } = req.params;

  try {
    const [data] = await conexion.query("CALL sp_obtener_categoriaservicio_por_id(?)", [id]);
    res.render("edit-categoriaservicio", {
      title: "Casa Andina",
      layout: "layouts/staff",
      categoria: data[0][0],
    });
  } catch (err) {
    console.error("Error al obtener categoría:", err.message);
    res.status(500).send("Error al obtener categoría");
  }
};

// ACTUALIZAR CATEGORÍA
export const updateCategoriaServicio = async (req, res) => {
  const { id } = req.params;
  const { detalle, descripcion, precio, estado } = req.body;

  try {
    await conexion.query(
      "CALL sp_actualizar_categoriaservicio(?, ?, ?, ?, ?)",
      [id, detalle, descripcion, precio, estado]
    );

    if (req.file) {
      const tempPath = req.file.path;
      const targetPath = join(__dirname, "../public/img/category-service", `${id}.png`);
      fs.renameSync(tempPath, targetPath);
    }

    res.redirect("/staff-crud-categoriaservicio");
  } catch (err) {
    console.error("Error al actualizar categoría:", err.message);
    res.status(500).send("Error al actualizar categoría");
  }
};

// CAMBIAR ESTADO
export const toggleEstadoCategoriaServicio = async (req, res) => {
  const { id } = req.params;

  try {
    await conexion.query("CALL sp_cambiar_estado_categoriaservicio(?)", [id]);
    res.redirect("/staff-crud-categoriaservicio");
  } catch (err) {
    console.error("Error al cambiar estado:", err.message);
    res.status(500).send("Error al cambiar estado");
  }
};
