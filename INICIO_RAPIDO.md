# 🚀 GUÍA DE INICIO RÁPIDO - APP RECLUTAMIENTO

## ⚡ Inicio Rápido (30 segundos)

```bash
# 1. Navega a la carpeta del proyecto
cd C:\Users\MOLLERICONA\Downloads\RECLUTACION

# 2. Inicia la aplicación (si no está corriendo)
python app.py

# 3. Abre en el navegador
# http://127.0.0.1:5000
```

La aplicación estará disponible en: **http://127.0.0.1:5000**

---

## 📝 Cuentas de Prueba

### Para Postulantes (Rol: postulante)
```
Usuario: postulante_demo
Email: postulante@demo.com
Contraseña: Demo@2026
```

### Para Reclutadores (Rol: reclutador)
```
Usuario: reclutador_user
Contraseña: RecluPass!2026
```

### Para Administradores (Rol: admin)
```
Usuario: admin_rrhh
Contraseña: AdminPass!2026
```

---

## 🎯 Flujo de Prueba Completo

### Paso 1: Registrar un Nuevo Postulante
```
1. Ir a: /register
2. Llenar formulario:
   - Nombre: Tu Nombre
   - Email: tu_email@example.com
   - Usuario: tu_usuario
   - Contraseña: Tu_Contraseña_123
3. Hacer clic: "Crear cuenta"
```

### Paso 2: Iniciar Sesión
```
1. Ir a: /login
2. Ingresar credenciales
3. Hacer clic: "Entrar"
4. ✅ Verás: "Bienvenido {usuario}"
```

### Paso 3: Completar Perfil
```
1. En navbar: 👤 {tu_usuario} → Editar Perfil
2. Llenar secciones:
   - Información Personal (Nombre, Email)
   - Años de Experiencia (ej: 5)
   - Habilidades (ej: Python, JavaScript)
   - Subir CV (PDF, DOC o DOCX)
3. Hacer clic: "Guardar cambios"
```

### Paso 4: Explorar Vacantes
```
1. Hacer clic en logo o: /
2. Puedes:
   - Ver todas las vacantes
   - Filtrar por Departamento
   - Buscar por texto
3. Hacer clic en "Ver detalle & Postularse"
```

### Paso 5: Postularse
```
1. En la página de vacante:
   - Leer descripción y requerimientos
   - En sidebar: "📤 Enviar Postulación"
2. ✅ Se calcula automáticamente tu compatibilidad
3. Se abre timeline con resultado
```

### Paso 6: Ver Timeline
```
1. Ves los eventos:
   - 📥 Postulación Recibida
   - 🤖 Evaluación IA (con score)
2. Puedes volver a: /mi-perfil
```

### Paso 7: Ver Mi Perfil
```
1. En navbar: 👤 {tu_usuario} → Ver Perfil
   O: /mi-perfil
2. Ves:
   - Datos personales y CV
   - Tabla de todas tus postulaciones
   - Estadísticas
3. Haz clic en "Ver Timeline" en cualquier postulación
```

---

## 🗂️ Estructura de Carpetas

```
RECLUTACION/
├── app.py                          # Aplicación Flask principal
├── setup_reclutamiento.sql         # Script de creación de BD
├── grant_execute_permisos.sql      # Permisos para SPs
├── seed_data.sql                   # Datos de prueba
├── requirements.txt                # Dependencias Python
│
├── templates/                      # Templates HTML
│   ├── base.html                  # Plantilla base
│   ├── index.html                 # Listado de vacantes
│   ├── register.html              # Registro
│   ├── login.html                 # Login
│   ├── postulante_perfil.html     # Mi Perfil
│   ├── postulante_editar.html     # Editar Perfil
│   ├── vacante.html               # Detalle de vacante
│   ├── postulacion_timeline.html  # Timeline
│   └── [otros templates]
│
├── static/                         # Archivos estáticos
│   └── css/
│       └── custom.css
│
├── uploads/                        # Carpeta de uploads
│   └── cvs/                        # CVs subidos
│
├── FLUJO_POSTULANTE.md            # Documentación del flujo
├── RESUMEN_IMPLEMENTACION.md      # Resumen de cambios
└── README.md                       # Este archivo
```

---

## 🔧 Requisitos del Sistema

