-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1:3307
-- Tiempo de generación: 24-06-2025 a las 18:08:41
-- Versión del servidor: 10.4.32-MariaDB
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `casa_andina_db`
--

DELIMITER $$
--
-- Procedimientos
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `ActualizarCategoriaComida` (IN `p_idCtgComida` INT, IN `p_descripcion` TEXT)   BEGIN
    UPDATE categoriacomida
    SET descripcion = p_descripcion
    WHERE idCtgComida = p_idCtgComida;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ActualizarFuncion` (IN `p_idFuncion` INT, IN `p_detalle` TEXT)   BEGIN
    UPDATE funcion
    SET detalle = p_detalle
    WHERE idFuncion = p_idFuncion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `calcular_monto_total` (IN `p_idTipoHbt` INT, IN `p_fechaEntrada` DATE, IN `p_fechaSalida` DATE)   BEGIN
    DECLARE noches INT;

    SET noches = DATEDIFF(p_fechaSalida, p_fechaEntrada);

    SELECT
        th.precio * noches AS monto_total
    FROM
        tipohabitacion th
    WHERE
        th.idTipoHbt = p_idTipoHbt;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CambiarEstadoCategoriaComida` (IN `p_idCtgComida` INT)   BEGIN
    UPDATE categoriacomida
    SET estado = IF(estado = 'activo', 'inactivo', 'activo')
    WHERE idCtgComida = p_idCtgComida;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CambiarEstadoServicio` (IN `p_idServicio` INT, IN `p_nuevoEstado` VARCHAR(20))   BEGIN
    UPDATE servicio
    SET estado = p_nuevoEstado,
        updated_at = CURRENT_TIMESTAMP()
    WHERE idServicio = p_idServicio;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CrearCategoriaComida` (IN `p_descripcion` TEXT)   BEGIN
    INSERT INTO categoriacomida (descripcion, estado)
    VALUES (p_descripcion, 'activo');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `CrearFuncion` (IN `p_detalle` TEXT)   BEGIN
    INSERT INTO funcion (detalle, activo) VALUES (p_detalle, 1);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `EliminarFuncion` (IN `p_idFuncion` INT)   BEGIN
    UPDATE funcion
    SET activo = IF(activo = 1, 0, 1)
    WHERE idFuncion = p_idFuncion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GenerarHorariosDiarios` (IN `id_actividad` INT, IN `cupo` INT, IN `fecha` DATE, IN `hora_inicio` TIME, IN `hora_fin` TIME, IN `duracion` INT)   BEGIN
  DECLARE hora_actual TIME;
  DECLARE estado_actividad VARCHAR(20);
  DECLARE actividad_existe INT DEFAULT 0;

  -- Verificar si la actividad existe
  SELECT COUNT(*) INTO actividad_existe
  FROM Actividad
  WHERE idActividad = id_actividad;

  IF actividad_existe = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La actividad no existe';
  END IF;

  -- Obtener el estado de la actividad
  SELECT estado INTO estado_actividad
  FROM Actividad
  WHERE idActividad = id_actividad;

  -- Validar que la actividad esté disponible
  IF estado_actividad <> 'disponible' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La actividad no está disponible';
  END IF;

  SET hora_actual = hora_inicio;

  WHILE ADDTIME(hora_actual, SEC_TO_TIME(duracion * 60)) <= hora_fin DO
    -- Validar que no exista un horario igual para la misma actividad en esa fecha y hora
    IF NOT EXISTS (
      SELECT 1 FROM HorarioActividad
      WHERE idActividad = id_actividad
        AND fchInicio = TIMESTAMP(fecha, hora_actual)
        AND fchFin = TIMESTAMP(fecha, ADDTIME(hora_actual, SEC_TO_TIME(duracion * 60)))
    ) THEN
      INSERT INTO HorarioActividad (idActividad, cupoMax, fchInicio, fchFin, estado)
      VALUES (
        id_actividad,
        cupo,
        TIMESTAMP(fecha, hora_actual),
        TIMESTAMP(fecha, ADDTIME(hora_actual, SEC_TO_TIME(duracion * 60))),
        'activo'
      );
    END IF;

    SET hora_actual = ADDTIME(hora_actual, SEC_TO_TIME(duracion * 60));
  END WHILE;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `insertarInscripcion` (IN `p_idHraActividad` INT, IN `p_idCuenta` INT)   BEGIN
    DECLARE v_idCliente INT;
    DECLARE v_cuposRestantes INT DEFAULT 0;

    -- Obtener el idCliente desde la cuenta
    SELECT idCliente INTO v_idCliente
    FROM usuario
    WHERE idCuenta = p_idCuenta
      AND estado = 'activo'
      AND idCliente IS NOT NULL;

    IF v_idCliente IS NOT NULL THEN

        SELECT
            GREATEST(
                (SELECT cupoMax FROM horarioactividad WHERE idHraActividad = p_idHraActividad) -
                (SELECT COUNT(*) FROM inscripcion WHERE idHraActividad = p_idHraActividad AND estado = 'confirmada'),
                0
            ) INTO v_cuposRestantes;

        IF v_cuposRestantes > 0 THEN
            INSERT INTO inscripcion (
                idHraActividad,
                idCliente,
                fchInscripcion,
                estado,
                created_at,
                updated_at
            ) VALUES (
                p_idHraActividad,
                v_idCliente,
                CURRENT_TIMESTAMP(),
                'confirmada',
                CURRENT_TIMESTAMP(),
                CURRENT_TIMESTAMP()
            );
            SELECT 1 AS insercionExitosa;
        ELSE
            SELECT 0 AS insercionExitosa;
        END IF;

    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cliente no encontrado o cuenta inactiva.';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `insertarServicio` (IN `p_idUsuario` INT, IN `p_idCtgServicio` INT)   BEGIN
    DECLARE v_idCliente INT;
    DECLARE v_idHabitacion INT;
    DECLARE v_idServicio INT;

    -- 1. Obtener el idCliente asociado al idUsuario
    SELECT idCliente INTO v_idCliente
    FROM usuario
    WHERE idCuenta = p_idUsuario;

    -- 2. Obtener la habitación activa del cliente
    SELECT idHabitacion INTO v_idHabitacion
    FROM reservahbt
    WHERE idCliente = v_idCliente AND estado = 'activa'
    LIMIT 1;

    -- 3. Insertar el servicio
    INSERT INTO Servicio (
        idCliente,
        idCtgServicio,
        idHabitacion,
        estado
    ) VALUES (
        v_idCliente,
        p_idCtgServicio,
        v_idHabitacion,
        'activo'
    );

    -- 4. Obtener el ID del servicio insertado
    SET v_idServicio = LAST_INSERT_ID();

    -- 5. Devolver el ID
    SELECT v_idServicio AS idServicio;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `insertarServicioComida` (IN `p_idProducto` INT, IN `p_idServicio` INT, IN `p_cantidad` INT, IN `p_precio` DECIMAL(10,2))   BEGIN
    INSERT INTO serviciocomida (idProducto, idServicio, cantidad, precio)
    VALUES (p_idProducto, p_idServicio, p_cantidad, p_precio);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `insertar_funcion_servicio` (IN `p_idFuncion` INT, IN `p_idCtgServicio` INT)   BEGIN
  IF EXISTS (SELECT 1 FROM Funcion WHERE idFuncion = p_idFuncion) AND
     EXISTS (SELECT 1 FROM CategoriaServicio WHERE idCtgServicio = p_idCtgServicio) THEN
    INSERT INTO FuncionServicio (idFuncion, idCtgServicio)
    VALUES (p_idFuncion, p_idCtgServicio);
  ELSE
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'La función o la categoría de servicio no existen';
  END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `LeerCategoriaComidaPorID` (IN `p_idCtgComida` INT)   BEGIN
    SELECT * FROM categoriacomida WHERE idCtgComida = p_idCtgComida;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `LeerCategoriasComida` ()   BEGIN
    SELECT * FROM categoriacomida;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `LeerFunciones` ()   BEGIN
    SELECT * FROM funcion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `LeerFuncionPorID` (IN `p_idFuncion` INT)   BEGIN
    SELECT * FROM funcion WHERE idFuncion = p_idFuncion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ListarActividades` ()   BEGIN
    SELECT 
        idActividad,
        detalle,
        descripcion,
        duracion,
        precio,
        estado
    FROM Actividad;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `listarCategoriasComida` ()   BEGIN
    SELECT idCtgComida, descripcion, estado
    FROM categoriacomida
    WHERE estado = 'activo';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `listarCategoriasServicioActivas` ()   BEGIN
    SELECT 
        idCtgServicio,
        detalle,
        descripcion,
        precio,
        estado
    FROM 
        categoriaservicio
    WHERE 
        estado = 'activo';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ListarProductosActivos` ()   BEGIN
    SELECT 
        idProducto,
        nombre,
        descripcion,
        precio,
        idCtgComida,
        estado
    FROM 
        producto
    WHERE 
        estado = 'activo';
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ObtenerActividadPorID` (IN `p_idActividad` INT)   BEGIN
    SELECT 
        idActividad,
        detalle,
        descripcion,
        duracion,
        precio,
        estado
    FROM Actividad
    WHERE idActividad = p_idActividad;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtenerCuposRestantes` (IN `p_idHraActividad` INT)   BEGIN
    DECLARE v_cupoMax INT DEFAULT 0;
    DECLARE v_inscripciones INT DEFAULT 0;
    DECLARE v_cuposRestantes INT DEFAULT 0;

    SELECT cupoMax INTO v_cupoMax
    FROM horarioactividad
    WHERE idHraActividad = p_idHraActividad;

    SELECT COUNT(*) INTO v_inscripciones
    FROM inscripcion
    WHERE idHraActividad = p_idHraActividad
      AND estado = 'confirmada';

    SET v_cuposRestantes = GREATEST(v_cupoMax - v_inscripciones, 0);

    SELECT v_cuposRestantes AS cuposRestantes;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtenerDatosCliente` (IN `p_idCliente` INT)   BEGIN
    -- Reservas del cliente
    SELECT 
        r.idReservaHbt,
        r.fchInicio,
        r.fchFin,
        r.horaSalida,
        r.estado AS estadoReserva,
        h.numero AS numeroHabitacion,
        th.nombre AS tipoHabitacion
    FROM reservahbt r
    JOIN habitacion h ON r.idHabitacion = h.idHabitacion
    JOIN tipohabitacion th ON h.idTipoHbt = th.idTipoHbt
    WHERE r.idCliente = p_idCliente;

    -- Servicios solicitados últimos 7 días
    SELECT 
        s.idServicio,
        s.estado AS estadoServicio,
        cs.detalle AS categoriaServicio,  -- Cambiado de descripcion a detalle
        s.idCtgServicio,
        s.created_at,
        s.updated_at
    FROM servicio s
    JOIN categoriaservicio cs ON s.idCtgServicio = cs.idCtgServicio
    WHERE s.idCliente = p_idCliente
      AND s.created_at >= NOW() - INTERVAL 7 DAY;

    -- Inscripciones últimos 7 días
    SELECT 
        i.idInscripcion,
        a.detalle AS actividad,  -- Cambiado de descripcion a detalle
        ha.fchInicio,
        ha.fchFin,
        i.estado AS estadoInscripcion,
        i.fchInscripcion
    FROM inscripcion i
    JOIN horarioactividad ha ON i.idHraActividad = ha.idHraActividad
    JOIN actividad a ON ha.idActividad = a.idActividad
    WHERE i.idCliente = p_idCliente
      AND i.created_at >= NOW() - INTERVAL 7 DAY;

    -- Productos asociados a servicios con idCtgServicio = 1 (últimos 7 días)
    SELECT 
        s.idServicio,
        p.nombre AS nombreProducto,
        p.descripcion,
        sc.cantidad,
        sc.precio,
        (sc.cantidad * sc.precio) AS total
    FROM servicio s
    JOIN serviciocomida sc ON s.idServicio = sc.idServicio
    JOIN producto p ON sc.idProducto = p.idProducto
    WHERE s.idCliente = p_idCliente
      AND s.idCtgServicio = 1
      AND s.created_at >= NOW() - INTERVAL 7 DAY;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ObtenerFuncionPorCuenta` (IN `p_idCuenta` INT)   BEGIN
    SELECT f.*
    FROM usuario u
    INNER JOIN empleado e ON u.idEmpleado = e.idEmpleado
    INNER JOIN funcion f ON e.idFuncion = f.idFuncion
    WHERE u.idCuenta = p_idCuenta;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ObtenerHorariosHoyPorActividad` (IN `p_idActividad` INT)   BEGIN
    SELECT 
        idHraActividad,
        idActividad,
        cupoMax,
        fchInicio,
        fchFin,
        estado
    FROM HorarioActividad
    WHERE idActividad = p_idActividad
      AND DATE(fchInicio) = CURDATE();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `ObtenerServiciosPorCuenta` (IN `p_idCuenta` INT)   BEGIN
    DECLARE v_idEmpleado INT;

    -- Obtener el idEmpleado desde la tabla usuario
    SELECT u.idEmpleado INTO v_idEmpleado
    FROM usuario u
    WHERE u.idCuenta = p_idCuenta;

    -- Mostrar los servicios asignados en las últimas 24 horas a ese empleado
    SELECT 
        s.idServicio,
        cs.detalle AS categoria_servicio,
        h.numero AS numero_habitacion,
        c.nombre AS nombre_cliente,
        c.apellido AS apellido_cliente,
        s.estado AS estado_servicio,
        a.fchAsignacion AS fecha_asignacion
    FROM asignacionservicio a
    INNER JOIN servicio s ON a.idServicio = s.idServicio
    LEFT JOIN categoriaservicio cs ON s.idCtgServicio = cs.idCtgServicio
    LEFT JOIN habitacion h ON s.idHabitacion = h.idHabitacion
    LEFT JOIN cliente c ON s.idCliente = c.idCliente
    WHERE a.idEmpleado = v_idEmpleado
      AND a.fchAsignacion >= NOW() - INTERVAL 1 DAY;

    -- Mostrar productos si la categoría de servicio es 1 (servicio de comida)
    SELECT 
        sc.idServicio,
        p.nombre AS producto,
        sc.cantidad,
        sc.precio
    FROM asignacionservicio a
    INNER JOIN servicio s ON a.idServicio = s.idServicio
    INNER JOIN serviciocomida sc ON s.idServicio = sc.idServicio
    INNER JOIN producto p ON sc.idProducto = p.idProducto
    WHERE a.idEmpleado = v_idEmpleado
      AND a.fchAsignacion >= NOW() - INTERVAL 1 DAY
      AND s.idCtgServicio = 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_checkouts_ocupacion_total` (IN `p_idTipoHbt` INT)   BEGIN
  WITH RECURSIVE fechas AS (
    SELECT
      r.idReservaHbt,
      h.idHabitacion,
      DATE(r.fchInicio) AS fecha,
      r.fchInicio,
      r.fchFin
    FROM reservahbt r
    JOIN habitacion h ON r.idHabitacion = h.idHabitacion
    WHERE r.estado = 'activa' AND h.idTipoHbt = p_idTipoHbt

    UNION ALL

    SELECT
      f.idReservaHbt,
      f.idHabitacion,
      DATE_ADD(f.fecha, INTERVAL 1 DAY),
      f.fchInicio,
      f.fchFin
    FROM fechas f
    WHERE DATE_ADD(f.fecha, INTERVAL 1 DAY) <= DATE(f.fchFin)
  ),

  checkout_fechas AS (
    SELECT
      f.idHabitacion,
      CASE
        WHEN f.fecha = DATE(f.fchInicio) THEN TIMESTAMP(f.fecha, TIME(f.fchInicio))
        ELSE TIMESTAMP(f.fecha, '12:00:00')
      END AS checkout
    FROM fechas f
    WHERE
      (
        (f.fecha = DATE(f.fchInicio) AND TIME(f.fchInicio) < '12:01:00')
        OR
        (f.fecha != DATE(f.fchInicio) AND '12:00:00' < '12:01:00')
      )
  )

  SELECT cf.checkout
  FROM checkout_fechas cf
  GROUP BY cf.checkout
  HAVING COUNT(DISTINCT cf.idHabitacion) = (
    SELECT COUNT(*) FROM habitacion WHERE idTipoHbt = p_idTipoHbt
  )
  ORDER BY cf.checkout;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_dias_ocupacion_total` (IN `p_idTipoHbt` INT)   BEGIN
  WITH RECURSIVE fechas AS (
    SELECT
      r.idReservaHbt,
      r.idHabitacion,
      r.fchInicio AS fecha,
      r.fchInicio AS fchInicio,
      r.fchFin,
      r.horaSalida
    FROM reservahbt r
    JOIN habitacion h ON r.idHabitacion = h.idHabitacion
    WHERE r.estado = 'activa' AND h.idTipoHbt = p_idTipoHbt

    UNION ALL

    SELECT
      f.idReservaHbt,
      f.idHabitacion,
      DATE_ADD(f.fecha, INTERVAL 1 DAY),
      f.fchInicio,
      f.fchFin,
      f.horaSalida
    FROM fechas f
    WHERE DATE_ADD(f.fecha, INTERVAL 1 DAY) <= f.fchFin
  ),

  dias_filtrados AS (
    SELECT
      f.idHabitacion,
      f.fecha,
      CASE
        WHEN DATE(f.fecha) = DATE(f.fchInicio) THEN TIME(f.fchInicio)
        WHEN DATE(f.fecha) = DATE(f.fchFin) THEN TIME(f.horaSalida)
        ELSE '14:00:00'
      END AS horaEstim
    FROM fechas f
    WHERE
      (
        (DATE(f.fecha) = DATE(f.fchInicio) AND TIME(f.fchInicio) > '13:59:00') OR
        (DATE(f.fecha) = DATE(f.fchFin) AND TIME(f.horaSalida) > '13:59:00') OR
        (f.fecha > f.fchInicio AND f.fecha < f.fchFin)
      )
  ),

  total_habitaciones AS (
    SELECT COUNT(*) AS total
    FROM habitacion
    WHERE idTipoHbt = p_idTipoHbt
  )

  SELECT df.fecha
  FROM dias_filtrados df
  GROUP BY df.fecha
  HAVING COUNT(DISTINCT df.idHabitacion) = (SELECT total FROM total_habitaciones)
  ORDER BY df.fecha;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_tipos_habitacion_disponibles` (IN `p_adultos` INT, IN `p_ninos` INT)   BEGIN
    SELECT DISTINCT t.*
    FROM habitacion h
    JOIN tipohabitacion t ON h.idTipoHbt = t.idTipoHbt
    WHERE h.estado = 'disponible'
      AND t.adultos >= p_adultos
      AND t.ninos >= p_ninos;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `obtener_tipo_habitacion` (IN `p_idTipoHbt` INT)   BEGIN
    SELECT *
    FROM tipohabitacion
    WHERE idTipoHbt = p_idTipoHbt;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_actualizar_actividad` (IN `p_idActividad` INT, IN `p_detalle` TEXT, IN `p_descripcion` TEXT, IN `p_duracion` INT, IN `p_precio` DECIMAL(10,2))   BEGIN
    UPDATE actividad
    SET detalle = p_detalle,
        descripcion = p_descripcion,
        duracion = p_duracion,
        precio = p_precio
    WHERE idActividad = p_idActividad;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_actualizar_categoriaservicio` (IN `p_id` INT, IN `p_detalle` TEXT, IN `p_descripcion` TEXT, IN `p_precio` DECIMAL(10,2), IN `p_estado` VARCHAR(20))   BEGIN
  UPDATE categoriaservicio
  SET detalle = p_detalle,
      descripcion = p_descripcion,
      precio = p_precio,
      estado = p_estado
  WHERE idCtgServicio = p_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_actualizar_empleado` (IN `p_idEmpleado` INT, IN `p_nombre` VARCHAR(50), IN `p_apellido` VARCHAR(50), IN `p_dni` CHAR(8), IN `p_idFuncion` INT, IN `p_email` VARCHAR(100), IN `p_telefono` VARCHAR(15))   BEGIN
    UPDATE empleado
    SET nombre = p_nombre,
        apellido = p_apellido,
        dni = p_dni,
        idFuncion = p_idFuncion,
        email = p_email,
        telefono = p_telefono
    WHERE idEmpleado = p_idEmpleado;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_actualizar_habitacion` (IN `p_idHabitacion` INT, IN `p_idTipoHbt` INT, IN `p_numero` VARCHAR(10), IN `p_estado` ENUM('disponible','ocupado','mantenimiento'))   BEGIN
  UPDATE habitacion
  SET idTipoHbt = p_idTipoHbt,
      numero = p_numero,
      estado = p_estado
  WHERE idHabitacion = p_idHabitacion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_actualizar_producto` (IN `p_idProducto` INT, IN `p_nombre` TEXT, IN `p_descripcion` TEXT, IN `p_precio` DECIMAL(10,2), IN `p_idCtgComida` INT)   BEGIN
  UPDATE producto
  SET nombre = p_nombre,
      descripcion = p_descripcion,
      precio = p_precio,
      idCtgComida = p_idCtgComida,
      updated_at = NOW()
  WHERE idProducto = p_idProducto;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_actualizar_tipohabitacion` (IN `p_idTipoHbt` INT, IN `p_nombre` TEXT, IN `p_descripcion` TEXT, IN `p_tamano` VARCHAR(10), IN `p_cama` TEXT, IN `p_adultos` INT, IN `p_ninos` INT, IN `p_precio` DECIMAL(10,0))   BEGIN
  UPDATE tipohabitacion
  SET nombre = p_nombre,
      descripcion = p_descripcion,
      tamano = p_tamano,
      cama = p_cama,
      adultos = p_adultos,
      ninos = p_ninos,
      precio = p_precio
  WHERE idTipoHbt = p_idTipoHbt;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_buscar_resenia_por_idServicio` (IN `p_idServicio` INT)   BEGIN
  SELECT * FROM resenia WHERE idServicio = p_idServicio;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_cambiar_estado_actividad` (IN `p_idActividad` INT)   BEGIN
    UPDATE actividad
    SET estado = IF(estado = 'disponible', 'suspendida', 'disponible')
    WHERE idActividad = p_idActividad;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_cambiar_estado_categoriaservicio` (IN `p_id` INT)   BEGIN
  UPDATE categoriaservicio
  SET estado = CASE
	  WHEN estado = 'activo' THEN 'inactivo'
	  ELSE 'activo'
	END
  WHERE idCtgServicio = p_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_cambiar_estado_empleado` (IN `p_idEmpleado` INT, IN `p_nuevoEstado` ENUM('activo','inactivo','suspendido'))   BEGIN
    UPDATE empleado
    SET estado = p_nuevoEstado
    WHERE idEmpleado = p_idEmpleado;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_cambiar_estado_habitacion` (IN `p_idHabitacion` INT, IN `p_nuevoEstado` ENUM('disponible','ocupado','mantenimiento'))   BEGIN
  UPDATE habitacion
  SET estado = p_nuevoEstado
  WHERE idHabitacion = p_idHabitacion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_cambiar_estado_producto` (IN `p_idProducto` INT)   BEGIN
  UPDATE producto
  SET estado = IF(estado = 'activo', 'inactivo', 'activo')
  WHERE idProducto = p_idProducto;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_editar_resenia` (IN `p_idServicio` INT, IN `p_calificacion` INT, IN `p_comentario` TEXT)   BEGIN
  UPDATE resenia
  SET calificacion = p_calificacion,
      comentario = p_comentario,
      updated_at = NOW()
  WHERE idServicio = p_idServicio;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_get_tipo_documento` ()   BEGIN
    SELECT idTipoDoc, nombre FROM tipodocumento;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_listar_actividades` ()   BEGIN
    SELECT * FROM actividad;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_listar_categoriaservicio` ()   BEGIN
  SELECT * FROM categoriaservicio;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_listar_empleados` ()   BEGIN
    SELECT e.idEmpleado, e.nombre, e.apellido, e.dni, e.email, e.telefono, e.estado,
           f.idFuncion, f.detalle AS funcion
    FROM empleado e
    LEFT JOIN funcion f ON e.idFuncion = f.idFuncion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_listar_habitaciones` ()   BEGIN
  SELECT h.idHabitacion, h.idTipoHbt, h.numero, h.estado, t.nombre AS tipoNombre
  FROM habitacion h
  JOIN tipohabitacion t ON h.idTipoHbt = t.idTipoHbt;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_listar_productos` ()   BEGIN
  SELECT p.idProducto, p.nombre, p.descripcion, p.precio, p.estado,
         p.idCtgComida, c.descripcion AS categoria
  FROM producto p
  INNER JOIN categoriacomida c ON p.idCtgComida = c.idCtgComida;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_listar_tipohabitaciones` ()   BEGIN
  SELECT * FROM tipohabitacion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_login_usuario` (IN `p_email` VARCHAR(100))   BEGIN
    SELECT u.idCuenta, u.contrasenia, c.nombre, c.apellido, 'cliente' AS tipo
    FROM usuario u
    JOIN cliente c ON u.idCliente = c.idCliente
    WHERE c.email = p_email AND u.estado = 'activo' AND c.estado = 'activo'
    LIMIT 1;

    SELECT u.idCuenta, u.contrasenia, e.nombre, e.apellido, 'empleado' AS tipo
    FROM usuario u
    JOIN empleado e ON u.idEmpleado = e.idEmpleado
    WHERE e.email = p_email AND u.estado = 'activo' AND e.estado = 'activo'
    LIMIT 1;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_obtener_actividad_por_id` (IN `p_idActividad` INT)   BEGIN
    SELECT * FROM actividad WHERE idActividad = p_idActividad;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_obtener_categoriaservicio_por_id` (IN `p_id` INT)   BEGIN
  SELECT * FROM categoriaservicio WHERE idCtgServicio = p_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_obtener_empleado_por_id` (IN `p_idEmpleado` INT)   BEGIN
    SELECT e.idEmpleado, e.nombre, e.apellido, e.dni, e.email, e.telefono, e.estado,
           f.idFuncion, f.detalle AS funcion
    FROM empleado e
    LEFT JOIN funcion f ON e.idFuncion = f.idFuncion
    WHERE e.idEmpleado = p_idEmpleado;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_obtener_habitacion_por_id` (IN `p_idHabitacion` INT)   BEGIN
  SELECT * FROM habitacion WHERE idHabitacion = p_idHabitacion;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_obtener_producto_por_id` (IN `p_idProducto` INT)   BEGIN
  SELECT * FROM producto WHERE idProducto = p_idProducto;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_obtener_tipohabitacion_por_id` (IN `p_idTipoHbt` INT)   BEGIN
  SELECT * FROM tipohabitacion WHERE idTipoHbt = p_idTipoHbt;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_actividad` (IN `p_detalle` TEXT, IN `p_descripcion` TEXT, IN `p_duracion` INT, IN `p_precio` DECIMAL(10,2))   BEGIN
    INSERT INTO actividad (detalle, descripcion, duracion, precio, estado)
    VALUES (p_detalle, p_descripcion, p_duracion, p_precio, 'disponible');

    SELECT LAST_INSERT_ID() AS nuevoId;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_categoriaservicio` (IN `p_detalle` TEXT, IN `p_descripcion` TEXT, IN `p_precio` DECIMAL(10,2))   BEGIN
  INSERT INTO categoriaservicio (detalle, descripcion, precio, estado)
  VALUES (p_detalle, p_descripcion, p_precio, 'activo');
  
  SELECT LAST_INSERT_ID() AS nuevoId;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_cliente_usuario` (IN `p_nombre` VARCHAR(50), IN `p_apellido` VARCHAR(50), IN `p_email` VARCHAR(100), IN `p_telefono` VARCHAR(15), IN `p_idTipoDoc` INT, IN `p_nroDoc` VARCHAR(30), IN `p_nacionalidad` VARCHAR(50), IN `p_contrasenia` VARCHAR(255))   BEGIN
    DECLARE new_idCliente INT;

    -- Insertar en cliente
    INSERT INTO cliente (nombre, apellido, email, telefono, idTipoDoc, nroDoc, nacionalidad, estado)
    VALUES (p_nombre, p_apellido, p_email, p_telefono, p_idTipoDoc, p_nroDoc, p_nacionalidad, 'activo');

    SET new_idCliente = LAST_INSERT_ID();
    
    INSERT INTO usuario (contrasenia, idCliente, estado)
    VALUES (p_contrasenia, new_idCliente, 'activo');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_empleado_usuario` (IN `p_nombre` VARCHAR(50), IN `p_apellido` VARCHAR(50), IN `p_dni` CHAR(8), IN `p_idFuncion` INT, IN `p_email` VARCHAR(100), IN `p_telefono` VARCHAR(15), IN `p_contrasenia` VARCHAR(255))   BEGIN
    DECLARE new_idEmpleado INT;

    -- Insertar en empleado
    INSERT INTO empleado (nombre, apellido, dni, idFuncion, email, telefono, estado)
    VALUES (p_nombre, p_apellido, p_dni, p_idFuncion, p_email, p_telefono, 'activo');

    SET new_idEmpleado = LAST_INSERT_ID();

    -- Insertar en usuario
    INSERT INTO usuario (contrasenia, idEmpleado, estado)
    VALUES (p_contrasenia, new_idEmpleado, 'activo');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_habitacion` (IN `p_idTipoHbt` INT, IN `p_numero` VARCHAR(10), IN `p_estado` ENUM('disponible','ocupado','mantenimiento'))   BEGIN
  INSERT INTO habitacion (idTipoHbt, numero, estado)
  VALUES (p_idTipoHbt, p_numero, p_estado);
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_producto` (IN `p_nombre` TEXT, IN `p_descripcion` TEXT, IN `p_precio` DECIMAL(10,2), IN `p_idCtgComida` INT, OUT `p_idProducto` INT)   BEGIN
  INSERT INTO producto(nombre, descripcion, precio, idCtgComida, estado)
  VALUES (p_nombre, p_descripcion, p_precio, p_idCtgComida, 'activo');

  SET p_idProducto = LAST_INSERT_ID();
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_resenia` (IN `p_idServicio` INT, IN `p_calificacion` INT, IN `p_comentario` TEXT)   BEGIN
  INSERT INTO resenia (idServicio, calificacion, comentario, fchResenia)
  VALUES (p_idServicio, p_calificacion, p_comentario, NOW());
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_registrar_tipohabitacion` (IN `p_nombre` TEXT, IN `p_descripcion` TEXT, IN `p_tamano` VARCHAR(10), IN `p_cama` TEXT, IN `p_adultos` INT, IN `p_ninos` INT, IN `p_precio` DECIMAL(10,0))   BEGIN
  INSERT INTO tipohabitacion (nombre, descripcion, tamano, cama, adultos, ninos, precio)
  VALUES (p_nombre, p_descripcion, p_tamano, p_cama, p_adultos, p_ninos, p_precio);

  SELECT LAST_INSERT_ID() AS nuevoId;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sp_reservar_habitacion` (IN `p_idCuenta` INT, IN `p_idTipoHbt` INT, IN `p_fchInicio` DATE, IN `p_fchFin` DATE)   BEGIN
    DECLARE v_idCliente INT;
    DECLARE v_idHabitacion INT;
    DECLARE v_fchInicio DATETIME;
    DECLARE v_fchFin DATETIME;

    -- Establecer las horas fijas
    SET v_fchInicio = CONCAT(p_fchInicio, ' 14:00:00');
    SET v_fchFin = CONCAT(p_fchFin, ' 12:00:00');

    -- Obtener el idCliente desde la cuenta de usuario
    SELECT idCliente INTO v_idCliente
    FROM usuario
    WHERE idCuenta = p_idCuenta
      AND estado = 'activo'
      AND idCliente IS NOT NULL;

    -- Verificar si se encontró un cliente válido
    IF v_idCliente IS NOT NULL THEN

        -- Buscar una habitación disponible del tipo solicitado
        SELECT h.idHabitacion INTO v_idHabitacion
        FROM habitacion h
        LEFT JOIN reservahbt r ON h.idHabitacion = r.idHabitacion
            AND r.estado = 'activa'
            AND (
                (r.fchInicio < v_fchFin AND r.fchFin > v_fchFin) OR
                (r.fchInicio < v_fchInicio AND r.fchFin > v_fchInicio) OR
                (r.fchInicio >= v_fchInicio AND r.fchFin <= v_fchFin)
            )
        WHERE h.idTipoHbt = p_idTipoHbt
          AND r.idReservaHbt IS NULL
        LIMIT 1;

        -- Validar si se encontró una habitación disponible
        IF v_idHabitacion IS NOT NULL THEN
            INSERT INTO reservahbt (
                idCliente,
                idHabitacion,
                fchInicio,
                fchFin,
                horaSalida,
                estado,
                created_at,
                updated_at
            ) VALUES (
                v_idCliente,
                v_idHabitacion,
                v_fchInicio,
                v_fchFin,
                NULL,
                'activa',
                NOW(),
                NOW()
            );
        ELSE
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No hay habitaciones disponibles para el rango de fechas.';
        END IF;

    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cliente no encontrado o cuenta inactiva.';
    END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `actividad`
--

CREATE TABLE `actividad` (
  `idActividad` int(11) NOT NULL,
  `detalle` text DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  `duracion` int(11) DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `estado` enum('disponible','suspendida') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `actividad`
--

INSERT INTO `actividad` (`idActividad`, `detalle`, `descripcion`, `duracion`, `precio`, `estado`) VALUES
(1, 'Masaje Relajante', 'Masaje corporal relajante con aceites esenciales en la zona de spa.', 60, 600.00, 'disponible'),
(2, 'Tour Panoramico', 'Paseo guiado en vehículo por los alrededores del hotel con guía local.', 90, 350.00, 'disponible'),
(3, 'Sala de Cómputo', 'Uso de computadoras con acceso a internet y servicios básicos de oficina.', 60, 0.00, 'disponible');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `asignacionservicio`
--

CREATE TABLE `asignacionservicio` (
  `idAsigSer` int(11) NOT NULL,
  `idServicio` int(11) NOT NULL,
  `idEmpleado` int(11) NOT NULL,
  `fchAsignacion` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `asignacionservicio`
--

INSERT INTO `asignacionservicio` (`idAsigSer`, `idServicio`, `idEmpleado`, `fchAsignacion`) VALUES
(1, 1, 3, '2025-06-09 05:07:16'),
(2, 1, 4, '2025-06-09 05:07:16'),
(3, 2, 6, '2025-06-09 05:09:36'),
(4, 3, 5, '2025-06-09 05:10:45'),
(5, 4, 7, '2025-06-09 05:12:35'),
(6, 5, 7, '2025-06-09 05:12:52'),
(7, 6, 7, '2025-06-09 05:13:34'),
(8, 7, 3, '2025-06-09 05:39:11'),
(9, 7, 4, '2025-06-09 05:39:11'),
(10, 8, 3, '2025-06-09 07:12:01'),
(11, 8, 4, '2025-06-09 07:12:01'),
(12, 9, 3, '2025-06-09 07:14:16'),
(13, 9, 4, '2025-06-09 07:14:16'),
(14, 10, 3, '2025-06-09 07:14:50'),
(15, 10, 4, '2025-06-09 07:14:50'),
(16, 11, 3, '2025-06-09 07:25:01'),
(17, 11, 4, '2025-06-09 07:25:01'),
(18, 12, 3, '2025-06-09 07:26:11'),
(19, 12, 4, '2025-06-09 07:26:11'),
(20, 13, 3, '2025-06-09 07:27:41'),
(21, 13, 4, '2025-06-09 07:27:41'),
(22, 14, 3, '2025-06-09 20:01:37'),
(23, 14, 4, '2025-06-09 20:01:37'),
(24, 15, 3, '2025-06-09 21:44:38'),
(25, 15, 4, '2025-06-09 21:44:38'),
(26, 16, 3, '2025-06-09 21:44:49'),
(27, 16, 4, '2025-06-09 21:44:49'),
(28, 17, 3, '2025-06-09 23:19:29'),
(29, 17, 4, '2025-06-09 23:19:29'),
(30, 18, 3, '2025-06-13 05:25:10'),
(31, 18, 4, '2025-06-13 05:25:10'),
(32, 19, 3, '2025-06-13 19:46:39'),
(33, 19, 4, '2025-06-13 19:46:39'),
(34, 20, 3, '2025-06-14 08:39:17'),
(35, 20, 4, '2025-06-14 08:39:17'),
(36, 21, 3, '2025-06-15 15:47:34'),
(37, 21, 4, '2025-06-15 15:47:34'),
(38, 22, 3, '2025-06-16 02:10:12'),
(39, 22, 4, '2025-06-16 02:10:12');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categoriacomida`
--

