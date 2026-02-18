# Sistema Inteligente de Reclutamiento para PYME

Resumen rápido
- Base de datos: MySQL (script: `setup_reclutamiento.sql`)
- Backend mínimo: Flask + SQLAlchemy (archivo `app.py`)
- Enfoque: lógica en MySQL (Stored Procedures, Functions, Triggers, Vistas, Auditoría, Roles y Permisos)

Instrucciones rápidas

1) Aplicar el script SQL

   - Ejecutar el script `setup_reclutamiento.sql` con un usuario con privilegios suficientes (ej. root):

```bash
mysql -u root -p < setup_reclutamiento.sql
```

2) Instalar dependencias Python

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

3) Configurar variables de entorno (opcional)

```bash
set DB_USER=admin_rrhh
set DB_PASS=AdminPass!2026
set DB_HOST=127.0.0.1
set DB_NAME=reclutamiento
```

4) Ejecutar Flask

```bash
python app.py
```

Seed y pruebas rápidas

- Cargar datos de prueba:

```bash
mysql -u root -p < setup_reclutamiento.sql
mysql -u root -p reclutamiento < seed_data.sql
```

- Carpeta para CVs: `uploads/cvs` se crea automáticamente al iniciar la app.

Rutas útiles
- `/` — listado de vacantes
- `/login` — iniciar sesión
- `/register` — registro postulante
- `/dashboard` — dashboard por rol
- `/postulante/<id>` — perfil postulante
- `/vacante/crear` y `/vacante/editar/<id>` — CRUD vacantes
- `/reportes` — reportes con gráficos
- `/auditoria` — visor de auditoría


Pruebas de seguridad y auditoría (guía)

- Validar roles y permisos:
  - Conéctese como `reclutador_user` y verifique que puede `SELECT`, `INSERT` y `UPDATE` en las tablas de la app, pero no `DELETE`.
  - Conéctese como `auditor_user` y confirme que solo tiene `SELECT`.
  - Conéctese como `admin_rrhh` y verifique todos los permisos.

- Probar hashing de contraseñas:
  - Use `CALL sp_crear_usuario('u1','MiPass123','Nombre','email@example.com','reclutador');`
  - Verifique que en la tabla `usuarios` el campo `password_hash` contiene `SHA2(...)` y que `password_plain` es NULL si se utiliza el SP.

- Probar triggers y auditoría:
  - Crear una postulacion válida vía `CALL sp_crear_postulacion(postulante_id, vacante_id, 'reclutador_user');` y luego revisar `SELECT * FROM logs_auditoria` para ver registros.
  - Intentar insertar una postulacion en una vacante inactiva para confirmar que el trigger `BEFORE INSERT` lanza error.
  - Intentar eliminar una vacante con postulaciones y confirmar que `BEFORE DELETE` bloquea la operación.
  - Actualizar `evaluacion_ia.score` y comprobar que `logs_auditoria` tiene el cambio.

Notas y buenas prácticas
- En producción no deje `password_plain` en la tabla: use SP para crear usuarios y revocar INSERT directo a roles no administrativos.
- Use conexiones TLS a MySQL, usuarios con contraseñas fuertes y rotadas regularmente.
- Para un motor IA real, reemplace la lógica de `sp_crear_postulacion` por llamadas a un servicio IA externo o funciones más complejas en MySQL si aplica.

Entrega
- `setup_reclutamiento.sql` — script SQL completo.
- `app.py` — ejemplo Flask mínimo que consume SPs.
- `requirements.txt` — dependencias.
- `README.md` — instrucciones y pruebas.
