import conexion from "../database/db.js";
import bcrypt from "bcryptjs";

// CREAR EMPLEADO (y su usuario)
export const createEmpleado = async (req, res) => {
  const { nombre, apellido, dni, idFuncion, email, telefono, contrasenia } =
    req.body;

  try {
    const hashedPassword = await bcrypt.hash(contrasenia, 10);

    await conexion.query(
      "CALL sp_registrar_empleado_usuario(?, ?, ?, ?, ?, ?, ?)",
      [nombre, apellido, dni, idFuncion, email, telefono, hashedPassword]
    );

    res.redirect("/staff-crud-empleado");
  } catch (err) {
    console.error("Error al crear empleado:", err.message);
    res.status(500).send("Error al crear empleado");
  }
};

// LEER TODOS LOS EMPLEADOS
export const getEmpleados = async (req, res) => {
  try {
    const [empleados] = await conexion.query("CALL sp_listar_empleados()");
    const [funciones] = await conexion.query("CALL LeerFunciones()");
    res.render("staff-crud-empleado", {
      title: "Casa Andina",
      layout: "layouts/staff",
      empleados: empleados[0],
      funciones: funciones[0],
    });
  } catch (error) {
    console.error("Error al obtener empleados:", error);
    res.status(500).send("Error interno");
  }
};

// LEER EMPLEADO POR ID
export const getEmpleadoById = async (req, res) => {
  const { id } = req.params;

  try {
    const [rows] = await conexion.query("CALL sp_obtener_empleado_por_id(?)", [
      id,
    ]);
    const empleado = rows[0][0];

    const [funcionesResult] = await conexion.query("CALL LeerFunciones()");
    const funciones = funcionesResult[0];

    res.render("edit-empleado", {
      title: "Casa Andina",
      layout: "layouts/staff",
      empleado,
      funciones,
    });
  } catch (err) {
    console.error("Error al obtener empleado:", err.message);
    res.status(500).send("Error al obtener empleado");
  }
};

// ACTUALIZAR EMPLEADO
export const updateEmpleado = async (req, res) => {
  const { id } = req.params;
  const { nombre, apellido, dni, idFuncion, email, telefono } = req.body;

  try {
    await conexion.query("CALL sp_actualizar_empleado(?, ?, ?, ?, ?, ?, ?)", [
      id,
      nombre,
      apellido,
      dni,
      idFuncion,
      email,
      telefono,
    ]);

    res.redirect("/staff-crud-empleado");
  } catch (err) {
    console.error("Error al actualizar empleado:", err.message);
    res.status(500).send("Error al actualizar empleado");
  }
};

// CAMBIAR ESTADO EMPLEADO
export const toggleEstadoEmpleado = async (req, res) => {
  const { id } = req.params;
  const { estadoActual } = req.body;

  const nuevoEstado = estadoActual === "activo" ? "suspendido" : "activo";

  try {
    await conexion.query("CALL sp_cambiar_estado_empleado(?, ?)", [id, nuevoEstado]);
    res.redirect("/staff-crud-empleado");
  } catch (err) {
    console.error("Error al cambiar estado:", err.message);
    res.status(500).send("Error al cambiar estado del empleado");
  }
};


export const renderFormCrearEmpleado = async (req, res) => {
  try {
    const [funcionesResult] = await conexion.query("CALL LeerFunciones()");
    res.render("register-empleado", {
      title: "Registrar Empleado",
      layout: "layouts/staff",
      funciones: funcionesResult[0],
    });
  } catch (err) {
    console.error("Error al cargar formulario:", err.message);
    res.status(500).send("Error al cargar formulario de empleado");
  }
};