CREATE TABLE `categoriacomida` (
  `idCtgComida` int(11) NOT NULL,
  `descripcion` text DEFAULT NULL,
  `estado` enum('activo','inactivo') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `categoriacomida`
--

INSERT INTO `categoriacomida` (`idCtgComida`, `descripcion`, `estado`) VALUES
(1, 'Bebidas', 'activo'),
(2, 'Entradas', 'activo'),
(3, 'Sopas', 'activo'),
(4, 'Fondos', 'activo'),
(5, 'Sandwiches', 'activo'),
(11, 'Bebidas Alcoholicas', 'inactivo');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `categoriaservicio`
--

CREATE TABLE `categoriaservicio` (
  `idCtgServicio` int(11) NOT NULL,
  `detalle` text DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `estado` enum('activo','inactivo') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `categoriaservicio`
--

INSERT INTO `categoriaservicio` (`idCtgServicio`, `detalle`, `descripcion`, `precio`, `estado`) VALUES
(1, 'Servicio a habitación', 'Servicio general de comida y bebida para los huéspedes', 0.00, 'activo'),
(2, 'Desayuno a la habitación', 'Entrega de desayuno directamente en la habitación', 0.00, 'inactivo'),
(3, 'Servicio de lavandería', 'Lavado, secado y planchado de ropa del huésped', 0.00, 'activo'),
(4, 'Servicio de reparación', 'Reparación de instalaciones o equipos en la habitación', 0.00, 'activo'),
(5, 'Servicio de limpieza', 'Limpieza de habitación proporcionada según requerimiento.', 0.00, 'activo');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `cliente`
--

CREATE TABLE `cliente` (
  `idCliente` int(11) NOT NULL,
  `nombre` varchar(50) DEFAULT NULL,
  `apellido` varchar(50) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `telefono` varchar(15) DEFAULT NULL,
  `idTipoDoc` int(11) DEFAULT NULL,
  `nroDoc` varchar(30) DEFAULT NULL,
  `nacionalidad` varchar(50) DEFAULT NULL,
  `estado` enum('activo','inactivo','suspendido') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `cliente`
--

INSERT INTO `cliente` (`idCliente`, `nombre`, `apellido`, `email`, `telefono`, `idTipoDoc`, `nroDoc`, `nacionalidad`, `estado`) VALUES
(1, 'Juan', 'Perez', 'JuanPerez@gmail.com', '+51123465789', 1, '12345678A', 'Perú', 'activo'),
(2, 'Pablo', 'Marmol', 'Pablito@gmail.com', '+34458967132', 1, '98746321', 'Perú', 'activo'),
(3, 'Juan', 'Perez', 'Usuario06@gmail.com', '+51582369741', 1, '57684239', 'Perú', 'activo'),
(4, 'Usuario', '1', 'Usuario01@gmail.com', '+51549876213', 1, '57698421', 'Perú', 'activo'),
(5, 'Usuario', '2', 'Usuario02@gmail.com', '+51159483267', 2, 'X12345678A', 'Países Bajos', 'activo'),
(6, 'usuario', '03', 'usuario03@example.com', '987654321', 2, '12345678', 'Peru', 'activo'),
(7, 'Usuario', '04', 'Usuario04@gmail.com', '+51984163543', 1, '84916237', 'Perú', 'activo'),
(8, 'Usuario', '10', 'Usuario10@gmail.com', '+51987546897', 1, '87589742', 'Perú', 'activo'),
(9, 'Usuario', '11', 'Usuario11@gmail.com', '+51985746123', 1, '57869457', 'Perú', 'activo'),
(10, 'Usuario', '12', 'Usuario12@gmail.com', '+51248964631', 1, '57684239', 'Perú', 'activo');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `empleado`
--

CREATE TABLE `empleado` (
  `idEmpleado` int(11) NOT NULL,
  `nombre` varchar(50) DEFAULT NULL,
  `apellido` varchar(50) DEFAULT NULL,
  `dni` char(8) DEFAULT NULL,
  `idFuncion` int(11) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `telefono` varchar(15) DEFAULT NULL,
  `estado` enum('activo','inactivo','suspendido') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `empleado`
--

INSERT INTO `empleado` (`idEmpleado`, `nombre`, `apellido`, `dni`, `idFuncion`, `email`, `telefono`, `estado`) VALUES
(1, 'Carlos', 'Pérez', '12345678', 1, 'gerente@email.com', '987654321', 'activo'),
(2, 'Alberto', 'Ruiz', '12345679', 2, 'recepcionista@email.com', '987254321', 'activo'),
(3, 'empleado', '3', '12345479', 3, 'cocinero@email.com', '987654321', 'activo'),
(4, 'empleado', '4', '14345479', 4, 'servicioHabitacion@email.com', '987654321', 'activo'),
(5, 'empleado', '5', '14345479', 5, 'lavanderia@email.com', '987654321', 'activo'),
(6, 'empleado', '6', '14345479', 6, 'Mantenimiento@email.com', '987654321', 'activo'),
(7, 'empleado', '7', '14355479', 7, 'limpieza@email.com', '987654321', 'activo');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `funcion`
--

CREATE TABLE `funcion` (
  `idFuncion` int(11) NOT NULL,
  `detalle` text DEFAULT NULL,
  `activo` tinyint(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `funcion`
--

INSERT INTO `funcion` (`idFuncion`, `detalle`, `activo`) VALUES
(1, 'Gerente', 1),
(2, 'Recepcionista', 1),
(3, 'Cocinero', 1),
(4, 'Camarero', 1),
(5, 'Personal de lavandería', 1),
(6, 'Mantenimiento', 1),
(7, 'Personal de limpieza', 1),
(8, 'Administrador', 1);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `funcionservicio`
--

CREATE TABLE `funcionservicio` (
  `idFunSer` int(11) NOT NULL,
  `idFuncion` int(11) DEFAULT NULL,
  `idCtgServicio` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `funcionservicio`
--

INSERT INTO `funcionservicio` (`idFunSer`, `idFuncion`, `idCtgServicio`) VALUES
(1, 3, 1),
(2, 4, 1),
(3, 3, 2),
(4, 4, 2),
(5, 5, 3),
(6, 6, 4),
(7, 7, 5);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `habitacion`
--

CREATE TABLE `habitacion` (
  `idHabitacion` int(11) NOT NULL,
  `idTipoHbt` int(11) NOT NULL,
  `numero` varchar(10) DEFAULT NULL,
  `estado` enum('disponible','ocupada','mantenimiento','fuera_servicio') DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `habitacion`
--

INSERT INTO `habitacion` (`idHabitacion`, `idTipoHbt`, `numero`, `estado`) VALUES
(1, 1, '101', ''),
(2, 1, '102', 'disponible'),
(3, 2, '103', ''),
(4, 2, '104', 'disponible'),
(5, 3, '105', 'disponible'),
(6, 3, '106', 'disponible'),
(7, 4, '107', 'disponible'),
(8, 4, '108', 'disponible'),
(9, 5, '109', 'disponible'),
(10, 5, '110', 'disponible');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `horarioactividad`
--

CREATE TABLE `horarioactividad` (
  `idHraActividad` int(11) NOT NULL,
  `idActividad` int(11) DEFAULT NULL,
  `cupoMax` int(11) DEFAULT NULL,
  `fchInicio` datetime DEFAULT NULL,
  `fchFin` datetime DEFAULT NULL,
  `estado` enum('activo','cancelado','cerrado') DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `horarioactividad`
--

INSERT INTO `horarioactividad` (`idHraActividad`, `idActividad`, `cupoMax`, `fchInicio`, `fchFin`, `estado`, `created_at`, `updated_at`) VALUES
(1, 1, 5, '2025-06-03 09:00:00', '2025-06-03 10:00:00', 'cerrado', '2025-06-03 12:18:10', '2025-06-05 23:37:51'),
(2, 1, 5, '2025-06-03 10:00:00', '2025-06-03 11:00:00', 'cerrado', '2025-06-03 12:18:10', '2025-06-05 23:37:51'),
(3, 1, 5, '2025-06-03 11:00:00', '2025-06-03 12:00:00', 'cerrado', '2025-06-03 12:18:10', '2025-06-05 23:37:51'),
(4, 1, 5, '2025-06-03 12:00:00', '2025-06-03 13:00:00', 'cerrado', '2025-06-03 12:18:10', '2025-06-05 23:37:51'),
(5, 1, 5, '2025-06-03 13:00:00', '2025-06-03 14:00:00', 'cerrado', '2025-06-03 12:18:10', '2025-06-05 23:37:51'),
(6, 1, 5, '2025-06-03 14:00:00', '2025-06-03 15:00:00', 'cerrado', '2025-06-03 12:18:10', '2025-06-15 23:19:09'),
(7, 1, 5, '2025-06-03 15:00:00', '2025-06-03 16:00:00', 'cerrado', '2025-06-03 12:18:10', '2025-06-05 23:37:51'),
(8, 1, 5, '2025-06-03 16:00:00', '2025-06-03 17:00:00', 'cerrado', '2025-06-03 12:18:10', '2025-06-05 23:37:51'),
(9, 2, 15, '2025-06-03 10:00:00', '2025-06-03 11:30:00', 'cerrado', '2025-06-03 12:24:36', '2025-06-05 23:37:51'),
(10, 2, 15, '2025-06-03 11:30:00', '2025-06-03 13:00:00', 'cerrado', '2025-06-03 12:24:36', '2025-06-05 23:37:51'),
(11, 2, 15, '2025-06-03 13:00:00', '2025-06-03 14:30:00', 'cerrado', '2025-06-03 12:24:36', '2025-06-05 23:37:51'),
(12, 2, 15, '2025-06-03 14:30:00', '2025-06-03 16:00:00', 'cerrado', '2025-06-03 12:24:36', '2025-06-05 23:37:51'),
(13, 3, 6, '2025-06-03 08:00:00', '2025-06-03 09:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(14, 3, 6, '2025-06-03 09:00:00', '2025-06-03 10:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(15, 3, 6, '2025-06-03 10:00:00', '2025-06-03 11:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(16, 3, 6, '2025-06-03 11:00:00', '2025-06-03 12:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(17, 3, 6, '2025-06-03 12:00:00', '2025-06-03 13:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(18, 3, 6, '2025-06-03 13:00:00', '2025-06-03 14:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(19, 3, 6, '2025-06-03 14:00:00', '2025-06-03 15:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(20, 3, 6, '2025-06-03 15:00:00', '2025-06-03 16:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(21, 3, 6, '2025-06-03 16:00:00', '2025-06-03 17:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(22, 3, 6, '2025-06-03 17:00:00', '2025-06-03 18:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(23, 3, 6, '2025-06-03 18:00:00', '2025-06-03 19:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(24, 3, 6, '2025-06-03 19:00:00', '2025-06-03 20:00:00', 'cerrado', '2025-06-03 12:26:43', '2025-06-05 23:37:51'),
(25, 3, 6, '2025-06-04 08:00:00', '2025-06-04 09:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(26, 2, 15, '2025-06-04 10:00:00', '2025-06-04 11:30:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(27, 3, 6, '2025-06-04 09:00:00', '2025-06-04 10:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(28, 2, 15, '2025-06-04 11:30:00', '2025-06-04 13:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(29, 3, 6, '2025-06-04 10:00:00', '2025-06-04 11:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(30, 2, 15, '2025-06-04 13:00:00', '2025-06-04 14:30:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(31, 2, 15, '2025-06-04 14:30:00', '2025-06-04 16:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(32, 3, 6, '2025-06-04 11:00:00', '2025-06-04 12:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(33, 3, 6, '2025-06-04 12:00:00', '2025-06-04 13:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(34, 3, 6, '2025-06-04 13:00:00', '2025-06-04 14:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(35, 3, 6, '2025-06-04 14:00:00', '2025-06-04 15:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(36, 3, 6, '2025-06-04 15:00:00', '2025-06-04 16:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(37, 3, 6, '2025-06-04 16:00:00', '2025-06-04 17:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(38, 3, 6, '2025-06-04 17:00:00', '2025-06-04 18:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(39, 3, 6, '2025-06-04 18:00:00', '2025-06-04 19:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(40, 3, 6, '2025-06-04 19:00:00', '2025-06-04 20:00:00', 'cancelado', '2025-06-04 01:18:29', '2025-06-04 01:43:55'),
(41, 3, 6, '2025-06-04 08:00:00', '2025-06-04 09:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(42, 2, 15, '2025-06-04 10:00:00', '2025-06-04 11:30:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(43, 1, 5, '2025-06-04 09:00:00', '2025-06-04 10:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(44, 3, 6, '2025-06-04 09:00:00', '2025-06-04 10:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(45, 2, 15, '2025-06-04 11:30:00', '2025-06-04 13:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(46, 1, 5, '2025-06-04 10:00:00', '2025-06-04 11:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(47, 3, 6, '2025-06-04 10:00:00', '2025-06-04 11:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(48, 1, 5, '2025-06-04 11:00:00', '2025-06-04 12:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(49, 2, 15, '2025-06-04 13:00:00', '2025-06-04 14:30:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(50, 2, 15, '2025-06-04 14:30:00', '2025-06-04 16:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(51, 1, 5, '2025-06-04 12:00:00', '2025-06-04 13:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(52, 3, 6, '2025-06-04 11:00:00', '2025-06-04 12:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(53, 3, 6, '2025-06-04 12:00:00', '2025-06-04 13:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(54, 1, 5, '2025-06-04 13:00:00', '2025-06-04 14:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(55, 3, 6, '2025-06-04 13:00:00', '2025-06-04 14:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(56, 1, 5, '2025-06-04 14:00:00', '2025-06-04 15:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(57, 3, 6, '2025-06-04 14:00:00', '2025-06-04 15:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(58, 1, 5, '2025-06-04 15:00:00', '2025-06-04 16:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(59, 3, 6, '2025-06-04 15:00:00', '2025-06-04 16:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(60, 1, 5, '2025-06-04 16:00:00', '2025-06-04 17:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(61, 3, 6, '2025-06-04 16:00:00', '2025-06-04 17:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(62, 3, 6, '2025-06-04 17:00:00', '2025-06-04 18:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(63, 3, 6, '2025-06-04 18:00:00', '2025-06-04 19:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(64, 3, 6, '2025-06-04 19:00:00', '2025-06-04 20:00:00', 'cerrado', '2025-06-04 01:30:00', '2025-06-05 23:37:51'),
(65, 2, 15, '2025-06-05 10:00:00', '2025-06-05 11:30:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(66, 1, 5, '2025-06-05 09:00:00', '2025-06-05 10:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(67, 3, 6, '2025-06-05 08:00:00', '2025-06-05 09:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(68, 2, 15, '2025-06-05 11:30:00', '2025-06-05 13:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(69, 1, 5, '2025-06-05 10:00:00', '2025-06-05 11:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(70, 3, 6, '2025-06-05 09:00:00', '2025-06-05 10:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(71, 2, 15, '2025-06-05 13:00:00', '2025-06-05 14:30:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(72, 1, 5, '2025-06-05 11:00:00', '2025-06-05 12:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(73, 2, 15, '2025-06-05 14:30:00', '2025-06-05 16:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(74, 3, 6, '2025-06-05 10:00:00', '2025-06-05 11:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(75, 1, 5, '2025-06-05 12:00:00', '2025-06-05 13:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(76, 3, 6, '2025-06-05 11:00:00', '2025-06-05 12:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(77, 1, 5, '2025-06-05 13:00:00', '2025-06-05 14:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(78, 3, 6, '2025-06-05 12:00:00', '2025-06-05 13:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(79, 1, 5, '2025-06-05 14:00:00', '2025-06-05 15:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(80, 3, 6, '2025-06-05 13:00:00', '2025-06-05 14:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(81, 1, 5, '2025-06-05 15:00:00', '2025-06-05 16:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(82, 3, 6, '2025-06-05 14:00:00', '2025-06-05 15:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(83, 1, 5, '2025-06-05 16:00:00', '2025-06-05 17:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(84, 3, 6, '2025-06-05 15:00:00', '2025-06-05 16:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(85, 3, 6, '2025-06-05 16:00:00', '2025-06-05 17:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(86, 3, 6, '2025-06-05 17:00:00', '2025-06-05 18:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(87, 3, 6, '2025-06-05 18:00:00', '2025-06-05 19:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(88, 3, 6, '2025-06-05 19:00:00', '2025-06-05 20:00:00', 'cerrado', '2025-06-05 03:02:18', '2025-06-05 23:37:51'),
(89, 3, 6, '2025-06-06 08:00:00', '2025-06-06 09:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 08:00:51'),
(90, 1, 5, '2025-06-06 09:00:00', '2025-06-06 10:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 09:00:51'),
(91, 2, 15, '2025-06-06 10:00:00', '2025-06-06 11:30:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(92, 1, 5, '2025-06-06 10:00:00', '2025-06-06 11:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(93, 3, 6, '2025-06-06 09:00:00', '2025-06-06 10:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 09:00:51'),
(94, 2, 15, '2025-06-06 11:30:00', '2025-06-06 13:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(95, 1, 5, '2025-06-06 11:00:00', '2025-06-06 12:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(96, 3, 6, '2025-06-06 10:00:00', '2025-06-06 11:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(97, 2, 15, '2025-06-06 13:00:00', '2025-06-06 14:30:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(98, 1, 5, '2025-06-06 12:00:00', '2025-06-06 13:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(99, 3, 6, '2025-06-06 11:00:00', '2025-06-06 12:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(100, 2, 15, '2025-06-06 14:30:00', '2025-06-06 16:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(101, 1, 5, '2025-06-06 13:00:00', '2025-06-06 14:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(102, 3, 6, '2025-06-06 12:00:00', '2025-06-06 13:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(103, 1, 5, '2025-06-06 14:00:00', '2025-06-06 15:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(104, 3, 6, '2025-06-06 13:00:00', '2025-06-06 14:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(105, 1, 5, '2025-06-06 15:00:00', '2025-06-06 16:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 15:00:51'),
(106, 3, 6, '2025-06-06 14:00:00', '2025-06-06 15:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 14:45:11'),
(107, 1, 5, '2025-06-06 16:00:00', '2025-06-06 17:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 16:00:51'),
(108, 3, 6, '2025-06-06 15:00:00', '2025-06-06 16:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 15:00:51'),
(109, 3, 6, '2025-06-06 16:00:00', '2025-06-06 17:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-06 16:00:51'),
(110, 3, 6, '2025-06-06 17:00:00', '2025-06-06 18:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-07 01:03:01'),
(111, 3, 6, '2025-06-06 18:00:00', '2025-06-06 19:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-07 01:03:01'),
(112, 3, 6, '2025-06-06 19:00:00', '2025-06-06 20:00:00', 'cerrado', '2025-06-06 01:30:00', '2025-06-07 01:03:01'),
(113, 1, 5, '2025-06-07 09:00:00', '2025-06-07 10:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(114, 2, 15, '2025-06-07 10:00:00', '2025-06-07 11:30:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(115, 3, 6, '2025-06-07 08:00:00', '2025-06-07 09:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 08:00:51'),
(116, 2, 15, '2025-06-07 11:30:00', '2025-06-07 13:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(117, 1, 5, '2025-06-07 10:00:00', '2025-06-07 11:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(118, 3, 6, '2025-06-07 09:00:00', '2025-06-07 10:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(119, 2, 15, '2025-06-07 13:00:00', '2025-06-07 14:30:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(120, 1, 5, '2025-06-07 11:00:00', '2025-06-07 12:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(121, 3, 6, '2025-06-07 10:00:00', '2025-06-07 11:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(122, 2, 15, '2025-06-07 14:30:00', '2025-06-07 16:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 14:30:51'),
(123, 1, 5, '2025-06-07 12:00:00', '2025-06-07 13:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(124, 3, 6, '2025-06-07 11:00:00', '2025-06-07 12:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(125, 1, 5, '2025-06-07 13:00:00', '2025-06-07 14:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(126, 3, 6, '2025-06-07 12:00:00', '2025-06-07 13:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(127, 1, 5, '2025-06-07 14:00:00', '2025-06-07 15:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 14:00:51'),
(128, 3, 6, '2025-06-07 13:00:00', '2025-06-07 14:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 13:54:50'),
(129, 1, 5, '2025-06-07 15:00:00', '2025-06-07 16:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 15:00:51'),
(130, 3, 6, '2025-06-07 14:00:00', '2025-06-07 15:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 14:00:51'),
(131, 1, 5, '2025-06-07 16:00:00', '2025-06-07 17:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 16:00:51'),
(132, 3, 6, '2025-06-07 15:00:00', '2025-06-07 16:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 15:00:51'),
(133, 3, 6, '2025-06-07 16:00:00', '2025-06-07 17:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 16:00:51'),
(134, 3, 6, '2025-06-07 17:00:00', '2025-06-07 18:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 17:26:42'),
(135, 3, 6, '2025-06-07 18:00:00', '2025-06-07 19:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 18:00:51'),
(136, 3, 6, '2025-06-07 19:00:00', '2025-06-07 20:00:00', 'cerrado', '2025-06-07 01:30:00', '2025-06-07 19:00:51'),
(137, 1, 5, '2025-06-08 09:00:00', '2025-06-08 10:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(138, 1, 5, '2025-06-08 10:00:00', '2025-06-08 11:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(139, 2, 15, '2025-06-08 10:00:00', '2025-06-08 11:30:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(140, 3, 6, '2025-06-08 08:00:00', '2025-06-08 09:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(141, 2, 15, '2025-06-08 11:30:00', '2025-06-08 13:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(142, 1, 5, '2025-06-08 11:00:00', '2025-06-08 12:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(143, 3, 6, '2025-06-08 09:00:00', '2025-06-08 10:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(144, 1, 5, '2025-06-08 12:00:00', '2025-06-08 13:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(145, 2, 15, '2025-06-08 13:00:00', '2025-06-08 14:30:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(146, 3, 6, '2025-06-08 10:00:00', '2025-06-08 11:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(147, 1, 5, '2025-06-08 13:00:00', '2025-06-08 14:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(148, 2, 15, '2025-06-08 14:30:00', '2025-06-08 16:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(149, 3, 6, '2025-06-08 11:00:00', '2025-06-08 12:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(150, 1, 5, '2025-06-08 14:00:00', '2025-06-08 15:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(151, 1, 5, '2025-06-08 15:00:00', '2025-06-08 16:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(152, 3, 6, '2025-06-08 12:00:00', '2025-06-08 13:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(153, 1, 5, '2025-06-08 16:00:00', '2025-06-08 17:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(154, 3, 6, '2025-06-08 13:00:00', '2025-06-08 14:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(155, 3, 6, '2025-06-08 14:00:00', '2025-06-08 15:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(156, 3, 6, '2025-06-08 15:00:00', '2025-06-08 16:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(157, 3, 6, '2025-06-08 16:00:00', '2025-06-08 17:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(158, 3, 6, '2025-06-08 17:00:00', '2025-06-08 18:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(159, 3, 6, '2025-06-08 18:00:00', '2025-06-08 19:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 18:41:49'),
(160, 3, 6, '2025-06-08 19:00:00', '2025-06-08 20:00:00', 'cerrado', '2025-06-08 02:42:26', '2025-06-08 19:00:51'),
(161, 1, 5, '2025-06-09 09:00:00', '2025-06-09 10:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 09:00:51'),
(162, 1, 5, '2025-06-09 10:00:00', '2025-06-09 11:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 10:00:51'),
(163, 2, 15, '2025-06-09 10:00:00', '2025-06-09 11:30:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 10:00:51'),
(164, 3, 6, '2025-06-09 08:00:00', '2025-06-09 09:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 08:00:51'),
(165, 1, 5, '2025-06-09 11:00:00', '2025-06-09 12:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 11:00:51'),
(166, 2, 15, '2025-06-09 11:30:00', '2025-06-09 13:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(167, 3, 6, '2025-06-09 09:00:00', '2025-06-09 10:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 09:00:51'),
(168, 1, 5, '2025-06-09 12:00:00', '2025-06-09 13:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(169, 2, 15, '2025-06-09 13:00:00', '2025-06-09 14:30:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(170, 3, 6, '2025-06-09 10:00:00', '2025-06-09 11:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 10:00:51'),
(171, 1, 5, '2025-06-09 13:00:00', '2025-06-09 14:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(172, 2, 15, '2025-06-09 14:30:00', '2025-06-09 16:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(173, 3, 6, '2025-06-09 11:00:00', '2025-06-09 12:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 11:00:51'),
(174, 1, 5, '2025-06-09 14:00:00', '2025-06-09 15:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(175, 3, 6, '2025-06-09 12:00:00', '2025-06-09 13:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(176, 1, 5, '2025-06-09 15:00:00', '2025-06-09 16:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(177, 3, 6, '2025-06-09 13:00:00', '2025-06-09 14:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(178, 1, 5, '2025-06-09 16:00:00', '2025-06-09 17:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(179, 3, 6, '2025-06-09 14:00:00', '2025-06-09 15:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(180, 3, 6, '2025-06-09 15:00:00', '2025-06-09 16:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(181, 3, 6, '2025-06-09 16:00:00', '2025-06-09 17:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 16:02:58'),
(182, 3, 6, '2025-06-09 17:00:00', '2025-06-09 18:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 17:00:51'),
(183, 3, 6, '2025-06-09 18:00:00', '2025-06-09 19:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 18:00:51'),
(184, 3, 6, '2025-06-09 19:00:00', '2025-06-09 20:00:00', 'cerrado', '2025-06-09 01:30:00', '2025-06-09 19:00:51'),
(185, 3, 6, '2025-06-10 08:00:00', '2025-06-10 09:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 11:56:47'),
(186, 3, 6, '2025-06-10 09:00:00', '2025-06-10 10:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 11:56:47'),
(187, 2, 15, '2025-06-10 10:00:00', '2025-06-10 11:30:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 11:56:47'),
(188, 1, 5, '2025-06-10 09:00:00', '2025-06-10 10:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 11:56:47'),
(189, 3, 6, '2025-06-10 10:00:00', '2025-06-10 11:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 11:56:47'),
(190, 2, 15, '2025-06-10 11:30:00', '2025-06-10 13:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 11:56:47'),
(191, 1, 5, '2025-06-10 10:00:00', '2025-06-10 11:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 11:56:47'),
(192, 3, 6, '2025-06-10 11:00:00', '2025-06-10 12:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 11:56:47'),
(193, 2, 15, '2025-06-10 13:00:00', '2025-06-10 14:30:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 13:00:51'),
(194, 1, 5, '2025-06-10 11:00:00', '2025-06-10 12:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 11:56:47'),
(195, 3, 6, '2025-06-10 12:00:00', '2025-06-10 13:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 12:00:51'),
(196, 2, 15, '2025-06-10 14:30:00', '2025-06-10 16:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 21:57:45'),
(197, 1, 5, '2025-06-10 12:00:00', '2025-06-10 13:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 12:00:51'),
(198, 3, 6, '2025-06-10 13:00:00', '2025-06-10 14:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 13:00:51'),
(199, 1, 5, '2025-06-10 13:00:00', '2025-06-10 14:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 13:00:51'),
(200, 3, 6, '2025-06-10 14:00:00', '2025-06-10 15:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 14:00:51'),
(201, 1, 5, '2025-06-10 14:00:00', '2025-06-10 15:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 14:00:51'),
(202, 3, 6, '2025-06-10 15:00:00', '2025-06-10 16:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 21:57:45'),
(203, 1, 5, '2025-06-10 15:00:00', '2025-06-10 16:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 21:57:45'),
(204, 3, 6, '2025-06-10 16:00:00', '2025-06-10 17:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 21:57:45'),
(205, 1, 5, '2025-06-10 16:00:00', '2025-06-10 17:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 21:57:45'),
(206, 3, 6, '2025-06-10 17:00:00', '2025-06-10 18:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 21:57:45'),
(207, 3, 6, '2025-06-10 18:00:00', '2025-06-10 19:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 21:57:45'),
(208, 3, 6, '2025-06-10 19:00:00', '2025-06-10 20:00:00', 'cerrado', '2025-06-10 01:30:00', '2025-06-10 21:57:45'),
(209, 2, 15, '2025-06-11 10:00:00', '2025-06-11 11:30:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 10:00:51'),
(210, 1, 5, '2025-06-11 09:00:00', '2025-06-11 10:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 09:00:51'),
(211, 2, 15, '2025-06-11 11:30:00', '2025-06-11 13:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 11:30:51'),
(212, 2, 15, '2025-06-11 13:00:00', '2025-06-11 14:30:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 13:15:37'),
(213, 1, 5, '2025-06-11 10:00:00', '2025-06-11 11:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 10:00:51'),
(214, 2, 15, '2025-06-11 14:30:00', '2025-06-11 16:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 14:30:51'),
(215, 3, 6, '2025-06-11 08:00:00', '2025-06-11 09:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 08:00:51'),
(216, 1, 5, '2025-06-11 11:00:00', '2025-06-11 12:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 11:00:51'),
(217, 3, 6, '2025-06-11 09:00:00', '2025-06-11 10:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 09:00:51'),
(218, 1, 5, '2025-06-11 12:00:00', '2025-06-11 13:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 12:00:51'),
(219, 3, 6, '2025-06-11 10:00:00', '2025-06-11 11:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 10:00:51'),
(220, 1, 5, '2025-06-11 13:00:00', '2025-06-11 14:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 13:15:37'),
(221, 3, 6, '2025-06-11 11:00:00', '2025-06-11 12:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 11:00:51'),
(222, 1, 5, '2025-06-11 14:00:00', '2025-06-11 15:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 14:00:51'),
(223, 3, 6, '2025-06-11 12:00:00', '2025-06-11 13:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 12:00:51'),
(224, 1, 5, '2025-06-11 15:00:00', '2025-06-11 16:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 15:00:51'),
(225, 3, 6, '2025-06-11 13:00:00', '2025-06-11 14:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 13:15:37'),
(226, 1, 5, '2025-06-11 16:00:00', '2025-06-11 17:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 16:00:51'),
(227, 3, 6, '2025-06-11 14:00:00', '2025-06-11 15:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 14:00:51'),
(228, 3, 6, '2025-06-11 15:00:00', '2025-06-11 16:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 15:00:51'),
(229, 3, 6, '2025-06-11 16:00:00', '2025-06-11 17:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 16:00:51'),
(230, 3, 6, '2025-06-11 17:00:00', '2025-06-11 18:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 17:00:51'),
(231, 3, 6, '2025-06-11 18:00:00', '2025-06-11 19:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 18:00:51'),
(232, 3, 6, '2025-06-11 19:00:00', '2025-06-11 20:00:00', 'cerrado', '2025-06-11 01:30:00', '2025-06-11 19:00:51'),
(233, 1, 5, '2025-06-12 09:00:00', '2025-06-12 10:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 09:00:51'),
(234, 2, 15, '2025-06-12 10:00:00', '2025-06-12 11:30:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 10:00:51'),
(235, 3, 6, '2025-06-12 08:00:00', '2025-06-12 09:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 08:00:51'),
(236, 2, 15, '2025-06-12 11:30:00', '2025-06-12 13:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 11:30:51'),
(237, 1, 5, '2025-06-12 10:00:00', '2025-06-12 11:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 10:00:51'),
(238, 3, 6, '2025-06-12 09:00:00', '2025-06-12 10:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 09:00:51'),
(239, 1, 5, '2025-06-12 11:00:00', '2025-06-12 12:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 11:00:51'),
(240, 2, 15, '2025-06-12 13:00:00', '2025-06-12 14:30:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 13:00:51'),
(241, 3, 6, '2025-06-12 10:00:00', '2025-06-12 11:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 10:00:51'),
(242, 1, 5, '2025-06-12 12:00:00', '2025-06-12 13:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 12:00:51'),
(243, 2, 15, '2025-06-12 14:30:00', '2025-06-12 16:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 14:30:51'),
(244, 3, 6, '2025-06-12 11:00:00', '2025-06-12 12:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 11:00:51'),
(245, 1, 5, '2025-06-12 13:00:00', '2025-06-12 14:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 13:00:51'),
(246, 3, 6, '2025-06-12 12:00:00', '2025-06-12 13:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 12:00:51'),
(247, 1, 5, '2025-06-12 14:00:00', '2025-06-12 15:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 14:00:51'),
(248, 3, 6, '2025-06-12 13:00:00', '2025-06-12 14:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 13:00:51'),
(249, 1, 5, '2025-06-12 15:00:00', '2025-06-12 16:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 15:25:22'),
(250, 3, 6, '2025-06-12 14:00:00', '2025-06-12 15:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 14:00:51'),
(251, 1, 5, '2025-06-12 16:00:00', '2025-06-12 17:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-13 03:40:13'),
(252, 3, 6, '2025-06-12 15:00:00', '2025-06-12 16:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-12 15:25:22'),
(253, 3, 6, '2025-06-12 16:00:00', '2025-06-12 17:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-13 03:40:13'),
(254, 3, 6, '2025-06-12 17:00:00', '2025-06-12 18:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-13 03:40:13'),
(255, 3, 6, '2025-06-12 18:00:00', '2025-06-12 19:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-13 03:40:13'),
(256, 3, 6, '2025-06-12 19:00:00', '2025-06-12 20:00:00', 'cerrado', '2025-06-12 01:30:00', '2025-06-13 03:40:13'),
(257, 1, 5, '2025-06-13 09:00:00', '2025-06-13 10:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 11:16:35'),
(258, 3, 6, '2025-06-13 08:00:00', '2025-06-13 09:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 11:16:35'),
(259, 2, 15, '2025-06-13 10:00:00', '2025-06-13 11:30:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 11:16:35'),
(260, 3, 6, '2025-06-13 09:00:00', '2025-06-13 10:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 11:16:35'),
(261, 1, 5, '2025-06-13 10:00:00', '2025-06-13 11:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 11:16:35'),
(262, 2, 15, '2025-06-13 11:30:00', '2025-06-13 13:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 11:30:51'),
(263, 3, 6, '2025-06-13 10:00:00', '2025-06-13 11:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 11:16:35'),
(264, 1, 5, '2025-06-13 11:00:00', '2025-06-13 12:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 11:16:35'),
(265, 2, 15, '2025-06-13 13:00:00', '2025-06-13 14:30:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 13:00:51'),
(266, 3, 6, '2025-06-13 11:00:00', '2025-06-13 12:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 11:16:35'),
(267, 1, 5, '2025-06-13 12:00:00', '2025-06-13 13:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 12:00:51'),
(268, 2, 15, '2025-06-13 14:30:00', '2025-06-13 16:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 14:30:51'),
(269, 1, 5, '2025-06-13 13:00:00', '2025-06-13 14:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 13:00:51'),
(270, 3, 6, '2025-06-13 12:00:00', '2025-06-13 13:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 12:00:51'),
(271, 1, 5, '2025-06-13 14:00:00', '2025-06-13 15:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 14:00:51'),
(272, 3, 6, '2025-06-13 13:00:00', '2025-06-13 14:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 13:00:51'),
(273, 1, 5, '2025-06-13 15:00:00', '2025-06-13 16:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 15:18:16'),
(274, 3, 6, '2025-06-13 14:00:00', '2025-06-13 15:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 14:00:51'),
(275, 1, 5, '2025-06-13 16:00:00', '2025-06-13 17:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 16:11:31'),
(276, 3, 6, '2025-06-13 15:00:00', '2025-06-13 16:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 15:18:16'),
(277, 3, 6, '2025-06-13 16:00:00', '2025-06-13 17:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 16:11:31'),
(278, 3, 6, '2025-06-13 17:00:00', '2025-06-13 18:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-13 17:20:11'),
(279, 3, 6, '2025-06-13 18:00:00', '2025-06-13 19:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-15 02:49:51'),
(280, 3, 6, '2025-06-13 19:00:00', '2025-06-13 20:00:00', 'cerrado', '2025-06-13 03:40:13', '2025-06-15 02:49:51'),
(281, 2, 15, '2025-06-15 10:00:00', '2025-06-15 11:30:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 10:29:21'),
(282, 3, 6, '2025-06-15 08:00:00', '2025-06-15 09:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 08:00:51'),
(283, 2, 15, '2025-06-15 11:30:00', '2025-06-15 13:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 11:47:24'),
(284, 1, 5, '2025-06-15 09:00:00', '2025-06-15 10:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 09:00:51'),
(285, 3, 6, '2025-06-15 09:00:00', '2025-06-15 10:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 09:00:51'),
(286, 2, 15, '2025-06-15 13:00:00', '2025-06-15 14:30:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 13:00:51'),
(287, 1, 5, '2025-06-15 10:00:00', '2025-06-15 11:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 10:29:21'),
(288, 2, 15, '2025-06-15 14:30:00', '2025-06-15 16:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 14:30:51'),
(289, 3, 6, '2025-06-15 10:00:00', '2025-06-15 11:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 10:29:21'),
(290, 1, 5, '2025-06-15 11:00:00', '2025-06-15 12:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 11:00:51'),
(291, 3, 6, '2025-06-15 11:00:00', '2025-06-15 12:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 11:00:51'),
(292, 1, 5, '2025-06-15 12:00:00', '2025-06-15 13:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 12:00:51'),
(293, 3, 6, '2025-06-15 12:00:00', '2025-06-15 13:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 12:00:51'),
(294, 1, 5, '2025-06-15 13:00:00', '2025-06-15 14:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 13:00:51'),
(295, 3, 6, '2025-06-15 13:00:00', '2025-06-15 14:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 13:00:51'),
(296, 1, 5, '2025-06-15 14:00:00', '2025-06-15 15:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 14:00:51'),
(297, 3, 6, '2025-06-15 14:00:00', '2025-06-15 15:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 14:00:51'),
(298, 1, 5, '2025-06-15 15:00:00', '2025-06-15 16:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 15:00:51'),
(299, 3, 6, '2025-06-15 15:00:00', '2025-06-15 16:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 15:00:51'),
(300, 1, 5, '2025-06-15 16:00:00', '2025-06-15 17:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 16:00:51'),
(301, 3, 6, '2025-06-15 16:00:00', '2025-06-15 17:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 16:00:51'),
(302, 3, 6, '2025-06-15 17:00:00', '2025-06-15 18:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 20:06:46'),
(303, 3, 6, '2025-06-15 18:00:00', '2025-06-15 19:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 20:06:46'),
(304, 3, 6, '2025-06-15 19:00:00', '2025-06-15 20:00:00', 'cerrado', '2025-06-15 03:00:00', '2025-06-15 23:19:51'),
(305, 1, 5, '2025-06-16 09:00:00', '2025-06-16 10:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 09:45:37'),
(306, 2, 15, '2025-06-16 10:00:00', '2025-06-16 11:30:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 10:00:51'),
(307, 3, 6, '2025-06-16 08:00:00', '2025-06-16 09:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 09:45:37'),
(308, 2, 15, '2025-06-16 11:30:00', '2025-06-16 13:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 11:30:51'),
(309, 1, 5, '2025-06-16 10:00:00', '2025-06-16 11:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 10:00:51'),
(310, 3, 6, '2025-06-16 09:00:00', '2025-06-16 10:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 09:45:37'),
(311, 1, 5, '2025-06-16 11:00:00', '2025-06-16 12:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 11:00:51'),
(312, 2, 15, '2025-06-16 13:00:00', '2025-06-16 14:30:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 13:00:51'),
(313, 1, 5, '2025-06-16 12:00:00', '2025-06-16 13:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 12:00:51'),
(314, 3, 6, '2025-06-16 10:00:00', '2025-06-16 11:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 10:00:51'),
(315, 2, 15, '2025-06-16 14:30:00', '2025-06-16 16:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 14:30:51'),
(316, 3, 6, '2025-06-16 11:00:00', '2025-06-16 12:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 11:00:51'),
(317, 1, 5, '2025-06-16 13:00:00', '2025-06-16 14:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 13:00:51'),
(318, 3, 6, '2025-06-16 12:00:00', '2025-06-16 13:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 12:00:51'),
(319, 1, 5, '2025-06-16 14:00:00', '2025-06-16 15:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 14:00:51'),
(320, 3, 6, '2025-06-16 13:00:00', '2025-06-16 14:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 13:00:51'),
(321, 1, 5, '2025-06-16 15:00:00', '2025-06-16 16:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 15:00:51'),
(322, 3, 6, '2025-06-16 14:00:00', '2025-06-16 15:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 14:00:51'),
(323, 1, 5, '2025-06-16 16:00:00', '2025-06-16 17:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 16:00:51'),
(324, 3, 6, '2025-06-16 15:00:00', '2025-06-16 16:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 15:00:51'),
(325, 3, 6, '2025-06-16 16:00:00', '2025-06-16 17:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 16:00:51'),
(326, 3, 6, '2025-06-16 17:00:00', '2025-06-16 18:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 17:00:51'),
(327, 3, 6, '2025-06-16 18:00:00', '2025-06-16 19:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 18:00:51'),
(328, 3, 6, '2025-06-16 19:00:00', '2025-06-16 20:00:00', 'cerrado', '2025-06-16 01:35:00', '2025-06-16 19:00:51'),
(329, 2, 15, '2025-06-17 10:00:00', '2025-06-17 11:30:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 10:00:51'),
(330, 2, 15, '2025-06-17 11:30:00', '2025-06-17 13:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 11:30:51'),
(331, 3, 6, '2025-06-17 08:00:00', '2025-06-17 09:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 08:00:51'),
(332, 1, 5, '2025-06-17 09:00:00', '2025-06-17 10:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 09:00:51'),
(333, 2, 15, '2025-06-17 13:00:00', '2025-06-17 14:30:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 13:00:51'),
(334, 1, 5, '2025-06-17 10:00:00', '2025-06-17 11:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 10:00:51'),
(335, 3, 6, '2025-06-17 09:00:00', '2025-06-17 10:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 09:00:51'),
(336, 2, 15, '2025-06-17 14:30:00', '2025-06-17 16:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 14:30:51'),
(337, 1, 5, '2025-06-17 11:00:00', '2025-06-17 12:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 11:00:51'),
(338, 3, 6, '2025-06-17 10:00:00', '2025-06-17 11:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 10:00:51'),
(339, 1, 5, '2025-06-17 12:00:00', '2025-06-17 13:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 12:00:51'),
(340, 3, 6, '2025-06-17 11:00:00', '2025-06-17 12:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 11:00:51'),
(341, 1, 5, '2025-06-17 13:00:00', '2025-06-17 14:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 13:00:51'),
(342, 3, 6, '2025-06-17 12:00:00', '2025-06-17 13:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 12:00:51'),
(343, 1, 5, '2025-06-17 14:00:00', '2025-06-17 15:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 14:00:51'),
(344, 3, 6, '2025-06-17 13:00:00', '2025-06-17 14:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 13:00:51'),
(345, 1, 5, '2025-06-17 15:00:00', '2025-06-17 16:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 15:00:51'),
(346, 3, 6, '2025-06-17 14:00:00', '2025-06-17 15:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 14:00:51'),
(347, 1, 5, '2025-06-17 16:00:00', '2025-06-17 17:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 16:00:51'),
(348, 3, 6, '2025-06-17 15:00:00', '2025-06-17 16:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 15:00:51'),
(349, 3, 6, '2025-06-17 16:00:00', '2025-06-17 17:00:00', 'cerrado', '2025-06-17 01:35:00', '2025-06-17 16:00:51'),
(350, 3, 6, '2025-06-17 17:00:00', '2025-06-17 18:00:00', 'activo', '2025-06-17 01:35:00', '2025-06-17 01:35:00'),
(351, 3, 6, '2025-06-17 18:00:00', '2025-06-17 19:00:00', 'activo', '2025-06-17 01:35:00', '2025-06-17 01:35:00'),
(352, 3, 6, '2025-06-17 19:00:00', '2025-06-17 20:00:00', 'activo', '2025-06-17 01:35:00', '2025-06-17 01:35:00');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `inscripcion`
--

CREATE TABLE `inscripcion` (
  `idInscripcion` int(11) NOT NULL,
  `idHraActividad` int(11) DEFAULT NULL,
  `idCliente` int(11) DEFAULT NULL,
  `fchInscripcion` datetime DEFAULT NULL,
  `estado` enum('confirmada','cancelada','pendiente') DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `inscripcion`
--

INSERT INTO `inscripcion` (`idInscripcion`, `idHraActividad`, `idCliente`, `fchInscripcion`, `estado`, `created_at`, `updated_at`) VALUES
(1, 66, 1, '2025-06-05 05:41:12', 'confirmada', '2025-06-05 05:41:59', '2025-06-05 05:41:59'),
(2, 66, 1, '2025-06-05 07:58:11', 'confirmada', '2025-06-05 07:58:11', '2025-06-05 07:58:11'),
(3, 66, 1, '2025-06-05 07:58:25', 'confirmada', '2025-06-05 07:58:25', '2025-06-05 07:58:25'),
(4, 66, 1, '2025-06-05 07:58:26', 'confirmada', '2025-06-05 07:58:26', '2025-06-05 07:58:26'),
(5, 66, 1, '2025-06-05 08:02:41', 'confirmada', '2025-06-05 08:02:41', '2025-06-05 08:02:41'),
(6, 69, 4, '2025-06-05 22:19:44', 'confirmada', '2025-06-05 22:19:44', '2025-06-05 22:19:44'),
(7, 69, 4, '2025-06-05 22:31:03', 'confirmada', '2025-06-05 22:31:03', '2025-06-05 22:31:03'),
(8, 72, 4, '2025-06-05 23:21:44', 'confirmada', '2025-06-05 23:21:44', '2025-06-05 23:21:44'),
(9, 69, 4, '2025-06-05 23:24:58', 'confirmada', '2025-06-05 23:24:58', '2025-06-05 23:24:58'),
(10, 69, 4, '2025-06-05 23:24:58', 'confirmada', '2025-06-05 23:24:58', '2025-06-05 23:24:58'),
(11, 69, 4, '2025-06-05 23:26:04', 'confirmada', '2025-06-05 23:26:04', '2025-06-05 23:26:04'),
(12, 72, 4, '2025-06-05 23:33:09', 'confirmada', '2025-06-05 23:33:09', '2025-06-05 23:33:09'),
(13, 72, 4, '2025-06-05 23:33:09', 'confirmada', '2025-06-05 23:33:09', '2025-06-05 23:33:09'),
(14, 137, 4, '2025-06-08 04:17:56', 'confirmada', '2025-06-08 04:17:56', '2025-06-08 04:17:56'),
(15, 233, 4, '2025-06-12 05:09:34', 'confirmada', '2025-06-12 05:09:34', '2025-06-12 05:09:34'),
(16, 234, 4, '2025-06-12 08:36:23', 'confirmada', '2025-06-12 08:36:23', '2025-06-12 08:36:23'),
(17, 284, 4, '2025-06-15 03:05:05', 'confirmada', '2025-06-15 03:05:05', '2025-06-15 03:05:05'),
(18, 284, 4, '2025-06-15 03:05:05', 'confirmada', '2025-06-15 03:05:05', '2025-06-15 03:05:05'),
(19, 284, 4, '2025-06-15 03:05:05', 'confirmada', '2025-06-15 03:05:05', '2025-06-15 03:05:05'),
(20, 284, 4, '2025-06-15 03:05:05', 'confirmada', '2025-06-15 03:05:05', '2025-06-15 03:05:05'),
(21, 284, 4, '2025-06-15 03:05:05', 'confirmada', '2025-06-15 03:05:05', '2025-06-15 03:05:05'),
(22, 305, 4, '2025-06-16 01:35:08', 'confirmada', '2025-06-16 01:35:08', '2025-06-16 01:35:08');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `producto`
--

CREATE TABLE `producto` (
  `idProducto` int(11) NOT NULL,
  `nombre` text DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  `precio` decimal(10,2) DEFAULT NULL,
  `idCtgComida` int(11) DEFAULT NULL,
  `estado` enum('activo','inactivo') DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `producto`
--

INSERT INTO `producto` (`idProducto`, `nombre`, `descripcion`, `precio`, `idCtgComida`, `estado`, `created_at`, `updated_at`) VALUES
(1, 'Orange', 'Naranja\r\nTe verde', 22.00, 1, 'activo', '2025-05-25 22:08:28', '2025-06-16 02:01:26'),
(2, 'Dosis c', 'Cacao\nHierba buena\nPiña', 20.00, 1, 'activo', '2025-05-25 22:08:30', '2025-06-15 12:08:24'),
(3, 'Vitam-ina', 'Cafe\r\nTamarindo\r\nMango', 20.00, 1, 'activo', '2025-05-25 22:11:44', '2025-06-15 12:13:22'),
(4, 'Mojo Berries', 'Arandanos\r\nPiña\r\nMenta', 22.00, 1, 'activo', '2025-05-25 22:12:37', '2025-05-26 05:34:17'),
(5, 'Ceviche Pesca del Dia', 'Leche de tigre al ají amarillo ahumado, choclo, camote caramelizado, ají limo (tambien puedes pedirlo en clásico).', 49.00, 2, 'activo', '2025-06-16 02:31:58', '2025-06-16 02:31:58'),
(6, 'Tataki de Bonito', 'Salsa acevichada de palta, masa de causa, pepino, mango, demiglace oriental, fansi crocante', 42.00, 2, 'activo', '2025-06-16 02:39:02', '2025-06-16 02:39:02'),
(7, 'Caesar Salad', 'Lechuga romana, tocino, croutones, queso parmesano, aceite de oliva (pollo adicional).', 42.00, 2, 'activo', '2025-06-16 02:41:46', '2025-06-16 05:33:15'),
(8, 'Ensalada de Pollo en Quinoa', 'Lechuga americana, praliné de pecanas, palta, rabanito, vinagreta de yogurt y queso azul.', 39.00, 2, 'activo', '2025-06-16 05:33:44', '2025-06-16 05:33:44');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `resenia`
--

CREATE TABLE `resenia` (
  `idRsnServicio` int(11) NOT NULL,
  `idServicio` int(11) DEFAULT NULL,
  `calificacion` int(11) DEFAULT NULL CHECK (`calificacion` between 1 and 5),
  `comentario` text DEFAULT NULL,
  `fchResenia` datetime DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `resenia`
--

INSERT INTO `resenia` (`idRsnServicio`, `idServicio`, `calificacion`, `comentario`, `fchResenia`, `created_at`, `updated_at`) VALUES
(1, 22, 5, 'Todo perfecto', '2025-06-17 10:42:21', '2025-06-17 10:42:21', '2025-06-17 11:44:47');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `reservahbt`
--

CREATE TABLE `reservahbt` (
  `idReservaHbt` int(11) NOT NULL,
  `idCliente` int(11) DEFAULT NULL,
  `idHabitacion` int(11) DEFAULT NULL,
  `fchInicio` datetime DEFAULT NULL,
  `fchFin` datetime DEFAULT NULL,
  `horaSalida` datetime DEFAULT NULL,
  `estado` enum('activa','cancelada','finalizada') DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `reservahbt`
--

INSERT INTO `reservahbt` (`idReservaHbt`, `idCliente`, `idHabitacion`, `fchInicio`, `fchFin`, `horaSalida`, `estado`, `created_at`, `updated_at`) VALUES
(1, 4, 1, '2025-05-27 14:00:00', '2025-05-29 12:00:00', NULL, 'activa', '2025-05-24 13:40:51', '2025-05-24 16:39:34'),
(2, 5, 1, '2025-05-29 14:00:00', '2025-05-31 12:00:00', NULL, 'activa', '2025-05-24 13:40:51', '2025-05-24 16:39:37'),
(3, 4, 2, '2025-05-27 14:00:00', '2025-05-29 12:00:00', NULL, 'activa', '2025-05-24 13:40:54', '2025-05-24 19:33:39'),
(4, 5, 2, '2025-05-30 14:00:00', '2025-05-31 12:00:00', NULL, 'activa', '2025-05-24 13:40:54', '2025-05-24 21:21:24'),
(6, 1, 1, '2025-06-01 14:00:00', '2025-06-05 12:00:00', NULL, 'activa', '2025-05-25 15:39:26', '2025-05-27 01:00:56'),
(7, 4, 1, '2025-05-25 14:00:00', '2025-05-27 12:00:00', NULL, 'activa', '2025-05-25 16:48:10', '2025-05-27 01:00:59'),
(9, 4, 2, '2025-05-29 14:00:00', '2025-05-30 12:00:00', NULL, 'activa', '2025-05-25 16:54:19', '2025-05-25 16:54:19'),
(10, 4, 2, '2025-06-02 14:00:00', '2025-06-08 12:00:00', NULL, 'activa', '2025-05-26 08:43:51', '2025-05-26 08:43:51'),
(11, 4, 1, '2025-06-05 14:00:00', '2025-06-13 12:00:00', NULL, 'activa', '2025-05-27 01:02:48', '2025-05-27 01:02:48'),
(12, 4, 3, '2025-05-28 14:00:00', '2025-05-31 12:00:00', NULL, 'activa', '2025-05-27 04:20:26', '2025-05-27 04:20:26'),
(13, 4, 4, '2025-05-27 14:00:00', '2025-05-30 12:00:00', NULL, 'activa', '2025-05-27 04:42:14', '2025-05-27 04:42:14'),
(14, 4, 3, '2025-06-03 14:00:00', '2025-06-05 12:00:00', NULL, 'activa', '2025-05-27 05:26:12', '2025-05-27 05:26:12'),
(15, 7, 3, '2025-06-13 14:00:00', '2025-06-30 12:00:00', NULL, 'activa', '2025-06-13 05:24:53', '2025-06-13 05:24:53'),
(16, 4, 1, '2025-06-17 14:00:00', '2025-06-20 12:00:00', NULL, 'activa', '2025-06-15 02:27:31', '2025-06-15 02:27:31'),
(17, 4, 7, '2025-06-18 14:00:00', '2025-06-26 12:00:00', NULL, 'activa', '2025-06-15 03:26:21', '2025-06-15 03:26:21');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `servicio`
--

CREATE TABLE `servicio` (
  `idServicio` int(11) NOT NULL,
  `idCliente` int(11) DEFAULT NULL,
  `idCtgServicio` int(11) DEFAULT NULL,
  `idHabitacion` int(11) DEFAULT NULL,
  `estado` enum('activo','cancelado','pendiente','finalizado') DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `servicio`
--

INSERT INTO `servicio` (`idServicio`, `idCliente`, `idCtgServicio`, `idHabitacion`, `estado`, `created_at`, `updated_at`) VALUES
(1, 4, 2, 1, 'activo', '2025-06-09 05:07:16', '2025-06-09 05:07:16'),
(2, 4, 4, 1, 'activo', '2025-06-09 05:09:36', '2025-06-09 05:09:36'),
(3, 4, 3, 1, 'activo', '2025-06-09 05:10:45', '2025-06-09 05:10:45'),
(4, 4, 5, 1, 'activo', '2025-06-09 05:12:35', '2025-06-09 05:12:35'),
(5, 4, 5, 1, 'activo', '2025-06-09 05:12:52', '2025-06-09 05:12:52'),
(6, 4, 5, 1, 'activo', '2025-06-09 05:13:34', '2025-06-09 05:13:34'),
(7, 4, 1, 1, 'activo', '2025-06-09 05:39:11', '2025-06-09 05:39:11'),
(8, 4, 1, 1, 'activo', '2025-06-09 07:12:01', '2025-06-09 07:12:01'),
(9, 4, 2, 1, 'activo', '2025-06-09 07:14:16', '2025-06-09 07:14:16'),
(10, 4, 1, 1, 'activo', '2025-06-09 07:14:50', '2025-06-09 07:14:50'),
(11, 4, 1, 1, 'activo', '2025-06-09 07:25:01', '2025-06-09 07:25:01'),
(12, 4, 1, 1, 'activo', '2025-06-09 07:26:11', '2025-06-09 07:26:11'),
(13, 4, 1, 1, 'activo', '2025-06-09 07:27:41', '2025-06-09 07:27:41'),
(14, 4, 1, 1, 'activo', '2025-06-09 20:01:37', '2025-06-09 20:01:37'),
(15, 4, 1, 1, 'activo', '2025-06-09 21:44:38', '2025-06-09 21:44:38'),
(16, 4, 1, 1, 'activo', '2025-06-09 21:44:49', '2025-06-09 21:44:49'),
(17, 4, 1, 1, 'activo', '2025-06-09 23:19:29', '2025-06-09 23:19:29'),
(18, 7, 2, 3, 'finalizado', '2025-06-13 05:25:10', '2025-06-14 05:06:40'),
(19, 4, 1, 1, 'activo', '2025-06-13 19:46:39', '2025-06-13 19:46:39'),
(20, 4, 1, 1, 'activo', '2025-06-14 08:39:17', '2025-06-14 08:39:17'),
(21, 4, 1, 1, 'activo', '2025-06-15 15:47:34', '2025-06-15 15:47:34'),
(22, 4, 2, 1, 'finalizado', '2025-06-16 02:10:12', '2025-06-17 05:52:07');

--
-- Disparadores `servicio`
--
DELIMITER $$
CREATE TRIGGER `trg_post_insert_servicio` AFTER INSERT ON `servicio` FOR EACH ROW BEGIN
    -- Variables
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_idFuncion INT;
    DECLARE v_idEmpleado INT;

    -- Cursor para funciones asociadas
    DECLARE cur_funciones CURSOR FOR
        SELECT idFuncion
        FROM funcionservicio
        WHERE idCtgServicio = NEW.idCtgServicio;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN cur_funciones;

    funciones_loop: LOOP
        FETCH cur_funciones INTO v_idFuncion;
        IF done THEN
            LEAVE funciones_loop;
        END IF;

        -- Selección por menos carga y asignación más antigua
        SELECT e.idEmpleado INTO v_idEmpleado
        FROM empleado e
        LEFT JOIN (
            SELECT idEmpleado,
                   COUNT(*) AS total,
                   MAX(fchAsignacion) AS ultimaAsignacion
            FROM asignacionservicio
            GROUP BY idEmpleado
        ) a ON e.idEmpleado = a.idEmpleado
        WHERE e.idFuncion = v_idFuncion AND e.estado = 'activo'
        ORDER BY 
            IFNULL(a.total, 0) ASC,
            IFNULL(a.ultimaAsignacion, '2000-01-01') ASC,
            e.idEmpleado ASC
        LIMIT 1;

        -- Insertar asignación
        IF v_idEmpleado IS NOT NULL THEN
            INSERT INTO asignacionservicio (
                idEmpleado,
                idServicio,
                fchAsignacion
            ) VALUES (
                v_idEmpleado,
                NEW.idServicio,
                NOW()
            );
        END IF;

    END LOOP;

    CLOSE cur_funciones;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `serviciocomida`
--

CREATE TABLE `serviciocomida` (
  `idSerCom` int(11) NOT NULL,
  `idProducto` int(11) DEFAULT NULL,
  `idServicio` int(11) DEFAULT NULL,
  `cantidad` int(11) DEFAULT NULL,
  `precio` decimal(10,0) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `serviciocomida`
--

INSERT INTO `serviciocomida` (`idSerCom`, `idProducto`, `idServicio`, `cantidad`, `precio`) VALUES
(1, 1, 13, 2, 22),
(2, 2, 13, 1, 20),
(3, 3, 13, 1, 20),
(4, 4, 14, 1, 22),
(5, 2, 14, 1, 20),
(6, 4, 15, 1, 22),
(7, 2, 15, 1, 20),
(8, 4, 16, 1, 22),
(9, 1, 17, 1, 22),
(10, 2, 17, 1, 20),
(11, 3, 17, 1, 20),
(12, 4, 17, 1, 22),
(13, 2, 19, 1, 20),
(14, 3, 19, 1, 20),
(15, 2, 20, 1, 20),
(16, 4, 20, 1, 22),
(17, 1, 21, 1, 22),
(18, 3, 21, 1, 20);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipodocumento`
--

CREATE TABLE `tipodocumento` (
  `idTipoDoc` int(11) NOT NULL,
  `nombre` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tipodocumento`
--

INSERT INTO `tipodocumento` (`idTipoDoc`, `nombre`) VALUES
(1, 'DNI'),
(2, 'NIE'),
(3, 'Pasaporte');

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `tipohabitacion`
--

CREATE TABLE `tipohabitacion` (
  `idTipoHbt` int(11) NOT NULL,
  `nombre` text NOT NULL,
  `descripcion` text NOT NULL,
  `tamano` varchar(10) NOT NULL,
  `cama` text NOT NULL,
  `adultos` int(11) NOT NULL,
  `ninos` int(11) NOT NULL,
  `precio` decimal(10,0) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Volcado de datos para la tabla `tipohabitacion`
--

INSERT INTO `tipohabitacion` (`idTipoHbt`, `nombre`, `descripcion`, `tamano`, `cama`, `adultos`, `ninos`, `precio`) VALUES
(1, 'Habitacion Deluxe Individual', 'Disfruta de una experiencia increíble en una cómoda habitación con una cama full-size (120 cm x 200 cm), una zona de estar y todos los servicios necesarios para tener una estadía única llena de confort. Ideal para viajeros o ejecutivos que necesitan hospedarse en un sitio céntrico, cómodo y con una atención a detalle.', '22', 'Large Single Bed', 1, 0, 455),
(2, 'Habitacion Deluxe Matrimonial Accesible', 'Habitación con barras de apoyo en el baño. Disfruta de una experiencia increíble en una cómoda habitación con una cama queen (153 cm x 203 cm), una zona de estar y todos los servicios necesarios para tener una estadía única llena de confort. Ideal para viajeros o ejecutivos que necesitan hospedarse en un sitio céntrico, cómodo y con una atención a detalle.', '30', 'Cama Queen', 2, 0, 468),
(3, 'Habitacion Deluxe Plus Matrimonial', 'Disfruta de una experiencia increíble en una cómoda habitación con una cama king (198 cm x 203 cm), una zona de estar y todos los servicios necesarios para tener una estadía única llena de confort. Ideal para viajeros o ejecutivos que necesitan hospedarse en un sitio céntrico, cómodo y con una atención a detalle.', '27', 'Cama King', 2, 0, 528),
(4, 'Habitacion Deluxe Doble', 'Experimenta una estadía única en nuestra habitación deluxe doble que cuenta con 2 camas full-size (120 cm x 200 cm) y todos los servicios necesarios para tener una experiencia única. Perfecta para aquellas personas que buscan un ambiente cálido, espacioso y funcional.\r\n\r\n\r\n', '29', 'Large Single Bed', 2, 2, 468),
(5, 'Habitacion Deluxe Matrimonial', 'Disfruta de una experiencia increíble en una cómoda habitación con una cama queen (153 cm x 203 cm), una zona de estar y todos los servicios necesarios para tener una estadía única llena de confort. Ideal para viajeros o ejecutivos que necesitan hospedarse en un sitio céntrico, cómodo y con una atención a detalle.', '31', 'Cama Queen', 2, 0, 468),
(9, 'habitacion de prueba', 'test', '22', 'Large Single Bed', 2, 1, 399999);

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `usuario`
--

CREATE TABLE `usuario` (
  `idCuenta` int(11) NOT NULL,
  `contrasenia` varchar(255) DEFAULT NULL,
  `idCliente` int(11) DEFAULT NULL,
  `idEmpleado` int(11) DEFAULT NULL,
  `estado` enum('activo','inactivo','suspendido') DEFAULT NULL,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ;

--
-- Volcado de datos para la tabla `usuario`
--

INSERT INTO `usuario` (`idCuenta`, `contrasenia`, `idCliente`, `idEmpleado`, `estado`, `created_at`, `updated_at`) VALUES
(1, '$2b$10$cEuMT7SUOJ.8yORFd9of0.z27arJ8LX2T/VXDAPKHexZDkjucrqwm', 1, NULL, 'activo', '2025-05-20 22:09:58', '2025-05-20 22:09:58'),
(2, '$2b$10$Yvkl0ujIdZzyU2tRVSAq4.bkgRc6liSkEQb3y/ioqGpv5f1xproii', 2, NULL, 'activo', '2025-05-21 13:23:22', '2025-05-21 13:23:22'),
(3, '$2b$10$iSACIpo0QB6UaLJCIDm6DuVsZFFw9n/GwAStCeeDU0BO/DdkcAy8a', 3, NULL, 'activo', '2025-05-21 13:32:40', '2025-05-21 13:32:40'),
(4, '$2b$10$g2LLruyVGrlzMt5JGP49VuhkGYcj7qgJYCKL/oSUBoJ4G8D7WBuF.', 4, NULL, 'activo', '2025-05-21 13:45:21', '2025-05-21 13:45:21'),
(5, '$2b$10$a5L0pCokOQbZx7bgRsR8EO51JbaSM2Xbx91GXms2e56TFEToeL/9W', 5, NULL, 'activo', '2025-05-21 19:27:56', '2025-05-21 19:27:56'),
(6, 'gerente', NULL, 1, 'activo', '2025-06-08 04:06:38', '2025-06-08 04:07:07'),
(7, 'recepcionista', NULL, 2, 'activo', '2025-06-08 04:07:42', '2025-06-08 04:07:59'),
(8, 'cocinero', NULL, 3, 'activo', '2025-06-08 04:08:16', '2025-06-08 04:08:16'),
(9, 'servicioHabitacion', NULL, 4, 'activo', '2025-06-08 04:08:31', '2025-06-08 04:08:31'),
(10, 'lavanderia', NULL, 5, 'activo', '2025-06-08 04:08:46', '2025-06-08 04:09:24'),
(11, 'Mantenimiento', NULL, 6, 'activo', '2025-06-08 04:08:58', '2025-06-08 04:08:58'),
(12, 'limpieza', NULL, 7, 'activo', '2025-06-08 04:09:14', '2025-06-08 04:09:14'),
(13, '123', 6, NULL, 'activo', '2025-06-13 05:18:00', '2025-06-13 05:18:00'),
(14, '$2b$10$6C7Pkd7zQ/2CKTTXtl7QeeGVRW8pfLgS4tZhqYlP/LIdLm732s3Ui', 7, NULL, 'activo', '2025-06-13 05:24:28', '2025-06-13 05:24:28'),
(15, '$2b$10$cLtAmflpH/.tarxMjKA/y.XdzeSapjZU8rpNBLmL3eovplXZ8pbOe', 8, NULL, 'activo', '2025-06-16 01:51:30', '2025-06-16 01:51:30'),
(16, '$2b$10$ptA4aK13vGSby5dzY1cq4e7MJD0/Pv611wvUQxto2kjfd76L1AC4K', 9, NULL, 'activo', '2025-06-16 01:58:52', '2025-06-16 01:58:52'),
(17, '$2b$10$sNv7O1Bhi5r3j4COlVZ7VO0klDdTRwJhFDYU3w.zRoOnUIFAj9Vv2', 10, NULL, 'activo', '2025-06-16 01:59:25', '2025-06-16 01:59:25');

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_empleados_funcion`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_empleados_funcion` (
`funcion` text
,`cantidad` bigint(21)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_estado_habitaciones`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_estado_habitaciones` (
`estado` enum('disponible','ocupada','mantenimiento','fuera_servicio')
,`cantidad` bigint(21)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_horarioactividad_estado_hoy`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_horarioactividad_estado_hoy` (
`estado` enum('activo','cancelado','cerrado')
,`cantidad` bigint(21)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_inscripciones_estado`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_inscripciones_estado` (
`estado` enum('confirmada','cancelada','pendiente')
,`cantidad` bigint(21)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_productos_categoria`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_productos_categoria` (
`categoria` text
,`cantidad` bigint(21)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_reservas_estado_fecha`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_reservas_estado_fecha` (
`estado` enum('activa','cancelada','finalizada')
,`fecha` date
,`cantidad` bigint(21)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_resumen_clientes`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_resumen_clientes` (
`estado` enum('activo','inactivo','suspendido')
,`cantidad` bigint(21)
);

-- --------------------------------------------------------

--
-- Estructura Stand-in para la vista `vista_servicios_estado_categoria`
-- (Véase abajo para la vista actual)
--
CREATE TABLE `vista_servicios_estado_categoria` (
`categoria` text
,`estado` enum('activo','cancelado','pendiente','finalizado')
,`cantidad` bigint(21)
);

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_empleados_funcion`
--
DROP TABLE IF EXISTS `vista_empleados_funcion`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_empleados_funcion`  AS SELECT `f`.`detalle` AS `funcion`, count(0) AS `cantidad` FROM (`empleado` `e` left join `funcion` `f` on(`e`.`idFuncion` = `f`.`idFuncion`)) GROUP BY `f`.`detalle` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_estado_habitaciones`
--
DROP TABLE IF EXISTS `vista_estado_habitaciones`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_estado_habitaciones`  AS SELECT `habitacion`.`estado` AS `estado`, count(0) AS `cantidad` FROM `habitacion` GROUP BY `habitacion`.`estado` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_horarioactividad_estado_hoy`
--
DROP TABLE IF EXISTS `vista_horarioactividad_estado_hoy`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_horarioactividad_estado_hoy`  AS SELECT `horarioactividad`.`estado` AS `estado`, count(0) AS `cantidad` FROM `horarioactividad` WHERE cast(`horarioactividad`.`fchInicio` as date) = curdate() GROUP BY `horarioactividad`.`estado` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_inscripciones_estado`
--
DROP TABLE IF EXISTS `vista_inscripciones_estado`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_inscripciones_estado`  AS SELECT `inscripcion`.`estado` AS `estado`, count(0) AS `cantidad` FROM `inscripcion` GROUP BY `inscripcion`.`estado` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_productos_categoria`
--
DROP TABLE IF EXISTS `vista_productos_categoria`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_productos_categoria`  AS SELECT `cc`.`descripcion` AS `categoria`, count(0) AS `cantidad` FROM (`producto` `p` left join `categoriacomida` `cc` on(`p`.`idCtgComida` = `cc`.`idCtgComida`)) GROUP BY `cc`.`descripcion` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_reservas_estado_fecha`
--
DROP TABLE IF EXISTS `vista_reservas_estado_fecha`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_reservas_estado_fecha`  AS SELECT `reservahbt`.`estado` AS `estado`, cast(`reservahbt`.`fchInicio` as date) AS `fecha`, count(0) AS `cantidad` FROM `reservahbt` WHERE `reservahbt`.`fchInicio` >= curdate() - interval 30 day GROUP BY `reservahbt`.`estado`, cast(`reservahbt`.`fchInicio` as date) ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_resumen_clientes`
--
DROP TABLE IF EXISTS `vista_resumen_clientes`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_resumen_clientes`  AS SELECT `cliente`.`estado` AS `estado`, count(0) AS `cantidad` FROM `cliente` WHERE `cliente`.`estado` = 'activo' GROUP BY `cliente`.`estado` ;

-- --------------------------------------------------------

--
-- Estructura para la vista `vista_servicios_estado_categoria`
--
DROP TABLE IF EXISTS `vista_servicios_estado_categoria`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `vista_servicios_estado_categoria`  AS SELECT `cs`.`detalle` AS `categoria`, `s`.`estado` AS `estado`, count(0) AS `cantidad` FROM (`servicio` `s` left join `categoriaservicio` `cs` on(`s`.`idCtgServicio` = `cs`.`idCtgServicio`)) GROUP BY `cs`.`descripcion`, `s`.`estado` ;

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `actividad`
--
ALTER TABLE `actividad`
  ADD PRIMARY KEY (`idActividad`);

--
-- Indices de la tabla `asignacionservicio`
--
ALTER TABLE `asignacionservicio`
  ADD PRIMARY KEY (`idAsigSer`),
  ADD KEY `asigservicio_ibfk_1` (`idServicio`),
  ADD KEY `asigservicio_ibfk_2` (`idEmpleado`);

--
-- Indices de la tabla `categoriacomida`
--
ALTER TABLE `categoriacomida`
  ADD PRIMARY KEY (`idCtgComida`);

--
-- Indices de la tabla `categoriaservicio`
--
ALTER TABLE `categoriaservicio`
  ADD PRIMARY KEY (`idCtgServicio`);

--
-- Indices de la tabla `cliente`
--
ALTER TABLE `cliente`
  ADD PRIMARY KEY (`idCliente`),
  ADD KEY `idTipoDoc` (`idTipoDoc`);

--
-- Indices de la tabla `empleado`
--
ALTER TABLE `empleado`
  ADD PRIMARY KEY (`idEmpleado`),
  ADD KEY `idFuncion` (`idFuncion`);

--
-- Indices de la tabla `funcion`
--
ALTER TABLE `funcion`
  ADD PRIMARY KEY (`idFuncion`);

--
-- Indices de la tabla `funcionservicio`
--
ALTER TABLE `funcionservicio`
  ADD PRIMARY KEY (`idFunSer`),
  ADD KEY `idFuncion` (`idFuncion`),
  ADD KEY `idCtgServicio` (`idCtgServicio`);

--
-- Indices de la tabla `habitacion`
--
ALTER TABLE `habitacion`
  ADD PRIMARY KEY (`idHabitacion`),
  ADD KEY `idTipoHbt` (`idTipoHbt`);

--
-- Indices de la tabla `horarioactividad`
--
ALTER TABLE `horarioactividad`
  ADD PRIMARY KEY (`idHraActividad`),
  ADD KEY `idActividad` (`idActividad`);

--
-- Indices de la tabla `inscripcion`
--
ALTER TABLE `inscripcion`
  ADD PRIMARY KEY (`idInscripcion`),
  ADD KEY `idHraActividad` (`idHraActividad`),
  ADD KEY `idCliente` (`idCliente`);

--
-- Indices de la tabla `producto`
--
ALTER TABLE `producto`
  ADD PRIMARY KEY (`idProducto`),
  ADD KEY `idCtgComida` (`idCtgComida`);

--
-- Indices de la tabla `resenia`
--
ALTER TABLE `resenia`
  ADD PRIMARY KEY (`idRsnServicio`),
  ADD KEY `idServicio` (`idServicio`);

--
-- Indices de la tabla `reservahbt`
--
ALTER TABLE `reservahbt`
  ADD PRIMARY KEY (`idReservaHbt`),
  ADD KEY `idCliente` (`idCliente`),
  ADD KEY `idHabitacion` (`idHabitacion`);

--
-- Indices de la tabla `servicio`
--
ALTER TABLE `servicio`
  ADD PRIMARY KEY (`idServicio`),
  ADD KEY `idCliente` (`idCliente`),
  ADD KEY `idCtgServicio` (`idCtgServicio`),
  ADD KEY `idHabitacion` (`idHabitacion`);

--
-- Indices de la tabla `serviciocomida`
--
ALTER TABLE `serviciocomida`
  ADD PRIMARY KEY (`idSerCom`),
  ADD KEY `idProducto` (`idProducto`),
  ADD KEY `idServicio` (`idServicio`);

--
-- Indices de la tabla `tipodocumento`
--
ALTER TABLE `tipodocumento`
  ADD PRIMARY KEY (`idTipoDoc`);

--
-- Indices de la tabla `tipohabitacion`
--
ALTER TABLE `tipohabitacion`
  ADD PRIMARY KEY (`idTipoHbt`);

--
-- Indices de la tabla `usuario`
--
ALTER TABLE `usuario`
  ADD PRIMARY KEY (`idCuenta`),
  ADD KEY `idCliente` (`idCliente`),
  ADD KEY `idEmpleado` (`idEmpleado`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `actividad`
--
ALTER TABLE `actividad`
  MODIFY `idActividad` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `asignacionservicio`
--
ALTER TABLE `asignacionservicio`
  MODIFY `idAsigSer` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=40;

--
-- AUTO_INCREMENT de la tabla `categoriacomida`
--
ALTER TABLE `categoriacomida`
  MODIFY `idCtgComida` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=12;

--
-- AUTO_INCREMENT de la tabla `categoriaservicio`
--
ALTER TABLE `categoriaservicio`
  MODIFY `idCtgServicio` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT de la tabla `cliente`
--
ALTER TABLE `cliente`
  MODIFY `idCliente` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `empleado`
--
ALTER TABLE `empleado`
  MODIFY `idEmpleado` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `funcion`
--
ALTER TABLE `funcion`
  MODIFY `idFuncion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `funcionservicio`
--
ALTER TABLE `funcionservicio`
  MODIFY `idFunSer` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT de la tabla `habitacion`
--
ALTER TABLE `habitacion`
  MODIFY `idHabitacion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT de la tabla `horarioactividad`
--
ALTER TABLE `horarioactividad`
  MODIFY `idHraActividad` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=353;

--
-- AUTO_INCREMENT de la tabla `inscripcion`
--
ALTER TABLE `inscripcion`
  MODIFY `idInscripcion` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT de la tabla `producto`
--
ALTER TABLE `producto`
  MODIFY `idProducto` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT de la tabla `resenia`
--
ALTER TABLE `resenia`
  MODIFY `idRsnServicio` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT de la tabla `reservahbt`
--
ALTER TABLE `reservahbt`
  MODIFY `idReservaHbt` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT de la tabla `servicio`
--
ALTER TABLE `servicio`
  MODIFY `idServicio` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT de la tabla `serviciocomida`
--
ALTER TABLE `serviciocomida`
  MODIFY `idSerCom` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=19;

--
-- AUTO_INCREMENT de la tabla `tipodocumento`
--
ALTER TABLE `tipodocumento`
  MODIFY `idTipoDoc` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT de la tabla `tipohabitacion`
--
ALTER TABLE `tipohabitacion`
  MODIFY `idTipoHbt` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=10;

--
-- AUTO_INCREMENT de la tabla `usuario`
--
ALTER TABLE `usuario`
  MODIFY `idCuenta` int(11) NOT NULL AUTO_INCREMENT;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `asignacionservicio`
--
ALTER TABLE `asignacionservicio`
  ADD CONSTRAINT `asigservicio_ibfk_1` FOREIGN KEY (`idServicio`) REFERENCES `servicio` (`idServicio`),
  ADD CONSTRAINT `asigservicio_ibfk_2` FOREIGN KEY (`idEmpleado`) REFERENCES `empleado` (`idEmpleado`);

--
-- Filtros para la tabla `cliente`
--
ALTER TABLE `cliente`
  ADD CONSTRAINT `cliente_ibfk_1` FOREIGN KEY (`idTipoDoc`) REFERENCES `tipodocumento` (`idTipoDoc`);

--
-- Filtros para la tabla `empleado`
--
ALTER TABLE `empleado`
  ADD CONSTRAINT `empleado_ibfk_1` FOREIGN KEY (`idFuncion`) REFERENCES `funcion` (`idFuncion`);

--
-- Filtros para la tabla `funcionservicio`
--
ALTER TABLE `funcionservicio`
  ADD CONSTRAINT `funcionservicio_ibfk_1` FOREIGN KEY (`idFuncion`) REFERENCES `funcion` (`idFuncion`),
  ADD CONSTRAINT `funcionservicio_ibfk_2` FOREIGN KEY (`idCtgServicio`) REFERENCES `categoriaservicio` (`idCtgServicio`);

--
-- Filtros para la tabla `habitacion`
--
ALTER TABLE `habitacion`
  ADD CONSTRAINT `habitacion_ibfk_1` FOREIGN KEY (`idTipoHbt`) REFERENCES `tipohabitacion` (`idTipoHbt`);

--
-- Filtros para la tabla `horarioactividad`
--
ALTER TABLE `horarioactividad`
  ADD CONSTRAINT `horarioactividad_ibfk_1` FOREIGN KEY (`idActividad`) REFERENCES `actividad` (`idActividad`);

--
-- Filtros para la tabla `inscripcion`
--
ALTER TABLE `inscripcion`
  ADD CONSTRAINT `inscripcion_ibfk_1` FOREIGN KEY (`idHraActividad`) REFERENCES `horarioactividad` (`idHraActividad`),
  ADD CONSTRAINT `inscripcion_ibfk_2` FOREIGN KEY (`idCliente`) REFERENCES `cliente` (`idCliente`);

--
-- Filtros para la tabla `producto`
--
ALTER TABLE `producto`
  ADD CONSTRAINT `producto_ibfk_1` FOREIGN KEY (`idCtgComida`) REFERENCES `categoriacomida` (`idCtgComida`);

--
-- Filtros para la tabla `resenia`
--
ALTER TABLE `resenia`
  ADD CONSTRAINT `resenia_ibfk_1` FOREIGN KEY (`idServicio`) REFERENCES `servicio` (`idServicio`);

--
-- Filtros para la tabla `reservahbt`
--
ALTER TABLE `reservahbt`
  ADD CONSTRAINT `reservahbt_ibfk_1` FOREIGN KEY (`idCliente`) REFERENCES `cliente` (`idCliente`),
  ADD CONSTRAINT `reservahbt_ibfk_2` FOREIGN KEY (`idHabitacion`) REFERENCES `habitacion` (`idHabitacion`);

--
-- Filtros para la tabla `servicio`
--
ALTER TABLE `servicio`
  ADD CONSTRAINT `servicio_ibfk_2` FOREIGN KEY (`idCliente`) REFERENCES `cliente` (`idCliente`),
  ADD CONSTRAINT `servicio_ibfk_3` FOREIGN KEY (`idCtgServicio`) REFERENCES `categoriaservicio` (`idCtgServicio`),
  ADD CONSTRAINT `servicio_ibfk_4` FOREIGN KEY (`idHabitacion`) REFERENCES `habitacion` (`idHabitacion`);

--
-- Filtros para la tabla `serviciocomida`
--
ALTER TABLE `serviciocomida`
  ADD CONSTRAINT `serviciocomida_ibfk_1` FOREIGN KEY (`idProducto`) REFERENCES `producto` (`idProducto`),
  ADD CONSTRAINT `serviciocomida_ibfk_2` FOREIGN KEY (`idServicio`) REFERENCES `servicio` (`idServicio`);

--
-- Filtros para la tabla `usuario`
--
ALTER TABLE `usuario`
  ADD CONSTRAINT `usuario_ibfk_1` FOREIGN KEY (`idCliente`) REFERENCES `cliente` (`idCliente`),
  ADD CONSTRAINT `usuario_ibfk_2` FOREIGN KEY (`idEmpleado`) REFERENCES `empleado` (`idEmpleado`);

DELIMITER $$
--
-- Eventos
--
CREATE DEFINER=`root`@`localhost` EVENT `generar_horario_id1` ON SCHEDULE EVERY 1 DAY STARTS '2025-06-15 01:35:00' ON COMPLETION PRESERVE ENABLE DO CALL GenerarHorariosDiarios(1, 5, CURDATE(), '09:00', '17:00', 60)$$

CREATE DEFINER=`root`@`localhost` EVENT `generar_horario_id2` ON SCHEDULE EVERY 1 DAY STARTS '2025-06-04 01:35:00' ON COMPLETION PRESERVE ENABLE DO CALL GenerarHorariosDiarios(2, 15, CURDATE(), '10:00:00', '16:00:00', 90)$$

CREATE DEFINER=`root`@`localhost` EVENT `generar_horario_id3` ON SCHEDULE EVERY 1 DAY STARTS '2025-06-04 01:35:00' ON COMPLETION PRESERVE ENABLE DO CALL GenerarHorariosDiarios(3, 6, CURDATE(), '08:00:00', '20:00:00', 60)$$

CREATE DEFINER=`root`@`localhost` EVENT `cerrar_horarios_pasados` ON SCHEDULE EVERY 1 MINUTE STARTS '2025-06-05 23:37:51' ON COMPLETION NOT PRESERVE ENABLE DO UPDATE horarioActividad
  SET estado = 'cerrado'
  WHERE fchInicio <= NOW() AND estado = 'activo'$$

CREATE DEFINER=`root`@`localhost` EVENT `actualizar_estado_habitaciones` ON SCHEDULE EVERY 1 HOUR STARTS '2025-06-17 12:37:50' ON COMPLETION NOT PRESERVE ENABLE DO BEGIN
  -- Marcar como 'ocupado' si hay una reserva activa
  UPDATE habitacion h
  SET h.estado = 'ocupado'
  WHERE EXISTS (
    SELECT 1
    FROM reservahbt r
    WHERE r.idHabitacion = h.idHabitacion
      AND r.estado = 'activa'
      AND NOW() BETWEEN r.fchInicio AND r.fchFin
  );

  -- Marcar como 'disponible' si NO hay reservas activas en ese momento
  UPDATE habitacion h
  SET h.estado = 'disponible'
  WHERE NOT EXISTS (
    SELECT 1
    FROM reservahbt r
    WHERE r.idHabitacion = h.idHabitacion
      AND r.estado = 'activa'
      AND NOW() BETWEEN r.fchInicio AND r.fchFin
  );
END$$

DELIMITER ;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
