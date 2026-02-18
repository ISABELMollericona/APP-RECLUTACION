-- Script: Sistema Inteligente de Reclutamiento para PYME
-- Fecha: 2026-02-11
-- Objetivo: crear BDD, tablas, roles, usuarios, funciones, SP, triggers, vistas y auditoría

DROP DATABASE IF EXISTS reclutamiento;
CREATE DATABASE reclutamiento CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE reclutamiento;

-- ROLES (MySQL 8+)
CREATE ROLE IF NOT EXISTS rol_admin;
CREATE ROLE IF NOT EXISTS rol_reclutador;
CREATE ROLE IF NOT EXISTS rol_consulta;

-- USERS (MySQL server users for DB access)
CREATE USER IF NOT EXISTS 'admin_rrhh'@'%' IDENTIFIED BY 'AdminPass!2026';
CREATE USER IF NOT EXISTS 'reclutador_user'@'%' IDENTIFIED BY 'RecluPass!2026';
CREATE USER IF NOT EXISTS 'auditor_user'@'%' IDENTIFIED BY 'AuditPass!2026';

-- GRANT permissions to roles (scoped to this database)
GRANT SELECT, INSERT, UPDATE, DELETE ON reclutamiento.* TO rol_admin;
GRANT SELECT, INSERT, UPDATE ON reclutamiento.* TO rol_reclutador;
GRANT SELECT ON reclutamiento.* TO rol_consulta;

-- Assign roles to server users and set default role
GRANT rol_admin TO 'admin_rrhh'@'%';
GRANT rol_reclutador TO 'reclutador_user'@'%';
GRANT rol_consulta TO 'auditor_user'@'%';
SET DEFAULT ROLE rol_admin TO 'admin_rrhh'@'%';
SET DEFAULT ROLE rol_reclutador TO 'reclutador_user'@'%';
SET DEFAULT ROLE rol_consulta TO 'auditor_user'@'%';

-- REVOKE unnecessary global privileges from PUBLIC (defensive)
-- NOTE: `REVOKE ... FROM PUBLIC` puede fallar en algunas instalaciones
-- de MySQL (Error 1269). Para evitar errores en MySQL Workbench y en
-- servidores que no reconocen `PUBLIC` como sujeto revocable, dejamos
-- la acción comentada y recomendamos ejecutar revokes explícitos por
-- usuario cuando sea necesario.
-- Ejemplo seguro (descomentar y adaptar si realmente se necesita):
-- REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'someuser'@'%';
-- Si prefiere que aplique revokes automáticos para los usuarios creados
-- en este script, indíquelo y generaré comandos específicos.

