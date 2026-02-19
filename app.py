from flask import Flask, request, jsonify
from sqlalchemy import create_engine
from flask import render_template, redirect, url_for, flash, session
import os
from werkzeug.utils import secure_filename
from pathlib import Path
from dotenv import load_dotenv

# Cargar variables desde .env (si existe)
load_dotenv()
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import text

app = Flask(__name__)
app.secret_key = os.getenv('FLASK_SECRET', 'dev-secret')
app.config['SESSION_PERMANENT'] = False
UPLOAD_FOLDER = os.path.join(os.path.dirname(__file__), 'uploads', 'cvs')
Path(UPLOAD_FOLDER).mkdir(parents=True, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
ALLOWED_EXT = {'pdf', 'doc', 'docx'}

# Configuración desde variables de entorno (usar credenciales seguras en producción)
DB_USER = os.getenv('DB_USER', 'admin_rrhh')
DB_PASS = os.getenv('DB_PASS', 'AdminPass!2026')
DB_HOST = os.getenv('DB_HOST', '127.0.0.1')
DB_NAME = os.getenv('DB_NAME', 'reclutamiento')

DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASS}@{DB_HOST}/{DB_NAME}"
engine = create_engine(DATABASE_URL, pool_pre_ping=True)


def call_proc(proc_name, params):
    conn = engine.raw_connection()
    cursor = None
    try:
        cursor = conn.cursor()
        cursor.callproc(proc_name, params)
        # recoger resultados si los hay
        results = []
        # Para pymysql, los resultados están en el primer cursor
        cols = [d[0] for d in cursor.description] if cursor.description else []
        for row in cursor.fetchall():
            results.append(dict(zip(cols, row)))
        # Avanzar a otros result sets si existen (para procedimientos con múltiples SELECT)
        while cursor.nextset():
            cols = [d[0] for d in cursor.description] if cursor.description else []
            for row in cursor.fetchall():
                results.append(dict(zip(cols, row)))
        conn.commit()
        return results
    except Exception as e:
        try:
            conn.rollback()
        except Exception:
            pass
        raise
    finally:
        if cursor is not None:
            try:
                cursor.close()
            except Exception:
                pass
        try:
            conn.close()
        except Exception:
            pass


