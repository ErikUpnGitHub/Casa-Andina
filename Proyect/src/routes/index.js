import { Router } from "express";
import multer from "multer"
import * as usercontroller from "../controllers/userController.js";
import * as reserveController from "../controllers/reserveController.js";
import * as foodController from "../controllers/foodController.js";
import * as activityController from "../controllers/activityController.js";
import * as serviceController from "../controllers/serviceController.js";
import * as staffController from "../controllers/staffController.js";
import * as crudFuncionController from "../controllers/crudFuncionController.js";
import * as crudCtgComidaController from "../controllers/crudCtgComidaController.js";
import * as crudEmpleadoController from "../controllers/crudEmployeController.js";
import * as crudTipoHabitacionController from "../controllers/crudTipoHabitacionController.js";
import * as crudRoomController from "../controllers/crudRoomController.js";
import * as crudProductoController from "../controllers/crudProductoController.js";
import * as crudActivityController from "../controllers/crudActividadController.js";
import * as dashboardController from "../controllers/dashboardController.js";
import * as categoriaServicioController from '../controllers/crudCategoriaServicioController.js';
import { getResponse } from '../chat/chatbotResponse.js';

//import conexion from '../database/db.js';

const router = Router();

function permitirRoles(rolesPermitidos) {
  return function (req, res, next) {
    const roleId = req.session.rol?.id;
    if (!rolesPermitidos.includes(roleId)) {
      return res.status(403).send("Acceso denegado");
    }
    next();
  };
}

const upload = multer({ dest: "src/public/temp" });

// =============== VIEWS ===============

// CHATBOT
router.get('/chatbot', (req, res) => {
  res.render('chatbot', { title: 'ChatBot Casa Andina', layout: 'layouts/main' });
});

// CLIENTES
router.get("/", (req, res) =>
  res.render("login", { title: "Casa Andina", layout: "layouts/access" })
);

router.get("/home", (req, res) =>
  res.render("home", {
    title: "Casa Andina",
    layout: "layouts/main",
    locale: req.getLocale(),
  })
);

router.get("/order-food", foodController.getFoodCategoriesAndProducts);
router.post("/successful-food", serviceController.postSuccessfulFood);

router.get("/activity", activityController.listActivities);
router.get("/activity-schedule/:id", activityController.showActivitySchedule);
router.post("/registrarInscripcion", activityController.registrarInscripcion);
router.get(
  "/activity-inscription",
  activityController.mostrarInscripcionExitosa
);
router.get("/services", serviceController.getActiveServiceCategories);

router.post("/insertar-servicio", serviceController.postInsertarServicio);
router.get(
  "/register-service-request",
  serviceController.getRegistrarSolicitud
);

router.get("/request", serviceController.getClientRequestData);

// ACCESS
router.get("/login", (req, res) => {
  res.render("login", {
    title: "Casa Andina",
    layout: "layouts/access",
    locale: req.getLocale(),
    success: req.query.success || null,
    error: req.query.error || null,
  });
});

router.post('/change-language', (req, res) => {
  const { locale } = req.body;
  res.cookie('locale', locale, { maxAge: 900000, httpOnly: true });
  res.redirect('home');
});


router.get("/register", usercontroller.getDocType);

// RESERVE
router.get("/reserveStep1", (req, res) =>
  res.render("reserveStep1", { title: "Casa Andina", layout: "layouts/main" })
);
router.get("/reserveStep2", reserveController.getAvailableRoomTypes);
router.get("/reserveStep3", reserveController.getReserveStep3);
router.get("/reserveStep4", reserveController.getReserveStep4);
router.post("/reserveStep5", reserveController.postReserveStep5);
router.get("/reserveStep5", reserveController.getReserveStep5);

// =============== VIEWS EMPLEADOS ===============

// HOME
router.get("/staff-home", (req, res) => {
  const roleId = req.session.rol?.id;

  if (!roleId) {
    return res.render("access-denied", {
      title: "Casa Andina",
      layout: "layouts/staff",
      locale: req.getLocale(),
    });
  }

  res.render("staff-home", {
    title: "Casa Andina",
    layout: "layouts/staff",
    locale: req.getLocale(),
  });
});

// TASKS
router.get("/staff-task", staffController.getServiciosAsignados);
router.post('/update-state-service', staffController.cambiarEstadoServicio);

// =============== CONTROLLERS ===============

// FUNCIONES
router.get("/staff-crud-funcion", crudFuncionController.getFunciones);
router.post("/staff-crud-funcion", crudFuncionController.createFuncion);
router.get("/staff-crud-funcion/editar/:id", crudFuncionController.getFuncionById);
router.post("/staff-crud-funcion/editar/:id", crudFuncionController.updateFuncion);
router.post("/staff-crud-funcion/eliminar/:id", crudFuncionController.deleteFuncion);

