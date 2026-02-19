# 🔄 Flujo Completo del Postulante - Sistema de Reclutamiento

## Resumen General
El sistema implementa un flujo completo para postulantes que incluye registro, autenticación, gestión de perfil, exploración de vacantes, postulación y seguimiento del proceso.

---

## 1️⃣ Registro en la Plataforma

### Acceso
- **URL**: `/register`
- **Método**: GET/POST

### Funcionalidad
El usuario crea una cuenta completando:
- **Nombre completo** (requerido)
- **Email** (requerido, único)
- **Usuario** (nombre de usuario, requerido)
- **Contraseña** (requerido, hasheada con SHA2)

### Proceso Backend
```
POST /register
↓
1. Validar datos requeridos
2. Insertar en tabla `postulantes` (nombre, email)
3. Crear usuario en tabla `usuarios` con rol 'postulante'
4. Hashear contraseña con SHA2(256)
5. Registrar en auditoría
```

### Resultado
✅ Cuenta creada exitosamente
→ Redirigir a `/login`

---

## 2️⃣ Inicio de Sesión

### Acceso
- **URL**: `/login`
- **Método**: GET/POST

### Funcionalidad
El usuario ingresa:
- **Usuario**
- **Contraseña**

### Características de Seguridad
- ✓ Validación de credenciales contra BD (SHA2 256)
- ✓ Bloqueo de cuenta tras 5 intentos fallidos (15 minutos)
- ✓ Registro de auditoría de intentos de login
- ✓ Session segura (Flask session)

### Datos Almacenados en Sesión
```python
session['user_id']       # ID del usuario
session['username']      # Nombre de usuario
session['rol_app']       # 'postulante'
```

### Resultado
✅ Login exitoso
→ Redirigir a `/` (vacantes) o `/dashboard` (según rol)

---

## 3️⃣ Completar Perfil Profesional

### Acceso
- **URL**: `/postulante/editar/<id>`
- **Método**: GET/POST
- **Requiere**: Autenticación

### Secciones de Edición

#### A. Información Personal
- Nombre
- Email

#### B. Experiencia Profesional
- Años de experiencia (0-50)

#### C. Habilidades
- **Interfaz mejorada**: Input dinámico (añadir/eliminar)
- **Formato**: Array JSON automático
- **Ejemplo**: `["Python", "JavaScript", "SQL"]`

#### D. Currículum Vitae
- Formatos soportados: PDF, DOC, DOCX
- Tamaño máximo: 5MB
- Se almacena en: `/uploads/cvs/`

### Proceso Backend
```
POST /postulante/editar/<id>
↓
1. Validar autenticación
2. Convertir habilidades a JSON
3. Si hay archivo: 
   - Validar extensión
   - Guardar con nombre: postulante_{id}_cv_{nombre}
4. Actualizar en tabla `postulantes`
5. Registrar en auditoría
```

### Visualización
- **URL**: `/postulante/<id>` o `/mi-perfil`
- Muestra todos los datos del perfil
- Formatea habilidades como badges
- Link para descargar CV

---

## 4️⃣ Explorar Vacantes Disponibles

### Acceso
- **URL**: `/`
- **Método**: GET
- **Público**: Sí (no requiere autenticación)

### Funcionalidades

#### Listado de Vacantes
```
Cada vacante muestra:
- Título
- Descripción (truncada)
- Departamento
- Estado (Abierta/Cerrada/Pausada)
- Fecha de publicación
- Botón: Ver detalle & Postularse
```

#### Filtros
1. **Por Departamento**
   - Select dropdown con todos los departamentos
   - POST en tiempo real

2. **Búsqueda por Texto**
   - Busca en título y descripción
   - Case-insensitive

#### Respuesta sin Vacantes
- Mensaje informativo
- Invitación a volver más tarde

#### Call to Action
- Para no autenticados: Botones de Registro/Login
- Para postulantes: Directamente explorar y postular

---

## 5️⃣ Postularse a una Vacante

### Acceso
- **URL**: `/vacante/<id>` (GET para ver detalle)
- **URL**: `/postular_ui` (POST para crear postulación)
- **Método**: GET/POST

