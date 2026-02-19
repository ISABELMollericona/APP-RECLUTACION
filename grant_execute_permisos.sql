-- Script para otorgar permisos EXECUTE a los procedimientos almacenados
-- Ejecutar como root o con permisos suficientes

USE reclutamiento;

-- Otorgar EXECUTE en todos los procedimientos al rol admin
GRANT EXECUTE ON PROCEDURE sp_postulacion_timeline TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_recalcular_score TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_report_vacantes_por_mes TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_report_postulantes_por_vacante TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_report_promedio_score_por_departamento TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_create_departamento TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_update_departamento TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_listar_usuarios TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_crear_postulacion TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_generar_ranking TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_cerrar_vacante TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_listar_logs TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_log_auditoria TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_crear_usuario TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_listar_vacantes TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_vacante_detalle TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_listar_postulantes_por_vacante TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_crear_usuario_ex TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_authenticate_user TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_request_password_reset TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_change_password_by_token TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_create_vacante TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_update_vacante TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_update_postulante TO rol_admin;
GRANT EXECUTE ON PROCEDURE sp_get_postulante TO rol_admin;

-- Otorgar EXECUTE en FUNCTIONS también
GRANT EXECUTE ON FUNCTION fn_calcular_score TO rol_admin;
GRANT EXECUTE ON FUNCTION fn_validar_postulante TO rol_admin;

-- Aplicar los cambios
FLUSH PRIVILEGES;
