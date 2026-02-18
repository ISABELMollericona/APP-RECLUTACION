-- Seed data para pruebas
USE reclutamiento;

-- Departamentos
INSERT INTO departamentos (nombre, descripcion) VALUES
('TI', 'Tecnologías de la Información'),
('Recursos Humanos', 'RRHH'),
('Marketing', 'Marketing y Comunicación');

-- Usuarios MySQL ya creados; insertar usuarios en tabla interna
CALL sp_crear_usuario_ex('admin', 'Admin!2026', 'Administrador', 'admin@example.com', 'admin');
CALL sp_crear_usuario_ex('reclutador1', 'Reclu!2026', 'Reclutador Uno', 'reclu1@example.com', 'reclutador');
CALL sp_crear_usuario_ex('auditor1', 'Audit!2026', 'Auditor Uno', 'auditor1@example.com', 'auditor');

-- Postulantes
INSERT INTO postulantes (nombre, email, anos_experiencia, habilidades) VALUES
('Ana Pérez', 'ana.perez@example.com', 5, JSON_ARRAY('python','sql','flask')),
('Luis Gómez', 'luis.gomez@example.com', 2, JSON_ARRAY('marketing','seo')),
('María López', 'maria.lopez@example.com', 8, JSON_ARRAY('java','spring'));

-- Vacantes
CALL sp_create_vacante('Desarrollador Python', 'Backend developer con experiencia en Flask y MySQL', 1, JSON_ARRAY('python','flask','mysql'), 'admin');
CALL sp_create_vacante('Analista de Marketing', 'Especialista en SEO y campañas digitales', 3, JSON_ARRAY('marketing','seo','ads'), 'admin');

-- Crear algunas postulaciones
CALL sp_crear_postulacion(1, 1, 'reclutador1');
CALL sp_crear_postulacion(2, 2, 'reclutador1');

-- Generar evaluaciones simples (si no creadas por SP)
INSERT IGNORE INTO evaluacion_ia (postulacion_id, score, criterios) SELECT p.id, 50.0, JSON_OBJECT('nota','seed') FROM postulaciones p WHERE p.id IS NOT NULL;

SELECT 'Seed completo' as message;