-- TABLAS PRINCIPALES
CREATE TABLE departamentos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  descripcion TEXT,
  creado_en DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE vacantes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(200) NOT NULL,
  descripcion TEXT,
  departamento_id INT NOT NULL,
  requerimientos JSON DEFAULT (JSON_ARRAY()),
  estado ENUM('abierta','cerrada','pausada') DEFAULT 'abierta',
  activo TINYINT(1) DEFAULT 1,
  creado_en DATETIME DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (departamento_id) REFERENCES departamentos(id) ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE postulantes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(150) NOT NULL,
  email VARCHAR(200) NOT NULL UNIQUE,
  anos_experiencia INT DEFAULT 0,
  habilidades JSON DEFAULT (JSON_ARRAY()),
  cv_path VARCHAR(500) DEFAULT NULL,
  creado_en DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE postulaciones (
  id INT AUTO_INCREMENT PRIMARY KEY,
  postulante_id INT NOT NULL,
  vacante_id INT NOT NULL,
  fecha_postulacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  estado ENUM('en_revision','rechazado','aceptado') DEFAULT 'en_revision',
  usuario_creo VARCHAR(150) DEFAULT NULL,
  usuario_id INT DEFAULT NULL,
  FOREIGN KEY (postulante_id) REFERENCES postulantes(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (vacante_id) REFERENCES vacantes(id) ON UPDATE CASCADE ON DELETE RESTRICT,
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON UPDATE CASCADE ON DELETE SET NULL,
  UNIQUE KEY ux_postulante_vacante (postulante_id, vacante_id)
);

CREATE TABLE evaluacion_ia (
  id INT AUTO_INCREMENT PRIMARY KEY,
  postulacion_id INT NOT NULL UNIQUE,
  score DECIMAL(6,2) DEFAULT 0.00,
  criterios JSON DEFAULT (JSON_OBJECT()),
  actualizado_en DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (postulacion_id) REFERENCES postulaciones(id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(128) NULL,
  password_plain VARCHAR(255) NULL COMMENT 'campo temporal: nunca dejar en producción',
  nombre VARCHAR(150),
  email VARCHAR(200) UNIQUE,
  rol_app ENUM('admin','reclutador','postulante','auditor') DEFAULT 'reclutador',
  activo TINYINT(1) DEFAULT 1,
  failed_attempts INT DEFAULT 0,
  locked_until DATETIME DEFAULT NULL,
  reset_token VARCHAR(128) DEFAULT NULL,
  reset_expire DATETIME DEFAULT NULL,
  creado_en DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE logs_auditoria (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  usuario_mysql VARCHAR(200) NULL,
  accion ENUM('INSERT','UPDATE','DELETE','SP') NOT NULL,
  tabla_afectada VARCHAR(200),
  fila_id VARCHAR(200),
  fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
  descripcion TEXT
);

-- FUNCTION: calcular score simple
DELIMITER $$
CREATE FUNCTION fn_calcular_score(p_anos INT, p_coincidencias INT) RETURNS DECIMAL(6,2)
DETERMINISTIC
BEGIN
  DECLARE v_score DECIMAL(6,2);
  SET v_score = LEAST(100, p_anos * 2 + p_coincidencias * 10);
  RETURN v_score;
END$$
DELIMITER ;

-- PROCEDIMIENTO: obtener línea de tiempo de una postulación
DELIMITER $$
CREATE PROCEDURE sp_postulacion_timeline(IN p_postulacion_id INT)
BEGIN
  SELECT 'recibida' AS estado, fecha_postulacion AS fecha, usuario_creo AS usuario FROM postulaciones WHERE id = p_postulacion_id
  UNION ALL
  SELECT 'evaluacion', actualizado_en, NULL FROM evaluacion_ia WHERE postulacion_id = p_postulacion_id
  UNION ALL
  SELECT accion AS estado, fecha, usuario_mysql FROM logs_auditoria WHERE tabla_afectada='postulaciones' AND fila_id = CAST(p_postulacion_id AS CHAR)
  ORDER BY fecha;
END$$
DELIMITER ;

-- PROCEDIMIENTO: recalcular score para una postulacion usando fn_calcular_score
DELIMITER $$
CREATE PROCEDURE sp_recalcular_score(IN p_postulacion_id INT)
BEGIN
  DECLARE v_postulante INT;
  DECLARE v_anos INT DEFAULT 0;
  DECLARE v_coincidencias INT DEFAULT 0;
  DECLARE v_score DECIMAL(6,2) DEFAULT 0;
  SELECT postulante_id INTO v_postulante FROM postulaciones WHERE id = p_postulacion_id;
  IF v_postulante IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Postulación no encontrada';
  END IF;
  SELECT anos_experiencia INTO v_anos FROM postulantes WHERE id = v_postulante;
  -- aproximación simple: no contar coincidencias avanzadas
  SET v_coincidencias = 0;
  SET v_score = fn_calcular_score(IFNULL(v_anos,0), v_coincidencias);
  -- actualizar o insertar en evaluacion_ia
  INSERT INTO evaluacion_ia (postulacion_id, score, criterios) VALUES (p_postulacion_id, v_score, JSON_OBJECT('metodo','recalculo'))
    ON DUPLICATE KEY UPDATE score = v_score, criterios = JSON_OBJECT('metodo','recalculo'), actualizado_en = CURRENT_TIMESTAMP;
  INSERT INTO logs_auditoria (usuario_mysql, accion, tabla_afectada, fila_id, descripcion)
    VALUES (CURRENT_USER(), 'UPDATE', 'evaluacion_ia', CAST(p_postulacion_id AS CHAR), CONCAT('sp_recalcular_score: ', v_score));
END$$
DELIMITER ;

-- Procedimientos para reportes: vacantes por mes, postulantes por vacante, promedio score por departamento
DELIMITER $$
CREATE PROCEDURE sp_report_vacantes_por_mes()
BEGIN
  SELECT DATE_FORMAT(creado_en, '%Y-%m') AS mes, COUNT(*) AS total FROM vacantes GROUP BY mes ORDER BY mes;
END$$

CREATE PROCEDURE sp_report_postulantes_por_vacante()
BEGIN
  SELECT v.id AS vacante_id, v.titulo, COUNT(po.id) AS total_postulantes
  FROM vacantes v LEFT JOIN postulaciones po ON po.vacante_id = v.id
  GROUP BY v.id ORDER BY total_postulantes DESC;
END$$

CREATE PROCEDURE sp_report_promedio_score_por_departamento()
BEGIN
  SELECT d.id AS departamento_id, d.nombre, ROUND(AVG(e.score),2) AS promedio_score
  FROM departamentos d
  JOIN vacantes v ON v.departamento_id = d.id
  JOIN postulaciones po ON po.vacante_id = v.id
  JOIN evaluacion_ia e ON e.postulacion_id = po.id
  GROUP BY d.id ORDER BY promedio_score DESC;
END$$
DELIMITER ;

-- SPs para gestión de departamentos
DELIMITER $$
CREATE PROCEDURE sp_create_departamento(IN p_nombre VARCHAR(100), IN p_desc TEXT)
BEGIN
  INSERT INTO departamentos (nombre, descripcion) VALUES (p_nombre, p_desc);
  INSERT INTO logs_auditoria (usuario_mysql, accion, tabla_afectada, fila_id, descripcion)
    VALUES (CURRENT_USER(), 'INSERT', 'departamentos', CAST(LAST_INSERT_ID() AS CHAR), CONCAT('Departamento creado: ', p_nombre));
END$$

CREATE PROCEDURE sp_update_departamento(IN p_id INT, IN p_nombre VARCHAR(100), IN p_desc TEXT)
BEGIN
  UPDATE departamentos SET nombre = p_nombre, descripcion = p_desc WHERE id = p_id;
  INSERT INTO logs_auditoria (usuario_mysql, accion, tabla_afectada, fila_id, descripcion)
    VALUES (CURRENT_USER(), 'UPDATE', 'departamentos', CAST(p_id AS CHAR), CONCAT('Departamento actualizado: ', p_nombre));
END$$
DELIMITER ;

-- SP para listar usuarios internos
DELIMITER $$
CREATE PROCEDURE sp_listar_usuarios()
BEGIN
  SELECT id, username, nombre, email, rol_app, activo FROM usuarios ORDER BY id;
END$$
DELIMITER ;

-- FUNCTION: validar postulante (no duplicados y existencia)
DELIMITER $$
CREATE FUNCTION fn_validar_postulante(p_postulante_id INT, p_vacante_id INT) RETURNS BOOLEAN
DETERMINISTIC
BEGIN
  DECLARE v_exists INT;
  SELECT COUNT(*) INTO v_exists FROM postulantes WHERE id = p_postulante_id;
  IF v_exists = 0 THEN
    RETURN FALSE;
  END IF;
  SELECT COUNT(*) INTO v_exists FROM postulaciones WHERE postulante_id = p_postulante_id AND vacante_id = p_vacante_id;
  IF v_exists > 0 THEN
    RETURN FALSE;
  END IF;
  RETURN TRUE;
END$$
DELIMITER ;

-- PROCEDURE: crear postulación y evaluación IA inicial
DELIMITER $$
CREATE PROCEDURE sp_crear_postulacion(
  IN p_postulante_id INT,
  IN p_vacante_id INT,
  IN p_usuario VARCHAR(150)
)
BEGIN
  DECLARE v_activo INT DEFAULT 0;
  DECLARE v_anos INT DEFAULT 0;
  DECLARE v_coincidencias INT DEFAULT 0;
  DECLARE v_score DECIMAL(6,2) DEFAULT 0;
  DECLARE v_hab_json JSON;
  DECLARE v_req_json JSON;
  DECLARE v_idx INT DEFAULT 0;
  DECLARE v_skill VARCHAR(200);
  DECLARE v_usuario_id INT DEFAULT NULL;
  -- validar vacante
  SELECT activo INTO v_activo FROM vacantes WHERE id = p_vacante_id;
  IF v_activo IS NULL OR v_activo = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vacante no existe o no está activa';
  END IF;
  -- validar postulante
  IF fn_validar_postulante(p_postulante_id, p_vacante_id) = FALSE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Postulante inválido o ya postuló';
  END IF;
  -- resolver usuario (username -> id) si existe
  SELECT id INTO v_usuario_id FROM usuarios WHERE username = p_usuario LIMIT 1;
  -- insertar postulacion (guardar username y usuario_id FK cuando sea posible)
  INSERT INTO postulaciones (postulante_id, vacante_id, usuario_creo, usuario_id)
    VALUES (p_postulante_id, p_vacante_id, p_usuario, v_usuario_id);
  SET @last_postulacion_id = LAST_INSERT_ID();
  -- calcular score inicial: extraer anos y comparar habilidades
  SELECT anos_experiencia INTO v_anos FROM postulantes WHERE id = p_postulante_id;
  -- Contar coincidencias entre habilidades y requerimientos usando JSON_SEARCH (compatible en MySQL 8+)
  SELECT pt.habilidades, v.requerimientos INTO v_hab_json, v_req_json
    FROM postulantes pt JOIN vacantes v ON v.id = p_vacante_id WHERE pt.id = p_postulante_id;
  SET v_coincidencias = 0;
  SET v_idx = 0;
  loop_coinc: LOOP
    SET v_skill = JSON_UNQUOTE(JSON_EXTRACT(v_hab_json, CONCAT('$[', v_idx, ']')));
    IF v_skill IS NULL THEN
      LEAVE loop_coinc;
    END IF;
    IF JSON_SEARCH(v_req_json, 'one', v_skill) IS NOT NULL THEN
      SET v_coincidencias = v_coincidencias + 1;
    END IF;
    SET v_idx = v_idx + 1;
  END LOOP loop_coinc;
  SET v_score = fn_calcular_score(IFNULL(v_anos,0), IFNULL(v_coincidencias,0));
  -- insertar evaluación IA
  INSERT INTO evaluacion_ia (postulacion_id, score, criterios) VALUES (@last_postulacion_id, v_score, JSON_OBJECT('metodo','inicial'));
  -- auditoría
  INSERT INTO logs_auditoria (usuario_mysql, accion, tabla_afectada, fila_id, descripcion)
    VALUES (p_usuario, 'SP', 'postulaciones', @last_postulacion_id, CONCAT('sp_crear_postulacion: puntaje inicial=', v_score));
END$$
DELIMITER ;

-- PROCEDURE: generar ranking por vacante
DELIMITER $$
CREATE PROCEDURE sp_generar_ranking(IN p_vacante_id INT)
BEGIN
  SELECT po.id AS postulacion_id, pt.id AS postulante_id, pt.nombre AS postulante_nombre,
         e.score, e.criterios, po.fecha_postulacion
  FROM postulaciones po
  JOIN postulantes pt ON pt.id = po.postulante_id
  LEFT JOIN evaluacion_ia e ON e.postulacion_id = po.id
  WHERE po.vacante_id = p_vacante_id
  ORDER BY e.score DESC, po.fecha_postulacion ASC;
END$$
DELIMITER ;

-- PROCEDURE: cerrar vacante (cambia estado y registra auditoría)
DELIMITER $$
CREATE PROCEDURE sp_cerrar_vacante(IN p_vacante_id INT, IN p_usuario VARCHAR(150))
BEGIN
  DECLARE v_exists INT;
  SELECT COUNT(*) INTO v_exists FROM vacantes WHERE id = p_vacante_id;
  IF v_exists = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vacante no encontrada';
  END IF;
  UPDATE vacantes SET estado = 'cerrada', activo = 0 WHERE id = p_vacante_id;
  INSERT INTO logs_auditoria (usuario_mysql, accion, tabla_afectada, fila_id, descripcion)
    VALUES (p_usuario, 'SP', 'vacantes', p_vacante_id, 'sp_cerrar_vacante ejecutado');
END$$
DELIMITER ;

-- VISTAS
CREATE VIEW vista_ranking_vacantes AS
SELECT v.id AS vacante_id, v.titulo, po.id AS postulacion_id, pt.id AS postulante_id, pt.nombre,
       IFNULL(e.score,0) AS score, po.fecha_postulacion
FROM vacantes v
JOIN postulaciones po ON po.vacante_id = v.id
JOIN postulantes pt ON pt.id = po.postulante_id
LEFT JOIN evaluacion_ia e ON e.postulacion_id = po.id
WHERE v.activo = 1 AND v.estado = 'abierta'
ORDER BY v.id, score DESC;

CREATE VIEW vista_reporte_general AS
SELECT
  (SELECT COUNT(*) FROM vacantes) AS total_vacantes,
  (SELECT COUNT(*) FROM postulantes) AS total_postulantes,
  (SELECT ROUND(AVG(score),2) FROM evaluacion_ia) AS promedio_score
;

CREATE VIEW vista_auditoria AS
SELECT id, usuario_mysql, accion, tabla_afectada, fila_id, fecha, descripcion
FROM logs_auditoria
ORDER BY fecha DESC;

-- SP auxiliar para listar logs (UI)
DELIMITER $$
CREATE PROCEDURE sp_listar_logs()
BEGIN
  SELECT id, usuario_mysql, accion, tabla_afectada, fila_id, fecha, descripcion FROM logs_auditoria ORDER BY fecha DESC LIMIT 500;
END$$
DELIMITER ;

-- AUDITORÍA: TRIGGERS GENERALES (INSERT/UPDATE/DELETE) para tablas clave
DELIMITER $$
CREATE PROCEDURE sp_log_auditoria(IN p_usuario VARCHAR(200), IN p_accion VARCHAR(10), IN p_tabla VARCHAR(200), IN p_fila VARCHAR(200), IN p_descr TEXT)
BEGIN
  INSERT INTO logs_auditoria (usuario_mysql, accion, tabla_afectada, fila_id, descripcion)
    VALUES (p_usuario, p_accion, p_tabla, p_fila, p_descr);
END$$
DELIMITER ;

-- Trigger helpers para tablas: usuarios, vacantes, postulantes, postulaciones, evaluacion_ia
DELIMITER $$
CREATE TRIGGER trg_postulaciones_before_insert
BEFORE INSERT ON postulaciones
FOR EACH ROW
BEGIN
  DECLARE v_activo INT;
  -- Asegurar que `usuario_creo` tenga el usuario MySQL si no fue enviado
  DECLARE v_uid INT;
  SET NEW.usuario_creo = COALESCE(NEW.usuario_creo, CURRENT_USER());
  -- Intentar resolver username a id en la tabla `usuarios` (si coincide exactamente)
  SET v_uid = NULL;
  SELECT id INTO v_uid FROM usuarios WHERE username = NEW.usuario_creo LIMIT 1;
  IF v_uid IS NOT NULL THEN
    SET NEW.usuario_id = v_uid;
  END IF;
  SELECT activo INTO v_activo FROM vacantes WHERE id = NEW.vacante_id;
  IF v_activo IS NULL OR v_activo = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No puede postular a una vacante inactiva';
  END IF;
END$$

CREATE TRIGGER trg_postulaciones_after_insert
AFTER INSERT ON postulaciones
FOR EACH ROW
BEGIN
  CALL sp_log_auditoria(CURRENT_USER(), 'INSERT', 'postulaciones', CAST(NEW.id AS CHAR), CONCAT('Postulación creada id=', NEW.id, ' postulante=', NEW.postulante_id));
END$$

CREATE TRIGGER trg_vacantes_before_delete
BEFORE DELETE ON vacantes
FOR EACH ROW
BEGIN
  DECLARE v_count INT;
  SELECT COUNT(*) INTO v_count FROM postulaciones WHERE vacante_id = OLD.id;
  IF v_count > 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar vacante con postulaciones asociadas';
  END IF;
END$$

CREATE TRIGGER trg_evaluacion_after_update
AFTER UPDATE ON evaluacion_ia
FOR EACH ROW
BEGIN
  IF OLD.score <> NEW.score THEN
    CALL sp_log_auditoria(CURRENT_USER(), 'UPDATE', 'evaluacion_ia', CAST(NEW.postulacion_id AS CHAR), CONCAT('Score cambiado de ', OLD.score, ' a ', NEW.score));
  END IF;
END$$

-- Triggers para auditoría de INSERT/UPDATE/DELETE en tablas principales
CREATE TRIGGER trg_usuarios_after_insert
AFTER INSERT ON usuarios
FOR EACH ROW
BEGIN
  CALL sp_log_auditoria(CURRENT_USER(), 'INSERT', 'usuarios', CAST(NEW.id AS CHAR), CONCAT('Usuario creado: ', NEW.username));
END$$

CREATE TRIGGER trg_usuarios_after_update
AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
  CALL sp_log_auditoria(CURRENT_USER(), 'UPDATE', 'usuarios', CAST(NEW.id AS CHAR), CONCAT('Usuario actualizado: ', NEW.username));
END$$

CREATE TRIGGER trg_postulantes_after_insert
AFTER INSERT ON postulantes
FOR EACH ROW
BEGIN
  CALL sp_log_auditoria(CURRENT_USER(), 'INSERT', 'postulantes', CAST(NEW.id AS CHAR), CONCAT('Postulante creado: ', NEW.nombre));
END$$

CREATE TRIGGER trg_vacantes_after_insert
AFTER INSERT ON vacantes
FOR EACH ROW
BEGIN
  CALL sp_log_auditoria(CURRENT_USER(), 'INSERT', 'vacantes', CAST(NEW.id AS CHAR), CONCAT('Vacante creada: ', NEW.titulo));
END$$

DELIMITER ;

-- Nota: para hashing de contraseñas de la tabla `usuarios` proporcionamos un SP y un trigger de ejemplo.
DELIMITER $$
CREATE PROCEDURE sp_crear_usuario(IN p_username VARCHAR(100), IN p_password_plain VARCHAR(255), IN p_nombre VARCHAR(150), IN p_email VARCHAR(200), IN p_rol_app VARCHAR(20))
BEGIN
  INSERT INTO usuarios (username, password_hash, nombre, email, rol_app)
    VALUES (p_username, SHA2(p_password_plain,256), p_nombre, p_email, p_rol_app);
  CALL sp_log_auditoria(CURRENT_USER(), 'SP', 'usuarios', CAST(LAST_INSERT_ID() AS CHAR), 'sp_crear_usuario ejecutado');
END$$
DELIMITER ;

-- Recomendación de seguridad: revocar INSERT/UPDATE directo sobre `usuarios` a roles que no sean admin, y usar SP para creación/hashing.

-- FIN del script

-- ADICION: Procedimientos para interfaz (listados y detalle)
DELIMITER $$
CREATE PROCEDURE sp_listar_vacantes()
BEGIN
  SELECT id, titulo, descripcion, departamento_id, estado, activo, creado_en
  FROM vacantes
  WHERE activo = 1
  ORDER BY creado_en DESC;
END$$

CREATE PROCEDURE sp_vacante_detalle(IN p_vacante_id INT)
BEGIN
  SELECT v.id, v.titulo, v.descripcion, v.requerimientos, v.estado, v.activo, v.creado_en, v.actualizado_en,
         d.id AS departamento_id, d.nombre AS departamento
  FROM vacantes v
  LEFT JOIN departamentos d ON d.id = v.departamento_id
  WHERE v.id = p_vacante_id;
END$$

CREATE PROCEDURE sp_listar_postulantes_por_vacante(IN p_vacante_id INT)
BEGIN
  SELECT pt.id AS postulante_id, pt.nombre, pt.email, pt.anos_experiencia, pt.habilidades, po.fecha_postulacion, po.estado
  FROM postulaciones po
  JOIN postulantes pt ON pt.id = po.postulante_id
  WHERE po.vacante_id = p_vacante_id
  ORDER BY po.fecha_postulacion DESC;
END$$

DELIMITER ;

-- PROCEDIMIENTOS PARA AUTENTICACIÓN, BLOQUEO Y RECUPERACIÓN
DELIMITER $$
CREATE PROCEDURE sp_crear_usuario_ex(
  IN p_username VARCHAR(100),
  IN p_password_plain VARCHAR(255),
  IN p_nombre VARCHAR(150),
  IN p_email VARCHAR(200),
  IN p_rol_app VARCHAR(20)
)
BEGIN
  INSERT INTO usuarios (username, password_hash, nombre, email, rol_app, failed_attempts, locked_until)
    VALUES (p_username, SHA2(p_password_plain,256), p_nombre, p_email, p_rol_app, 0, NULL);
  CALL sp_log_auditoria(CURRENT_USER(), 'INSERT', 'usuarios', CAST(LAST_INSERT_ID() AS CHAR), CONCAT('sp_crear_usuario_ex ejecutado rol=', p_rol_app));
END$$

CREATE PROCEDURE sp_authenticate_user(IN p_username VARCHAR(100), IN p_password_plain VARCHAR(255))
BEGIN
  DECLARE v_id INT;
  DECLARE v_hash VARCHAR(128);
  DECLARE v_failed INT;
  DECLARE v_locked DATETIME;
  DECLARE v_rol VARCHAR(50);
  SELECT id, password_hash, failed_attempts, locked_until, rol_app INTO v_id, v_hash, v_failed, v_locked, v_rol
    FROM usuarios WHERE username = p_username AND activo = 1;
  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no encontrado o inactivo';
  END IF;
  IF v_locked IS NOT NULL AND v_locked > NOW() THEN
    SET @msg_locked = CONCAT('Cuenta bloqueada hasta ', DATE_FORMAT(v_locked, '%Y-%m-%d %H:%i:%s'));
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @msg_locked;
  END IF;
  IF v_hash = SHA2(p_password_plain,256) THEN
    -- login exitoso: reset de intentos y retorno
    UPDATE usuarios SET failed_attempts = 0, locked_until = NULL WHERE id = v_id;
    SELECT v_id AS id, p_username AS username, v_rol AS rol_app;
    CALL sp_log_auditoria(p_username, 'SP', 'usuarios', CAST(v_id AS CHAR), 'sp_authenticate_user: login exitoso');
  ELSE
    -- fallo: incrementar intentos
    SET v_failed = v_failed + 1;
    IF v_failed >= 5 THEN
      UPDATE usuarios SET failed_attempts = 0, locked_until = DATE_ADD(NOW(), INTERVAL 15 MINUTE) WHERE id = v_id;
      CALL sp_log_auditoria(p_username, 'UPDATE', 'usuarios', CAST(v_id AS CHAR), 'Cuenta bloqueada por intentos fallidos');
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cuenta bloqueada por intentos fallidos';
    ELSE
      UPDATE usuarios SET failed_attempts = v_failed WHERE id = v_id;
      SET @msg_intento = CONCAT('Intento fallido #', v_failed);
      CALL sp_log_auditoria(p_username, 'UPDATE', 'usuarios', CAST(v_id AS CHAR), @msg_intento);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Credenciales inválidas';
    END IF;
  END IF;
END$$

CREATE PROCEDURE sp_request_password_reset(IN p_username VARCHAR(100), IN p_token VARCHAR(128), IN p_minutes INT)
BEGIN
  DECLARE v_id INT;
  SELECT id INTO v_id FROM usuarios WHERE username = p_username;
  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Usuario no encontrado';
  END IF;
  UPDATE usuarios SET reset_token = p_token, reset_expire = DATE_ADD(NOW(), INTERVAL p_minutes MINUTE) WHERE id = v_id;
  CALL sp_log_auditoria(p_username, 'UPDATE', 'usuarios', CAST(v_id AS CHAR), 'Solicitud de restablecimiento de contraseña');
END$$

CREATE PROCEDURE sp_change_password_by_token(IN p_token VARCHAR(128), IN p_new_password VARCHAR(255))
BEGIN
  DECLARE v_id INT;
  DECLARE v_exp DATETIME;
  SELECT id, reset_expire INTO v_id, v_exp FROM usuarios WHERE reset_token = p_token;
  IF v_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Token inválido';
  END IF;
  IF v_exp IS NULL OR v_exp < NOW() THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Token expirado';
  END IF;
  UPDATE usuarios SET password_hash = SHA2(p_new_password,256), reset_token = NULL, reset_expire = NULL WHERE id = v_id;
  CALL sp_log_auditoria(CURRENT_USER(), 'UPDATE', 'usuarios', CAST(v_id AS CHAR), 'Cambio de contraseña por token');
END$$

DELIMITER ;

-- PROCEDIMIENTOS PARA CRUD DE VACANTES
DELIMITER $$
CREATE PROCEDURE sp_create_vacante(
  IN p_titulo VARCHAR(200),
  IN p_descripcion TEXT,
  IN p_departamento_id INT,
  IN p_requerimientos JSON,
  IN p_usuario VARCHAR(150)
)
BEGIN
  INSERT INTO vacantes (titulo, descripcion, departamento_id, requerimientos, estado, activo)
    VALUES (p_titulo, p_descripcion, p_departamento_id, p_requerimientos, 'abierta', 1);
  INSERT INTO logs_auditoria (usuario_mysql, accion, tabla_afectada, fila_id, descripcion)
    VALUES (p_usuario, 'INSERT', 'vacantes', CAST(LAST_INSERT_ID() AS CHAR), CONCAT('Vacante creada: ', p_titulo));
END$$

CREATE PROCEDURE sp_update_vacante(
  IN p_vacante_id INT,
  IN p_titulo VARCHAR(200),
  IN p_descripcion TEXT,
  IN p_departamento_id INT,
  IN p_requerimientos JSON,
  IN p_estado VARCHAR(20),
  IN p_usuario VARCHAR(150)
)
BEGIN
  UPDATE vacantes SET titulo = p_titulo, descripcion = p_descripcion, departamento_id = p_departamento_id,
    requerimientos = p_requerimientos, estado = p_estado WHERE id = p_vacante_id;
  INSERT INTO logs_auditoria (usuario_mysql, accion, tabla_afectada, fila_id, descripcion)
    VALUES (p_usuario, 'UPDATE', 'vacantes', CAST(p_vacante_id AS CHAR), CONCAT('Vacante actualizada: ', p_titulo));
END$$

DELIMITER ;

-- PROCEDIMIENTOS PARA POSTULANTES (CRUD y CV)
DELIMITER $$
CREATE PROCEDURE sp_update_postulante(
  IN p_postulante_id INT,
  IN p_nombre VARCHAR(150),
  IN p_email VARCHAR(200),
  IN p_anos_experiencia INT,
  IN p_habilidades JSON,
  IN p_cv_path VARCHAR(500)
)
BEGIN
  UPDATE postulantes SET nombre = p_nombre, email = p_email, anos_experiencia = p_anos_experiencia, habilidades = p_habilidades, cv_path = p_cv_path WHERE id = p_postulante_id;
  INSERT INTO logs_auditoria (usuario_mysql, accion, tabla_afectada, fila_id, descripcion)
    VALUES (CURRENT_USER(), 'UPDATE', 'postulantes', CAST(p_postulante_id AS CHAR), CONCAT('sp_update_postulante ejecutado'));
END$$

CREATE PROCEDURE sp_get_postulante(IN p_postulante_id INT)
BEGIN
  SELECT id, nombre, email, anos_experiencia, habilidades, cv_path, creado_en FROM postulantes WHERE id = p_postulante_id;
END$$

DELIMITER ;