### Pantalla de Detalle de Vacante

**Sección Izquierda** (Información):
- Título completo
- Departamento
- Descripción completa
- Requerimientos (lista formateada)

**Sección Derecha** (Postulación):

Si **NO autenticado**:
```
⚠️ Necesitas autenticación
[Botón: Iniciar Sesión]
[Botón: Crear Cuenta]
```

Si **autenticado como postulante**:
```
✓ Usuario: {nombre}
[Botón: Enviar Postulación]
Mensaje: Se evaluará tu compatibilidad automáticamente
```

Si **autenticado como otro rol**:
```
⚠️ No tienes permisos
Solo postulantes pueden aplicar
[Botón: Cambiar usuario]
```

### Proceso de Postulación

```
POST /postular_ui
↓
1. Validar autenticación y rol
2. Validar que postulante no ya postuló a esta vacante
3. Insertar en tabla `postulaciones` (estado: en_revision)
4. Calcular score inicial:
   - Años de experiencia: anos * 2
   - Coincidencia de habilidades: coincidencias * 10
   - Score = MIN(100, años + habilidades)
5. Insertar en tabla `evaluacion_ia` con score
6. Registrar en auditoría
7. Mostrar mensaje de éxito
```

### Resultado
✅ Postulación registrada
→ Redirigir a `/postulacion/<id>/timeline`
→ Mostrar timeline del proceso

---

## 6️⃣ Seguimiento del Proceso

### Acceso
- **URL**: `/postulacion/<id>/timeline`
- **Método**: GET
- **Requiere**: Autenticación

### Vista de Timeline

**Información Mostrada**:
- 📥 Postulación Recibida
- 🤖 Evaluación IA Completada
- ✅ Aceptado / ❌ Rechazado
- Fecha y hora de cada evento
- Usuario que registró el evento

**Eventos del Proceso**:

1. **Postulación Recibida**
   - Trigger: `trg_postulaciones_after_insert`
   - Registra fecha y usuario

2. **Evaluación IA**
   - Score calculado automáticamente
   - Criterios guardados en JSON
   - Evento: `sp_recalcular_score`

3. **Estado Final**
   - Aceptado / Rechazado
   - Generalmente manual (reclutador/admin)

**Información Adicional**:
- ¿Qué esperar en cada etapa?
- Contacto: Recursos Humanos
- Botones: Volver a Vacantes, Mi Perfil

---

## 7️⃣ Recepción de Resultado Final

### En el Sistema

#### 1. **Vista de Perfil** (`/postulante/<id>`)
Tabla: "Mis Postulaciones"
```
| Vacante | Depto | Fecha | Estado | Score | Acciones |
|----|----|----|----|----|----| 
| Dev Backend | IT | 15/02 | En revisión | 75.5 | Ver Timeline |
| Marketing Manager | Mkt | 10/02 | Aceptado | 88.2 | Ver Timeline |
| Analyst | HR | 05/02 | Rechazado | 45.0 | Ver Timeline |
```

#### 2. **Timeline** (`/postulacion/<id>/timeline`)
- Historial completo de eventos
- Fechas y responsables
- Score final mostrado en evaluación

#### 3. **Estadísticas**
En sidebar del perfil:
- Total de postulaciones
- Aceptadas ✅
- Rechazadas ❌

### Notificaciones (Sistema)

✅ **Flash Messages** (mensajes en sesión):
- Postulación exitosa
- Cambios en perfil guardados
- Errores de validación

⚠️ **Potencial Mejora**:
- Email de notificación
- Sistema de notificaciones internas
- Push notifications

---

## 📊 Rutas Disponibles para Postulantes

| Ruta | Método | Descripción |
|------|--------|-------------|
| `/` | GET | Listar vacantes (público) |
| `/register` | GET/POST | Crear cuenta |
| `/login` | GET/POST | Iniciar sesión |
| `/logout` | GET | Cerrar sesión |
| `/vacante/<id>` | GET | Ver detalle y postular |
| `/postular_ui` | POST | Enviar postulación |
| `/mi-perfil` | GET | Acceso rápido a perfil (requiere auth) |
| `/postulante/<id>` | GET | Ver perfil completo |
| `/postulante/editar/<id>` | GET/POST | Editar perfil y CV |
| `/postulacion/<id>/timeline` | GET | Ver timeline de postulación |
| `/reset_request` | GET/POST | Solicitar reset de contraseña |
| `/reset/<token>` | GET/POST | Cambiar contraseña |

