import conexion from "../database/db.js";
import fs from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// CREAR PRODUCTO
export const createProducto = async (req, res) => {
  const { nombre, descripcion, precio, idCtgComida } = req.body;

  try {
    // Llamamos al procedimiento y guardamos el ID en @p_idProducto
    await conexion.query(
      "CALL sp_registrar_producto(?, ?, ?, ?, @p_idProducto)",
      [nombre, descripcion, precio, idCtgComida]
    );

    // Recuperamos el ID insertado
    const [result] = await conexion.query("SELECT @p_idProducto AS nuevoId");
    const nuevoId = result[0].nuevoId;

    // Guardar imagen si se subió
    if (req.file) {
      const tempPath = req.file.path;
      const targetPath = join(__dirname, "../public/img/food", `${nuevoId}.png`);
      fs.renameSync(tempPath, targetPath);
    }

    res.redirect("/staff-crud-producto");
  } catch (err) {
    console.error("Error al registrar producto:", err.message);
    res.status(500).send("Error al registrar producto");
  }
};


// LISTAR PRODUCTOS
export const getProductos = async (req, res) => {
  try {
    const [productos] = await conexion.query("CALL sp_listar_productos()");
    res.render("staff-crud-producto", {
      title: "Casa Andina",
      layout: "layouts/staff",
      productos: productos[0],
    });
  } catch (err) {
    console.error("Error al obtener productos:", err.message);
    res.status(500).send("Error al obtener productos");
  }
};

// FORMULARIO PARA REGISTRO
export const renderFormCrearProducto = async (req, res) => {
  try {
    const [categorias] = await conexion.query("CALL LeerCategoriasComida()");
    res.render("register-producto", {
      title: "Casa Andina",
      layout: "layouts/staff",
      categorias: categorias[0],
    });
  } catch (err) {
    console.error("Error al cargar formulario:", err.message);
    res.status(500).send("Error al cargar formulario");
  }
};

// OBTENER PRODUCTO POR ID
export const getProductoById = async (req, res) => {
  const { id } = req.params;

  try {
    const [productoData] = await conexion.query("CALL sp_obtener_producto_por_id(?)", [id]);
    const [categorias] = await conexion.query("CALL LeerCategoriasComida()");
    res.render("edit-producto", {
      title: "Casa Andina",
      layout: "layouts/staff",
      producto: productoData[0][0],
      categorias: categorias[0],
    });
  } catch (err) {
    console.error("Error al obtener producto:", err.message);
    res.status(500).send("Error al obtener producto");
  }
};

// ACTUALIZAR PRODUCTO
export const updateProducto = async (req, res) => {
  const { id } = req.params;
  const { nombre, descripcion, precio, idCtgComida } = req.body;

  try {
    await conexion.query(
      "CALL sp_actualizar_producto(?, ?, ?, ?, ?)",
      [id, nombre, descripcion, precio, idCtgComida]
    );

    // Reemplazar imagen si se subió una nueva
    if (req.file) {
      const tempPath = req.file.path;
      const targetPath = join(__dirname, "../public/img/food", `${id}.png`);
      fs.renameSync(tempPath, targetPath);
    }

    res.redirect("/staff-crud-producto");
  } catch (err) {
    console.error("Error al actualizar producto:", err.message);
    res.status(500).send("Error al actualizar producto");
  }
};

// CAMBIAR ESTADO
export const toggleEstadoProducto = async (req, res) => {
  const { id } = req.params;

  try {
    await conexion.query("CALL sp_cambiar_estado_producto(?)", [id]);
    res.redirect("/staff-crud-producto");
  } catch (err) {
    console.error("Error al cambiar estado:", err.message);
    res.status(500).send("Error al cambiar estado del producto");
  }
};