// CATEGORÍAS DE COMIDA
router.get("/staff-crud-categoriacomida", crudCtgComidaController.getCategoriasComida);
router.post("/staff-crud-categoriacomida", crudCtgComidaController.createCategoriaComida);
router.get("/staff-crud-categoriacomida/editar/:id", crudCtgComidaController.getCategoriaComidaById);
router.post("/staff-crud-categoriacomida/editar/:id", crudCtgComidaController.updateCategoriaComida);
router.post("/staff-crud-categoriacomida/cambiar-estado/:id", crudCtgComidaController.toggleEstadoCategoriaComida);

// EMPLEADOS
router.get("/staff-crud-empleado", crudEmpleadoController.getEmpleados);
router.post("/staff-crud-empleado", crudEmpleadoController.createEmpleado);
router.get("/staff-crud-empleado/registrar", crudEmpleadoController.renderFormCrearEmpleado);
router.get("/staff-crud-empleado/editar/:id", crudEmpleadoController.getEmpleadoById);
router.post("/staff-crud-empleado/editar/:id", crudEmpleadoController.updateEmpleado);
router.post("/staff-crud-empleado/cambiar-estado/:id", crudEmpleadoController.toggleEstadoEmpleado);

// TIPOS DE HABITACIÓN
router.get("/staff-crud-tipo-habitacion", crudTipoHabitacionController.getTiposHabitacion);
router.post("/staff-crud-tipo-habitacion", upload.single("imagen"), crudTipoHabitacionController.createTipoHabitacion);
router.get("/staff-crud-tipo-habitacion/registrar", crudTipoHabitacionController.renderFormCrearTipoHabitacion);
router.get("/staff-crud-tipo-habitacion/editar/:id", crudTipoHabitacionController.getTipoHabitacionById);
router.post("/staff-crud-tipo-habitacion/editar/:id", upload.single("imagen"), crudTipoHabitacionController.updateTipoHabitacion);

// HABITACIONES
router.get("/staff-crud-habitacion", crudRoomController.getHabitaciones);
router.post("/staff-crud-habitacion", crudRoomController.createHabitacion);
router.get("/staff-crud-habitacion/registrar", crudRoomController.renderFormCrearHabitacion);
router.get("/staff-crud-habitacion/editar/:id", crudRoomController.getHabitacionById);
router.post("/staff-crud-habitacion/editar/:id", crudRoomController.updateHabitacion);

// PRODUCTOS
router.get("/staff-crud-producto", crudProductoController.getProductos);
router.get("/staff-crud-producto/registrar", crudProductoController.renderFormCrearProducto);
router.post("/staff-crud-producto", upload.single("imagen"), crudProductoController.createProducto);
router.get("/staff-crud-producto/editar/:id", crudProductoController.getProductoById);
router.post("/staff-crud-producto/editar/:id", upload.single("imagen"), crudProductoController.updateProducto);
router.post("/staff-crud-producto/cambiar-estado/:id", crudProductoController.toggleEstadoProducto);

// ACTIVIDADES
router.get("/staff-crud-actividad", crudActivityController.getActividades);
router.get("/staff-crud-actividad/registrar", crudActivityController.renderFormCrearActividad);
router.post("/staff-crud-actividad", upload.single("imagen"), crudActivityController.createActividad);
router.get("/staff-crud-actividad/editar/:id", crudActivityController.getActividadById);
router.post("/staff-crud-actividad/editar/:id", upload.single("imagen"), crudActivityController.updateActividad);
router.post("/staff-crud-actividad/cambiar-estado/:id", crudActivityController.toggleEstadoActividad);
router.get("/staff-crud-actividad/evento/:id", crudActivityController.renderFormEvento);
router.post("/staff-crud-actividad/evento/:id", crudActivityController.crearOActualizarEvento);

// CATEGORÍAS DE SERVICIO
router.get("/staff-crud-categoriaservicio", categoriaServicioController.getCategoriasServicio);
router.get("/staff-crud-categoriaservicio/registrar", categoriaServicioController.renderFormCrearCategoria);
router.post("/staff-crud-categoriaservicio", upload.single("imagen"), categoriaServicioController.createCategoriaServicio);
router.get("/staff-crud-categoriaservicio/editar/:id", categoriaServicioController.getCategoriaServicioById);
router.post("/staff-crud-categoriaservicio/editar/:id", upload.single("imagen"), categoriaServicioController.updateCategoriaServicio);
router.post("/staff-crud-categoriaservicio/cambiar-estado/:id", categoriaServicioController.toggleEstadoCategoriaServicio);

// RESEÑAS
router.get("/registrar-resenia/:idServicio", serviceController.getRegistrarResenia);
router.post("/registrar-resenia", serviceController.postRegistrarResenia);

// DASHBOARD
router.get("/staff-dashboard", dashboardController.renderDashboard);

// LOGIN
router.post("/register", usercontroller.registerUser);
router.post("/login", usercontroller.loginUser);

// CHATBOT API
router.post('/chat', (req, res) => {
  const userInput = req.body.message;
  const response = getResponse(userInput);
  res.json({ response });
});

export default router;