@app.route('/postular', methods=['POST'])
def crear_postulacion():
    data = request.get_json()
    postulante_id = data.get('postulante_id')
    vacante_id = data.get('vacante_id')
    usuario = data.get('usuario', DB_USER)
    if not postulante_id or not vacante_id:
        return jsonify({'error': 'postulante_id y vacante_id requeridos'}), 400
    try:
        call_proc('sp_crear_postulacion', (postulante_id, vacante_id, usuario))
        return jsonify({'ok': True}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/ranking/<int:vacante_id>', methods=['GET'])
def ranking(vacante_id):
    try:
        rows = call_proc('sp_generar_ranking', (vacante_id,))
        # obtener info de vacante para encabezado
        vac = call_proc('sp_vacante_detalle', (vacante_id,))
        vacante = vac[0] if vac else {'titulo': 'Vacante'}
        return render_template('ranking.html', ranking=rows, vacante=vacante)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/')
def index():
    try:
        vacantes = call_proc('sp_listar_vacantes', ())
        return render_template('index.html', vacantes=vacantes)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/dashboard')
def dashboard():
    rol = session.get('rol_app')
    try:
        if rol == 'admin':
            stats = call_proc('vista_reporte_general', ())
            # vista_reporte_general devuelve una fila con totales
            stats_row = stats[0] if stats else {'total_vacantes': 0, 'total_postulantes': 0, 'promedio_score': 0}
            with engine.connect() as conn:
                recent = conn.execute(text('SELECT pt.nombre, v.titulo, po.fecha_postulacion FROM postulaciones po JOIN postulantes pt ON pt.id = po.postulante_id JOIN vacantes v ON v.id = po.vacante_id ORDER BY po.fecha_postulacion DESC LIMIT 10')).fetchall()
            # convertir rows a dict simple
            recent_list = [{'nombre': r[0], 'titulo': r[1], 'fecha_postulacion': r[2]} for r in recent]
            return render_template('dash_admin.html', stats=stats_row, recent=recent_list)
        elif rol == 'reclutador':
            vacantes = call_proc('sp_listar_vacantes', ())
            top = call_proc('sp_generar_ranking', (1,))[:5] if vacantes else []
            return render_template('dash_reclutador.html', vacantes=vacantes, top=top)
        elif rol == 'postulante':
            vacantes = call_proc('sp_listar_vacantes', ())
            return render_template('dash_postulante.html', vacantes=vacantes)
        elif rol == 'auditor':
            logs = call_proc('sp_listar_logs', ()) if 'sp_listar_logs' in globals() else call_proc('sp_listar_logs_dummy', ())
            return render_template('dash_auditor.html', logs=logs)
        else:
            return redirect(url_for('index'))
    except Exception as e:
        flash(str(e))
        return redirect(url_for('index'))



@app.route('/vacante/<int:vacante_id>')
def vacante_detalle(vacante_id):
    try:
        rows = call_proc('sp_vacante_detalle', (vacante_id,))
        if not rows:
            return "Vacante no encontrada", 404
        vacante = rows[0]
        return render_template('vacante.html', vacante=vacante)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXT


@app.route('/postulante/<int:postulante_id>')
def postulante_perfil(postulante_id):
    try:
        rows = call_proc('sp_get_postulante', (postulante_id,))
        if not rows:
            return "Postulante no encontrado", 404
        p = rows[0]
        
        # Obtener postulaciones del postulante
        with engine.connect() as conn:
            postulaciones = conn.execute(text('''
                SELECT po.id AS postulacion_id, po.fecha_postulacion, po.estado,
                       v.id AS vacante_id, v.titulo, d.nombre AS departamento,
                       e.score
                FROM postulaciones po
                JOIN vacantes v ON v.id = po.vacante_id
                LEFT JOIN departamentos d ON d.id = v.departamento_id
                LEFT JOIN evaluacion_ia e ON e.postulacion_id = po.id
                WHERE po.postulante_id = :postulante_id
                ORDER BY po.fecha_postulacion DESC
            '''), {'postulante_id': postulante_id}).fetchall()
        
        postulaciones_list = [dict(row._mapping) for row in postulaciones]
        
        return render_template('postulante_perfil.html', postulante=p, postulaciones=postulaciones_list)
    except Exception as e:
        flash(str(e))
        return redirect(url_for('index'))


@app.route('/postulante/editar/<int:postulante_id>', methods=['GET', 'POST'])
def postulante_editar(postulante_id):
    if request.method == 'GET':
        rows = call_proc('sp_get_postulante', (postulante_id,))
        if not rows:
            flash('Postulante no encontrado')
            return redirect(url_for('index'))
        return render_template('postulante_editar.html', postulante=rows[0])
    # POST: procesar edición y posible CV upload
    nombre = request.form.get('nombre')
    email = request.form.get('email')
    anos = int(request.form.get('anos_experiencia') or 0)
    habilidades = request.form.get('habilidades') or '[]'
    cv_path = None
    file = request.files.get('cv')
    if file and file.filename:
        if not allowed_file(file.filename):
            flash('Extensión de archivo no permitida')
            return redirect(url_for('postulante_editar', postulante_id=postulante_id))
        filename = secure_filename(f"postulante_{postulante_id}_cv_{file.filename}")
        fullpath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(fullpath)
        cv_path = os.path.relpath(fullpath, start=os.path.dirname(__file__))
    try:
        call_proc('sp_update_postulante', (postulante_id, nombre, email, anos, habilidades, cv_path))
        flash('Perfil actualizado')
        return redirect(url_for('postulante_perfil', postulante_id=postulante_id))
    except Exception as e:
        flash(str(e))
        return redirect(url_for('postulante_editar', postulante_id=postulante_id))


@app.route('/vacante/crear', methods=['GET', 'POST'])
def vacante_crear():
    if request.method == 'GET':
        # traer departamentos
        with engine.connect() as conn:
            deps = conn.execute(text('SELECT id, nombre FROM departamentos')).fetchall()
        return render_template('vacante_form.html', deps=deps, vacante=None)
    titulo = request.form.get('titulo')
    descripcion = request.form.get('descripcion')
    departamento_id = request.form.get('departamento_id')
    requerimientos = request.form.get('requerimientos') or '[]'
    usuario = session.get('username', DB_USER)
    if not departamento_id:
        flash('Departamento es requerido')
        return redirect(url_for('vacante_crear'))
    try:
        call_proc('sp_create_vacante', (titulo, descripcion, int(departamento_id), requerimientos, usuario))
        flash('Vacante creada')
        return redirect(url_for('index'))
    except Exception as e:
        flash(str(e))
        return redirect(url_for('vacante_crear'))


@app.route('/vacante/editar/<int:vacante_id>', methods=['GET', 'POST'])
def vacante_editar(vacante_id):
    if request.method == 'GET':
        with engine.connect() as conn:
            deps = conn.execute(text('SELECT id, nombre FROM departamentos')).fetchall()
        rows = call_proc('sp_vacante_detalle', (vacante_id,))
        if not rows:
            flash('Vacante no encontrada')
            return redirect(url_for('index'))
        vacante = rows[0]
        return render_template('vacante_form.html', deps=deps, vacante=vacante)
    # POST
    titulo = request.form.get('titulo')
    descripcion = request.form.get('descripcion')
    departamento_id_raw = request.form.get('departamento_id')
    if not departamento_id_raw:
        flash('Departamento es requerido')
        return redirect(url_for('vacante_editar', vacante_id=vacante_id))
    departamento_id = int(departamento_id_raw)
    requerimientos = request.form.get('requerimientos') or '[]'
    estado = request.form.get('estado') or 'abierta'
    usuario = session.get('username', DB_USER)
    try:
        call_proc('sp_update_vacante', (vacante_id, titulo, descripcion, departamento_id, requerimientos, estado, usuario))
        flash('Vacante actualizada')
        return redirect(url_for('vacante_detalle', vacante_id=vacante_id))
    except Exception as e:
        flash(str(e))
        return redirect(url_for('vacante_editar', vacante_id=vacante_id))


@app.route('/postulacion/<int:postulacion_id>/timeline')
def postulacion_timeline(postulacion_id):
    try:
        rows = call_proc('sp_postulacion_timeline', (postulacion_id,))
        return render_template('postulacion_timeline.html', timeline=rows, postulacion_id=postulacion_id)
    except Exception as e:
        flash(str(e))
        return redirect(url_for('index'))


@app.route('/postulacion/<int:postulacion_id>/recalcular', methods=['POST'])
def postulacion_recalcular(postulacion_id):
    try:
        call_proc('sp_recalcular_score', (postulacion_id,))
        flash('Score recalculado')
        # intentar volver a la pagina anterior
        return redirect(request.referrer or url_for('index'))
    except Exception as e:
        flash(str(e))
        return redirect(request.referrer or url_for('index'))


@app.route('/reportes')
def reportes():
    return render_template('reportes.html')


@app.route('/api/report/vacantes_mes')
def api_vacantes_mes():
    try:
        rows = call_proc('sp_report_vacantes_por_mes', ())
        return jsonify(rows)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/report/postulantes_vacante')
def api_postulantes_vacante():
    try:
        rows = call_proc('sp_report_postulantes_por_vacante', ())
        return jsonify(rows)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/auditoria')
def auditoria():
    user = request.args.get('user')
    accion = request.args.get('accion')
    fecha_from = request.args.get('from')
    fecha_to = request.args.get('to')
    # simplificación: usar sp_listar_logs y filtrar en Python
    try:
        logs = call_proc('sp_listar_logs', ())
        # aplicar filtros simples
        def within(row):
            ok = True
            if user and user.lower() not in (row.get('usuario_mysql') or '').lower():
                ok = False
            if accion and accion.lower() not in (row.get('accion') or '').lower():
                ok = False
            # fechas omitidas para simplicidad
            return ok
        logs_f = [r for r in logs if within(r)]
        return render_template('auditoria.html', logs=logs_f)
    except Exception as e:
        flash(str(e))
        return redirect(url_for('index'))


@app.route('/config/departamentos')
def config_departamentos():
    try:
        with engine.connect() as conn:
            deps = conn.execute(text('SELECT id, nombre, descripcion FROM departamentos ORDER BY nombre')).fetchall()
        return render_template('config_departamentos.html', deps=deps)
    except Exception as e:
        flash(str(e))
        return redirect(url_for('index'))


@app.route('/config/departamentos/crear', methods=['GET', 'POST'])
def config_departamento_crear():
    if request.method == 'GET':
        return render_template('config_departamento_form.html', dep=None)
    nombre = request.form.get('nombre')
    descripcion = request.form.get('descripcion')
    try:
        call_proc('sp_create_departamento', (nombre, descripcion))
        flash('Departamento creado')
        return redirect(url_for('config_departamentos'))
    except Exception as e:
        flash(str(e))
        return redirect(url_for('config_departamento_crear'))


@app.route('/config/usuarios')
def config_usuarios():
    try:
        users = call_proc('sp_listar_usuarios', ())
        return render_template('config_usuarios.html', users=users)
    except Exception as e:
        flash(str(e))
        return redirect(url_for('index'))



@app.route('/postular_ui', methods=['POST'])
def postular_ui():
    postulante_id_raw = request.form.get('postulante_id')
    vacante_id_raw = request.form.get('vacante_id')
    usuario = request.form.get('usuario', DB_USER)
    if not postulante_id_raw or not vacante_id_raw:
        flash('ID de postulante y vacante son requeridos')
        return redirect(request.referrer or url_for('index'))
    try:
        postulante_id = int(postulante_id_raw)
        vacante_id = int(vacante_id_raw)
    except (TypeError, ValueError):
        flash('ID de postulante o vacante inválido')
        return redirect(request.referrer or url_for('index'))
    try:
        call_proc('sp_crear_postulacion', (postulante_id, vacante_id, usuario))
        flash('Postulación enviada correctamente')
        return redirect(url_for('vacante_detalle', vacante_id=vacante_id))
    except Exception as e:
        flash(f'Error: {e}')
        return redirect(url_for('vacante_detalle', vacante_id=vacante_id))


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')
    username = request.form.get('username')
    password = request.form.get('password')
    if not username or not password:
        flash('Usuario y contraseña requeridos')
        return redirect(url_for('login'))
    try:
        rows = call_proc('sp_authenticate_user', (username, password))
        if rows:
            user = rows[0]
            session['user_id'] = user.get('id')
            session['username'] = user.get('username')
            session['rol_app'] = user.get('rol_app')
            flash('Bienvenido ' + session['username'])
            return redirect(url_for('index'))
        flash('Error de autenticación')
        return redirect(url_for('login'))
    except Exception as e:
        flash(str(e))
        return redirect(url_for('login'))


@app.route('/logout')
def logout():
    session.clear()
    flash('Sesión cerrada')
    return redirect(url_for('index'))


@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'GET':
        return render_template('register.html')
    nombre = request.form.get('nombre')
    email = request.form.get('email')
    username = request.form.get('username')
    password = request.form.get('password')
    if not (nombre and email and username and password):
        flash('Todos los campos son requeridos')
        return redirect(url_for('register'))
    try:
        # Crear postulante y usuario: insert postulante y crear usuario (rol postulante)
        # Insert postulante
        conn = engine.raw_connection()
        cur = None
        try:
            cur = conn.cursor()
            cur.execute('INSERT INTO postulantes (nombre, email) VALUES (%s, %s)', (nombre, email))
            postulante_id = cur.lastrowid
            conn.commit()
        finally:
            if cur is not None:
                try:
                    cur.close()
                except Exception:
                    pass
            try:
                conn.close()
            except Exception:
                pass
        # Crear usuario interno
        call_proc('sp_crear_usuario_ex', (username, password, nombre, email, 'postulante'))
        flash('Cuenta creada. Puedes iniciar sesión')
        return redirect(url_for('login'))
    except Exception as e:
        flash(str(e))
        return redirect(url_for('register'))


@app.route('/reset_request', methods=['GET', 'POST'])
def reset_request():
    if request.method == 'GET':
        return render_template('reset_request.html')
    username = request.form.get('username')
    if not username:
        flash('Usuario requerido')
        return redirect(url_for('reset_request'))
    # generar token simple (en producción usar token seguro)
    import uuid
    token = uuid.uuid4().hex
    try:
        call_proc('sp_request_password_reset', (username, token, 30))
        # normalmente enviar por email. Aquí devolvemos enlace en flash para pruebas
        reset_link = url_for('reset_password', token=token, _external=True)
        flash('Enlace de restablecimiento (prueba): ' + reset_link)
        return redirect(url_for('login'))
    except Exception as e:
        flash(str(e))
        return redirect(url_for('reset_request'))


@app.route('/reset/<token>', methods=['GET', 'POST'])
def reset_password(token):
    if request.method == 'GET':
        return render_template('reset_password.html', token=token)
    new_password = request.form.get('password')
    if not new_password:
        flash('Contraseña requerida')
        return redirect(url_for('reset_password', token=token))
    try:
        call_proc('sp_change_password_by_token', (token, new_password))
        flash('Contraseña actualizada. Inicia sesión.')
        return redirect(url_for('login'))
    except Exception as e:
        flash(str(e))
        return redirect(url_for('reset_password', token=token))


@app.route('/vacante/cerrar', methods=['POST'])
def cerrar_vacante():
    data = request.get_json()
    vacante_id = data.get('vacante_id')
    usuario = data.get('usuario', DB_USER)
    if not vacante_id:
        return jsonify({'error': 'vacante_id requerido'}), 400
    try:
        call_proc('sp_cerrar_vacante', (vacante_id, usuario))
        return jsonify({'ok': True}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True)