### Software Requerido
- Python 3.8+
- MySQL 8.0+
- Flask 2.x

### Paquetes Python
```
Flask
SQLAlchemy
PyMySQL
werkzeug
python-dotenv
```

Instalar con:
```bash
pip install -r requirements.txt
```

---

## 🗄️ Base de Datos

### Setup Inicial
```bash
# 1. Crear BD y tablas
mysql -u root -p < setup_reclutamiento.sql

# 2. Otorgar permisos EXECUTE
mysql -u root -p < grant_execute_permisos.sql

# 3. (Opcional) Agregar datos de prueba
mysql -u root -p < seed_data.sql
```

### Conexión
```python
DB_HOST = 127.0.0.1
DB_NAME = reclutamiento
DB_USER = admin_rrhh
DB_PASS = AdminPass!2026
```

Configurar en `.env` si es necesario.

---

## 📋 Rutas Principales

| Ruta | Descripción |
|------|------------|
| `/` | Inicio - Listado de vacantes |
| `/register` | Registro de nuevo usuario |
| `/login` | Iniciar sesión |
| `/logout` | Cerrar sesión |
| `/mi-perfil` | Mi perfil (requiere autenticación) |
| `/postulante/<id>` | Ver perfil del postulante |
| `/postulante/editar/<id>` | Editar perfil |
| `/vacante/<id>` | Detalle de vacante |
| `/postular_ui` | Enviar postulación (POST) |
| `/postulacion/<id>/timeline` | Ver timeline |
| `/dashboard` | Dashboard (según rol) |
| `/reportes` | Reportes (reclutador/admin) |
| `/config/departamentos` | Configurar departamentos (admin) |
| `/auditoria` | Ver logs de auditoría (auditor/admin) |

---

## 🔐 Seguridad

### Contraseñas
- ✅ Se hashean con SHA2(256)
- ✅ Nunca se almacenan en texto plano
- ✅ Se validan contra hash en login

### Sesiones
- ✅ Almacenadas en Flask (seguras)
- ✅ Se limpian al logout
- ✅ Expiran automáticamente

### Auditoría
- ✅ Todos los cambios se registran
- ✅ Se registran intentos de login fallidos
- ✅ Se puede ver en: `/auditoria`

### Bloqueos
- ✅ Cuenta bloqueada tras 5 intentos fallidos
- ✅ Bloqueo de 15 minutos
- ✅ Se limpia al login exitoso

---

## ⚠️ Solución de Problemas

### Error: "stored_results"
**Causa**: Función incorrecta para pymysql
**Solución**: Ya está corregido en el código actual

### Error: "Execute denied for routine"
**Causa**: Permisos EXECUTE no otorgados
**Solución**: Ejecutar `grant_execute_permisos.sql`

### Error: "Tabla no encontrada"
**Causa**: BD no creada
**Solución**: Ejecutar `setup_reclutamiento.sql`

### Puerto 5000 en uso
**Causa**: Otra aplicación usa puerto 5000
**Solución**: 
```bash
# Windows
netstat -ano | findstr :5000
taskkill /PID {PID} /F

# O cambiar puerto en app.py
app.run(debug=True, port=5001)
```

### Archivo de CV no se sube
**Causa**: Extensión no permitida o tamaño > 5MB
**Solución**: Permitidas: PDF, DOC, DOCX

---

## 📞 Contacto y Soporte

- **Email**: support@reclutamiento.pyme
- **Documentación**: Ver `FLUJO_POSTULANTE.md`
- **Issues**: Reportar en GitHub

---

## 📝 Notas Importantes

1. **Datos de Prueba**: Los datos creados durante pruebas se guardan en BD
2. **Auditoría**: Todos los cambios se registran automáticamente
3. **CVs**: Se guardan en `/uploads/cvs/`
4. **Backups**: Hacer backup regular de BD
5. **Producción**: No usar `debug=True` en producción

---

## 🎓 Próximos Pasos

1. **Crear vacantes** (como reclutador)
2. **Postular** (como postulante)
3. **Ver rankings** (como reclutador/admin)
4. **Cambiar estados** (como admin)
5. **Ver auditoría** (como admin/auditor)

---

**¡Bienvenido al Sistema de Reclutamiento PYME!** 🎉

Versión: 1.0  
Última actualización: 19 de febrero de 2026