---

## 🗄️ Tablas Involucradas

### `postulantes`
```
id, nombre, email, anos_experiencia, habilidades (JSON), cv_path, creado_en
```

### `usuarios`
```
id, username, password_hash, nombre, email, rol_app ('postulante'), 
activo, failed_attempts, locked_until, reset_token, reset_expire
```

### `postulaciones`
```
id, postulante_id, vacante_id, fecha_postulacion, estado ('en_revision'),
usuario_creo, usuario_id
```

### `evaluacion_ia`
```
id, postulacion_id (UNIQUE), score, criterios (JSON), actualizado_en
```

### `logs_auditoria`
```
id, usuario_mysql, accion, tabla_afectada, fila_id, fecha, descripcion
```

---

## 🔐 Seguridad Implementada

✅ **Autenticación**:
- SHA2(256) para hash de contraseñas
- Session segura de Flask
- Bloqueo de cuenta tras intentos fallidos

✅ **Autorización**:
- Rol-based access control (RBAC)
- Validación en cada ruta
- Solo postulantes pueden postular

✅ **Auditoría**:
- Registro de todas las acciones
- Usuario y timestamp automáticos
- Triggers en tablas principales

✅ **Validación**:
- Datos requeridos validados
- Tipos de datos verificados
- Extensiones de archivo permitidas

---

## 🎯 Próximas Mejoras Sugeridas

1. **Email de Notificación**
   - Enviar email al postular
   - Notificar resultado final
   - Recordatorios de vacantes

2. **Dashboard Avanzado**
   - Gráficos de postulaciones
   - Estadísticas de tasas de aceptación
   - Comparativa de scores

3. **Mensajería**
   - Chat con reclutador
   - Preguntas sobre vacante
   - Feedback personalizado

4. **Recomendaciones IA**
   - Sugerir vacantes según perfil
   - Mejorar score automáticamente
   - Análisis de skills faltantes

5. **Certificaciones**
   - Validar certificaciones
   - Peso en scoring
   - Cargar documentos

---

## 📝 Ejemplo de Flujo Completo

```
1. Usuario accede a /register
   ↓ Llena datos (nombre, email, usuario, contraseña)
   ↓ Se crea postulante + usuario
   ↓ Flash: "Cuenta creada. Puedes iniciar sesión"

2. Accede a /login
   ↓ Ingresa usuario y contraseña
   ↓ Se valida contra BD
   ↓ Flash: "Bienvenido {usuario}"

3. Accede a /
   ↓ Ve lista de vacantes
   ↓ Filtra por departamento IT
   ↓ Busca "Backend"

4. Hace clic en vacante "Senior Backend Developer"
   ↓ Accede a /vacante/5
   ↓ Lee descripción y requerimientos
   ↓ Hace clic en "Enviar Postulación"

5. POST /postular_ui
   ↓ Sistema calcula score (90/100)
   ↓ Inserta postulación
   ↓ Redirige a timeline

6. Ve su timeline
   ↓ 📥 Postulación Recibida - Hace 2 minutos
   ↓ 🤖 Evaluación IA - Hace 1 minuto (Score: 90)
   ↓ ⏳ En espera de revisión del reclutador

7. Accede a /postulante/{id}
   ↓ Ve tabla "Mis Postulaciones"
   ↓ Puede ver todas sus postulaciones activas
   ↓ Puede hacer clic para ver timeline de cada una

8. Si es aceptado
   ↓ Estado cambia a "Aceptado" en BD
   ↓ Aparece ✅ en la tabla
   ↓ Puede ver en timeline cuándo fue aceptado
```

---

**Versión**: 1.0  
**Fecha**: 19 de febrero de 2026  
**Estado**: ✅ Implementado y Funcionando  
**Autor**: Sistema Inteligente de Reclutamiento
