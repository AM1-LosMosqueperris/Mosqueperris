# Auditoría Técnica — PetCare Santa Cruz

> **Alcance:** análisis estático de solo lectura del repositorio `C:\Users\USUARIO\Documents\PetCare` **contrastado con el esquema real de Supabase** (resultados de las consultas SQL de auditoría ejecutadas el 2026-11-16).
> **Restricción cumplida:** no se modificó, creó, eliminó ni reestructuró ningún archivo de la aplicación; **no se ejecutó ninguna operación que altere Supabase**. El SQL de corrección propuesto (Anexo A) está documentado, **no ejecutado**.
> **Convención de evidencia:**
> - **(A)** observado directamente en el código fuente.
> - **(V)** **verificado** contra el esquema real de Supabase.
> - **(I)** inferido a partir de (A) + (V), con alta confianza.
> - **(C)** no comprobable sin información adicional.

---

## 1. Resumen ejecutivo

**PetCare Santa Cruz** es una app Flutter/Dart con backend Supabase (Auth + PostgREST + Realtime) para gestión de mascotas con tres roles: `cliente`, `veterinario` y `administrador`. El código es funcional y de calidad razonable en arquitectura (feature-first, separación de responsabilidades, manejo de errores consistente, uso de RPCs para operaciones privilegiadas). La base de datos, en cambio, está **más completa y mejor diseñada que el código que la consume**: existen triggers de notificación, políticas RLS por rol y 16 RPCs de administración con validación de negocio, pero **falta el último paso de conectarlos**.

### 1.1 Conclusión principal (3 defectos que rompen funciones en producción)

El contraste código ↔ esquema revela un **desequilibrio de privilegios**: las políticas RLS de UPDATE se escribieron correctamente, pero los `GRANT` correspondientes nunca se aplicaron. En Postgres, **una policy sin privilegio de tabla no habilita nada**: el permiso de tabla se evalúa *antes* que RLS y, si falta, la operación se rechaza con `42501 permission denied` sin llegar a evaluar la policy.

| # | Defecto | Función de la app que queda rota | Evidencia |
|---|---|---|---|
| **D1** | `GRANT UPDATE` ausente en `public.reservas` (`authenticated` solo tiene `INSERT, SELECT`) | **Cliente:** "Cancelar reserva" · **Veterinario:** "Confirmar", "Cancelar" y **"Atender" cita** | `reservas_citas.dart:268-273`, `citas_veterinario.dart:134-137` y `:360-364` · grants §13b |
| **D2** | `GRANT UPDATE` ausente en `public.notificaciones` (`authenticated` solo tiene `SELECT`) | **Todos los roles:** "Marcar como leída" y "Marcar todas como leídas" → **la campanita nunca se limpia** | `notificaciones.dart:108-111` y `:148-152` · grants §13b |
| **D3** | Policy de INSERT de `reservas` compara `(fecha + hora) > now()` donde `hora` es `time without time zone` → Postgres lo interpreta como **UTC**, pero la app envía hora local naive | Validación de "cita futura" con **desfase de 4 h** (Santa Cruz es UTC-4) | `reservas_citas.dart:486-489` · policy §8 |

> **D1 tiene un efecto secundario grave:** en `citas_veterinario.dart` el `INSERT` en `historial_medico` (línea 337) se ejecuta **antes** que el `UPDATE` de la reserva a `'Atendida'` (línea 360), y ambos son sentencias independientes con auto-commit. Al fallar el UPDATE, **queda una atención médica registrada mientras la reserva sigue en `'Confirmada'`**: inconsistencia de datos silenciosa.

### 1.2 Lo que sí está bien construido (verificado)

- **Aislamiento por rol real**: 22 políticas RLS sobre 9 tablas; los veterinarios ven todas las mascotas/reservas, los clientes solo las suyas, y la lectura de `productos`/`servicios` es pública (`anon` + `authenticated`, solo `activo = true`).
- **Operaciones privilegiadas correctamente encapsuladas**: las 16 RPCs de administración son `SECURITY DEFINER` con `SET search_path TO ''` y validan `es_administrador()` antes de actuar. No hay superficie de admin expuesta por `GRANT` directo a `authenticated`.
- **Generación de notificaciones implementada en BD**: 7 triggers activos que cubren alta de reservas (admin + veterinario), cambios de estado de reserva, historial médico, consultas nuevas y consultas atendidas.
- **Realtime coherente**: las 9 tablas de la app están publicadas en `supabase_realtime` con insert/update/delete, y RLS se aplica al filtrado de eventos.
- **Coherencia app↔BD en los inserts sensibles**: el veterinario escribe `historial_medico.usuario_id` = **dueño de la mascota** (no su propio id), cumpliendo exactamente la policy `EXISTS (m.usuario_id = historial_medico.usuario_id)`. Verificado en `citas_veterinario.dart:171` y `detalle_mascota_veterinario.dart:129`.
- **Contratos de RPC 100 % alineados**: las 16 funciones que la app invoca existen con firma y tipo de retorno idénticos a lo que el Dart espera.

### 1.3 Brechas funcionales (ya conocidas, confirmadas)

- El **sistema de consultas** no tiene respuesta in-app, asignación a veterinario ni trazabilidad de quién atendió (solo alternancia `Pendiente`/`Atendida` + WhatsApp externo).
- Las **reservas** no tienen asignación de veterinario a la cita.
- Las **notificaciones** son 100 % internas (sin push) y 3 de los 7 tipos generados por los triggers no tienen icono/color propio en la UI.
- `citas` y `vacunas` son **esquema muerto** (existen, RLS activo, cero policies ⇒ inaccesibles) y la app no las usa.
- Modelos Dart vacíos (`cita.dart`, `mascota.dart`) y `database_helper.dart` sin implementar; casi todo el acceso a datos usa `Map<String, dynamic>`.

---

## 2. Estructura del proyecto

### 2.1 Árbol relevante de `lib/`

- `lib/main.dart` — entrada, listener de Auth, rutas, navegación del cliente, router por rol.
- `lib/config/config.dart` — `Config.supabaseUrl`, `Config.supabaseAnonKey`.
- `lib/database/database_helper.dart` — **vacío** (placeholder).
- `lib/core/constants/`, `lib/core/theme/`, `lib/core/widgets/`, `lib/widgets/` — directorios **sin archivos**.
- `lib/features/auth/screens/` — `bienvenida.dart`, `login.dart`, `nueva_password.dart`.
- `lib/features/cliente/screens/` — `inicio.dart`, `registro_mascotas.dart`, `servicios.dart`, `reservas_citas.dart`, `control_vacunas.dart`, `historial.dart`, `tienda.dart`, `contacto.dart`, `consultas.dart`.
- `lib/features/veterinario/screens/` — `panel_veterinario.dart`, `detalle_mascota_veterinario.dart`, `citas_veterinario.dart`.
- `lib/features/administrador/screens/` — `panel_administrador.dart`, `gestion_servicios.dart`, `gestion_productos.dart`, `gestion_mascotas.dart`, `gestion_reservas_admin.dart`, `gestion_consultas_admin.dart`, `reportes_admin.dart`.
- `lib/features/notificaciones/screens/` — `notificaciones.dart`.
- `lib/models/` — `cita.dart` (**vacío**), `mascota.dart` (**vacío**), `producto.dart`, `servicio.dart`.
- `lib/services/` — `producto_service.dart`, `servicio_service.dart`.
- `lib/utils/` — `validadores.dart`.

### 2.2 Otros elementos del repositorio

- `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `README.md`.
- `doc/01_descripcion_general.md` … `doc/08_manual_de_usuario.md`.
- Plataformas: `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`.
- `test/widget_test.dart`.
- **No hay archivos `.sql` ni migraciones versionadas** (C): el esquema de BD no está en control de versiones. Este es el principal riesgo de reproducibilidad del proyecto.

---

## 3. Tecnologías y dependencias

| Componente | Evidencia | Estado |
|---|---|---|
| Flutter / Dart | `pubspec.yaml` (`sdk: ^3.13.7`, Material 3) | (A) |
| Supabase | `supabase_flutter: ^2.18.3`; PKCE en `main.dart:26-32` | (A) |
| PostgREST / RPC | 16 RPCs de app | (A) + (V) |
| Realtime | `postgres_changes` en 20+ puntos de suscripción | (A) + (V) |
| URL externa | `url_launcher: ^6.3.3` (WhatsApp admin) | (A) |
| Persistencia local | `shared_preferences: ^2.5.3` (en `dev_dependencies`, sin uso en `lib/`) | (A) |
| Lints/tests | `flutter_lints: ^6.0.0`, `flutter_test` (1 test) | (A) |
| Push / local notifications | **Ninguna** dependencia (`firebase_*`, `fcm`, `onesignal`, `flutter_local_notifications` ausentes en `pubspec.yaml`/`pubspec.lock`/`AndroidManifest.xml`) | (A) |
| Extensiones BD | `pgcrypto`, `uuid-ossp`, `supabase_vault`, `pg_stat_statements` | (V) |
| ENUMs propios | **Ninguno** — todos los estados son `text` + `CHECK` | (V) |
| Vistas en `public` | **Ninguna** | (V) |

---

## 4. Funcionalidades del administrador

| Funcionalidad | Archivo / clase / función | Qué hace (A) | Tablas/RPC | Permiso real en BD (V) | Observaciones |
|---|---|---|---|---|---|
| Panel, KPIs y accesos | `administrador/screens/panel_administrador.dart` — `PanelAdministradorScreen` (`_cargarNotificacionesAdmin`, `_escucharNotificacionesAdmin`, `cargarUsuarios`, `cargarEstadisticas`, `_escucharResumen`, `cambiarRol`, `_cerrarSesion`) | Badge de notificaciones, lista de usuarios, estadísticas, navegación a módulos, cambio de rol | `notificaciones`, `perfiles`, `mascotas`, `reservas`; RPC `listar_perfiles_admin`, `obtener_estadisticas_admin`, `cambiar_rol_usuario` | `perfiles`: solo `SELECT` para `authenticated` → el listado global llega por RPC `SECURITY DEFINER` | Las 3 RPC validan `es_administrador()` y usan `search_path TO ''` |
| Gestión de servicios | `gestion_servicios.dart` — `GestionServiciosScreen` (`cargarServicios`, `mostrarFormulario`/`guardar`, `cambiarEstado`, `escucharCambios`) | Lista, crea/edita, activa/desactiva | RPC `listar_servicios_admin`, `guardar_servicio_admin`, `cambiar_estado_servicio_admin`; realtime `servicios` | Sin `INSERT`/`UPDATE` de tabla para `authenticated` ⇒ todo pasa por RPC | `guardar_servicio_admin` valida nombre obligatorio, precio ≥ 0 y duración > 0 |
| Gestión de productos | `gestion_productos.dart` — `GestionProductosScreen` (`cargarProductos`, `guardarProducto`, `actualizarStock`, `cambiarEstadoProducto`, `escucharCambios`) | CRUD, stock, estado, búsqueda/filtros | RPC `listar_productos_admin`, `crear_producto_admin`, `editar_producto_admin`, `actualizar_stock_producto_admin`, `cambiar_estado_producto_admin` | Igual: por RPC | `crear_producto_admin` valida nombre, precio y stock; `productos` tiene CHECK `precio >= 0` y `stock >= 0` |
| Gestión de mascotas (consulta) | `gestion_mascotas.dart` — `GestionMascotasScreen` (`cargarMascotas`, `escucharCambios`, `mostrarDetalle`) | Lista/busca e indicadores; detalle en diálogo | RPC `listar_mascotas_admin`; realtime `mascotas` | `SECURITY DEFINER` + guard `es_administrador()` | Solo lectura; no hay edición ni borrado |
| Gestión de reservas | `gestion_reservas_admin.dart` — `GestionReservasAdminScreen` (`cargarReservas`, `escucharReservas`, `cambiarEstadoReserva`) | Lista/filtro/búsqueda, detalle, cambio de estado | RPC `listar_reservas_admin`, `cambiar_estado_reserva_admin` | `cambiar_estado_reserva_admin` valida `estado IN ('Pendiente','Confirmada','Atendida','Cancelada')` | El RPC **sí funciona** (el admin no depende del `GRANT UPDATE`) → **el admin no está afectado por D1** |
| Gestión de consultas | `gestion_consultas_admin.dart` — `GestionConsultasAdminScreen` (`cargarConsultas`, `cambiarEstadoConsulta`, `mostrarDetalle`, `contactarWhatsApp`, `escucharConsultas`) | Bandeja, métricas, búsqueda, detalle, alterna estado, WhatsApp | `consultas` + RPC `cambiar_estado_consulta` | `consultas`: `authenticated` tiene `INSERT, SELECT` (sin UPDATE) ⇒ el cambio de estado **debe** ir por RPC | `cambiar_estado_consulta` valida `estado IN ('Pendiente','Atendida')`. **Solo escucha `insert` en realtime** → un cambio de estado desde otra sesión no refresca en vivo |
| Reportes | `reportes_admin.dart` — `ReportesAdminScreen`, `GraficoCircularPainter` (`cargarReportes`, `_escucharReportes`) | KPIs y gráficos circulares/barras | RPC `obtener_reportes_admin` (jsonb) | Contrato **coincide exactamente**: `total_usuarios`, `total_atenciones`, `mascotas_por_especie`, `reservas_por_estado`, `servicios_solicitados` | El RPC ya aplica `COALESCE(...,'[]')` para arrays vacíos |
| Notificaciones | Acceso desde paneles a `NotificacionesScreen` | Listado y marcado de leídas | `notificaciones` | **Solo `SELECT`** ⇒ **marcar leída falla (D2)** | El badge de los paneles se recalcula al volver de la pantalla |

---

## 5. Funcionalidades del veterinario

| Funcionalidad | Archivo / clase / función | Qué hace (A) | Tablas | Permiso real en BD (V) | Observaciones |
|---|---|---|---|---|---|
| Panel de pacientes | `veterinario/screens/panel_veterinario.dart` (`cargarMascotas`, `_cargarNotificacionesVeterinario`, `_escucharMascotas`, `_escucharNotificacionesVeterinario`, `abrirGestionCitas`, `abrirDetalleMascota`, `_cerrarSesion`) | Lista/busca mascotas, badge, navegación | `mascotas`, `notificaciones` | Policy "Veterinarios pueden ver mascotas" ⇒ **ve todas las mascotas** (coherente con el diseño) | Realtime global sobre `mascotas` |
| Detalle e historial | `veterinario/screens/detalle_mascota_veterinario.dart` (`cargarHistorial`, `escucharHistorial`, `registrarAtencion`) | Registra atención médica; lista historial por mascota | `perfiles`, `historial_medico` | INSERT permitido solo si `veterinario_id = auth.uid()` **y** el usuario es `veterinario` **y** `mascota.usuario_id = historial_medico.usuario_id` | **El código cumple la policy**: `usuario_id` = dueño de la mascota (`detalle_mascota_veterinario.dart:129`) |
| Gestión de citas | `veterinario/screens/citas_veterinario.dart` (`cargarReservas`, `escucharReservas`, `cambiarEstado`, `atenderCita`) | Filtra reservas, confirma/cancela, atiende (crea historial + marca Atendida) | `reservas`, `perfiles`, `historial_medico` | Policy "Veterinarios pueden ver todas las reservas" ⇒ SELECT OK; **UPDATE bloqueado por falta de `GRANT` (D1)** | Al atender, el `INSERT` en `historial_medico` **sí se commitea** y el `UPDATE` de la reserva **falla** → estado inconsistente |
| Consultas asignadas / médicas | — | — | — | No existe tabla/policy para ello | **No implementado** |
| Responder directamente al cliente | — | — | — | — | **No implementado** |

---

## 6. Funcionalidades del cliente

| Funcionalidad | Archivo / clase / función | Qué hace (A) | Tablas/servicios | Permiso real en BD (V) | Observaciones |
|---|---|---|---|---|---|
| Autenticación | `auth/screens/login.dart` (`_autenticar`, `_recuperarPassword`), `nueva_password.dart` (`_actualizarPassword`), `bienvenida.dart`; `main.dart` | Login/registro/reset/update, rutas, router por rol | Auth, `perfiles` | `perfiles` solo `SELECT` con `auth.uid() = id` | El registro funciona gracias al trigger `crear_perfil_usuario()` sobre `auth.users`, que inserta `rol='cliente'` y toma el nombre de `raw_user_meta_data->>'full_name'` — **coincide con el `data: {'full_name': ...}` que envía la app** |
| Inicio / resumen | `cliente/screens/inicio.dart` (`_cargarResumen`, `_escucharNotificaciones`) | KPIs, próximas citas, accesos, badge | `mascotas`, `reservas`, `historial_medico`, `notificaciones` | Todo filtrado por `usuario_id` | Realtime en las 4 tablas con filtro `usuario_id` |
| Registro de mascotas | `registro_mascotas.dart` (`cargarMascotas`, `registrarMascota`, `_escucharCambios`) | Alta y listado de mascotas propias | `mascotas` | `authenticated` tiene `INSERT, SELECT, UPDATE`; policy exige `auth.uid() = usuario_id` | `mascotas.usuario_id` es **nullable** en BD pero la policy no lo permite en la práctica |
| Catálogo de servicios | `servicios.dart`; `services/servicio_service.dart`; `models/servicio.dart` | Lista servicios activos | `servicios` | Policy "Lectura pública de servicios" (`anon` + `authenticated`, `activo = true`) | Coherente con la pantalla pública `/servicios-publicos` |
| Reservas / citas | `reservas_citas.dart` (`_cargarMascotas`, `_cargarCitas`, `solicitarCita`, `_cancelarCita`, `_escucharCambios`) | Crear, listar, cancelar pendientes | `mascotas`, `reservas` | INSERT: policy valida `usuario_id`, `length(nombre)>0`, `telefono ~ '^[0-9]{8}$'`, `personas 1..50`, `(fecha+hora) > now()` | La app no envía `personas` ni `estado` ⇒ entran los defaults (`1`, `'Pendiente'`) ✓. **Cancelar falla (D1)**. **Zona horaria (D3)** |
| Control de vacunas | `control_vacunas.dart` (`cargarDatos`, `_escucharCambios`) | Registros con vacuna por mascota | `mascotas`, `historial_medico` | Filtra `vacuna IS NOT NULL AND <> ''` | **Usa `historial_medico.vacuna`, no la tabla `vacunas`** → se pierde el concepto de `proxima_fecha` |
| Historial médico | `historial.dart` (`cargarMascotas`, `seleccionarMascota`, `_escucharCambios`) | Historial por mascota con filtros UI | `mascotas`, `historial_medico` | Policy propia o `rol='veterinario'` | Solo lectura para el cliente |
| Tienda | `tienda.dart` (`cargarProductos`, `escucharCambios`); `services/producto_service.dart`; `models/producto.dart` | Catálogo activo con búsqueda y stock | `productos` | Lectura pública `activo = true` | Sin carrito/compra |
| Consultas | `consultas.dart` (`_enviarConsulta`, `_cargarMisConsultas`, `_escucharMisConsultas`) | Envía consulta y ve su estado | `consultas` | INSERT: policy exige `usuario_id`, `length(trim(mensaje)) >= 10` **y `estado = 'Pendiente'`** (satisfecho por el default) | `consultas.usuario_id` es **nullable** ⇒ un registro sin dueño rompe el trigger de "atendida" (§12) |
| Contacto | `contacto.dart` | Información estática | — | — | Datos placeholder ("por confirmar") |
| Notificaciones | `notificaciones/screens/notificaciones.dart` | Lista y marca leída | `notificaciones` | **Solo `SELECT`** ⇒ **D2** | Tipos no mapeados en UI: `reserva_admin`, `reserva_veterinario`, `usuario_nuevo` |

---

## 7. Sistema de consultas

### 7.1 Esquema real (V)

```
consultas(
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre       text NOT NULL,
  telefono     text NOT NULL,
  mensaje      text NOT NULL,
  created_at   timestamptz DEFAULT now(),
  usuario_id   uuid NULL REFERENCES auth.users ON DELETE NO ACTION,
  estado       text NOT NULL DEFAULT 'Pendiente'
               CHECK (estado IN ('Pendiente','Atendida'))
)
```

### 7.2 Flujo verificado

| Paso | Actor | Mecanismo | Verificación |
|---|---|---|---|
| Crear | Cliente | `INSERT` directo con `usuario_id, nombre, telefono, mensaje` (`consultas.dart:153-158`) | Policy INSERT exige `mensaje` ≥ 10 y `estado='Pendiente'` (default) ✓ |
| Notificar a admins | BD | Trigger `trigger_nueva_consulta_admin` AFTER INSERT → `notificar_nueva_consulta_admin()` inserta **una notificación por cada admin** con `tipo='consulta_admin'` | (V) Trigger activo |
| Listar cliente | Cliente | `SELECT ... eq('usuario_id', uid).order('created_at', desc)` + realtime `all` filtrado | Policy "Usuarios pueden ver sus consultas" ✓ |
| Listar admin | Admin | `SELECT` de toda la tabla | Policy "Administradores pueden ver todas las consultas" (`es_administrador()`) ✓ |
| Cambiar estado | Admin | RPC `cambiar_estado_consulta(p_consulta_id, p_estado)` | `SECURITY DEFINER` + valida estado ✓ **funciona** |
| Notificar al cliente | BD | Trigger `trigger_consulta_atendida_cliente` AFTER UPDATE OF estado → `notificar_consulta_atendida()` inserta `tipo='consulta_atendida'` | (V) Trigger activo |
| Ver en cliente | Cliente | Realtime `all` sobre `consultas` filtrado por `usuario_id` → recarga | El trigger inserta en `notificaciones`, y la pantalla de notificaciones **sí** recibe realtime ✓ (pero marcar leída falla → D2) |

### 7.3 Capacidades ausentes (confirmado)

| Capacidad | Estado | Detalle |
|---|---|---|
| Respuesta personalizada in-app | ❌ Ausente | No existe columna de respuesta ni UI; la columna `consultas` no tiene campo `respuesta` |
| Asignación a veterinario | ❌ Ausente | Sin campo `asignado_a`; no hay pantalla de consultas para veterinario |
| Seguimiento de quién atendió | ❌ Ausente | No existe `respondida_por` ni timestamp de atención |
| Comunicación cliente↔veterinario | ❌ Ausente | Sin chat/hilos. Único canal: WhatsApp externo iniciado por el admin (`gestion_consultas_admin.dart:156-192`) |
| Notificación al cliente de la respuesta | ⚠️ Parcial | El trigger notifica el **cambio de estado**, pero el mensaje es genérico: *"Ingresa a PetCare para revisar su estado"* — no hay texto de respuesta que leer |

### 7.4 Propuesta de evolución (sin perder lo existente)

**Capa BD (aditiva):**
1. `ALTER TABLE public.consultas ADD COLUMN IF NOT EXISTS tipo text;` (administrativa/médica)
2. `ADD COLUMN IF NOT EXISTS asignado_a uuid REFERENCES auth.users(id) ON DELETE SET NULL;`
3. `ADD COLUMN IF NOT EXISTS respuesta text;`
4. `ADD COLUMN IF NOT EXISTS respondida_por uuid REFERENCES auth.users(id) ON DELETE SET NULL;`
5. `ADD COLUMN IF NOT EXISTS respondida_en timestamptz;`
6. `ADD COLUMN IF NOT EXISTS mascota_id bigint REFERENCES public.mascotas(id) ON DELETE SET NULL;`
7. Nueva tabla `consulta_mensajes(id, consulta_id FK, emisor_id, texto, created_at)` para hilos.
8. RPC `responder_consulta(p_consulta_id, p_respuesta)` `SECURITY DEFINER` que valida rol (admin o veterinario), escribe la respuesta, actualiza estado y **notifica** con el texto.
9. Nueva policy de SELECT para veterinarios sobre consultas **asignadas** y nueva policy de UPDATE que restrinja el estado a valores válidos.
10. Triggers: `notificar_nueva_consulta_veterinario` (consultas médicas asignadas) y ampliar `notificar_consulta_atendida` para incluir la respuesta.

**Capa app (aditiva):**
- `lib/features/veterinario/screens/consultas_veterinario.dart` (nuevo): bandeja de consultas médicas asignadas + formulario de respuesta.
- `lib/features/administrador/screens/gestion_consultas_admin.dart`: añadir selector de tipo, campo de respuesta, asignación a veterinario, y escuchar `update` además de `insert` en realtime.
- `lib/features/cliente/screens/consultas.dart`: mostrar la respuesta y el estado en la tarjeta de cada consulta.
- `lib/features/notificaciones/screens/notificaciones.dart`: mapear los tipos `reserva_admin`, `reserva_veterinario`, `usuario_nuevo`.

---

## 8. Sistema de reservas

### 8.1 Esquema real (V)

```
reservas(
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre     text NOT NULL,
  telefono   text NOT NULL,
  fecha      date NOT NULL,
  hora       time WITHOUT time zone NOT NULL,
  personas   integer NOT NULL DEFAULT 1 CHECK (personas BETWEEN 1 AND 50),
  created_at timestamptz DEFAULT now(),
  usuario_id uuid NULL REFERENCES auth.users ON DELETE NO ACTION,
  mascota    text NULL,            -- nombre denormalizado
  servicio   text NULL,            -- nombre denormalizado
  comentario text NULL,
  estado     text NOT NULL DEFAULT 'Pendiente',   -- ⚠️ SIN CHECK
  mascota_id bigint NULL REFERENCES public.mascotas(id) ON DELETE SET NULL
)
```

### 8.2 Ciclo de vida verificado

| Transición | Quién | Mecanismo | Estado |
|---|---|---|---|
| Crear | Cliente | `INSERT` directo (`reservas_citas.dart:478-490`) | ✅ Funciona (policy satisfecha) |
| Notificar admins | BD | Trigger `trigger_nueva_reserva_admin` AFTER INSERT → `tipo='reserva_admin'` | ✅ |
| Notificar veterinarios | BD | Trigger `trigger_nueva_reserva_veterinario` AFTER INSERT → `tipo='reserva_veterinario'` | ✅ |
| Ver propias | Cliente | `SELECT ... eq('usuario_id', uid)` | ✅ |
| Ver todas | Veterinario | `SELECT` sin filtro + policy "Veterinarios pueden ver todas las reservas" | ✅ |
| Ver todas | Admin | RPC `listar_reservas_admin` (LEFT JOIN a `mascotas` para `nombre_mascota`/`especie_mascota`) | ✅ |
| **Cancelar (cliente)** | Cliente | `UPDATE` directo condicionado a `usuario_id` | ❌ **D1 — sin `GRANT UPDATE`** |
| **Confirmar / Cancelar (vet)** | Veterinario | `UPDATE` directo por `id` | ❌ **D1** |
| **Atender (vet)** | Veterinario | `INSERT` historial + `UPDATE` estado a `'Atendida'` (con `eq('estado','Confirmada')`) | ⚠️ **D1 — el INSERT se commitea, el UPDATE falla** |
| Cambiar estado (admin) | Admin | RPC `cambiar_estado_reserva_admin` con validación de los 4 estados | ✅ |
| Notificar cliente | BD | Trigger `trigger_notificar_cambio_reserva` AFTER UPDATE OF estado WHEN estado cambia → `tipo='reserva'` con mensajes "Cita confirmada/cancelada/atendida" | ✅ (pero el cliente no puede marcar la notificación como leída → D2) |

### 8.3 Limitaciones confirmadas

| Limitación | Evidencia |
|---|---|
| Sin asignación de veterinario a la cita | No existe columna `veterinario_id` en `reservas` (V). El `veterinario_id` solo se guarda en `historial_medico` |
| Sin validación de disponibilidad/solapamiento | No hay índice único ni exclusión por (`fecha`,`hora`) (V); la app solo valida "fecha/hora futura" |
| Servicios hardcodeados | `reservas_citas.dart:73-80` — lista fija en el cliente, sin leer la tabla `servicios` |
| Datos denormalizados | `nombre`, `telefono`, `mascota` y `servicio` se guardan como texto además de los ids |
| Sin CHECK de estado | `reservas.estado` es `text` libre (V), a diferencia de `consultas.estado` y `perfiles.rol`. La validación solo existe en la RPC de admin |
| Zona horaria (D3) | Policy compara `(fecha + hora) > now()`; `hora` es `time without time zone` ⇒ se interpreta como UTC mientras la app envía hora local de Santa Cruz (UTC-4) |
| Cero índices de soporte | Solo `reservas_pkey` (V). Las consultas `.eq('usuario_id').order('fecha')` y `.order('fecha')` hacen seq scan + sort |
| Sin trigger de "nueva reserva" hacia el cliente | Correcto por diseño (el cliente ve la reserva en su propia lista) |

---

## 9. Sistema de notificaciones

### 9.1 Esquema real (V)

```
notificaciones(
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  usuario_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  titulo     text NOT NULL,
  mensaje    text NOT NULL,
  tipo       text NOT NULL,
  leida      boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
)
Índice: idx_notificaciones_usuario_fecha ON (usuario_id, created_at DESC)   ← único índice no-PK del proyecto
```

### 9.2 Tipos: generados por BD (V) vs. reconocidos por la UI (A)

| `tipo` generado | Función trigger | Destinatario | Icono/color en UI |
|---|---|---|---|
| `reserva` | `notificar_cambio_reserva` | Cliente dueño de la reserva | ✅ `Icons.calendar_month_outlined` / azul |
| `consulta_admin` | `notificar_nueva_consulta_admin` | **Todos** los admins | ✅ `Icons.contact_support_outlined` / morado |
| `consulta_atendida` | `notificar_consulta_atendida` | Cliente de la consulta | ✅ `Icons.mark_email_read_outlined` / verde |
| `historial_medico` | `notificar_nuevo_historial` | Cliente dueño de la mascota | ✅ `Icons.medical_services_outlined` / verde |
| `reserva_admin` | `notificar_nueva_reserva_admin` | **Todos** los admins | ❌ cae en `default` (`Icons.notifications_none` / naranja) |
| `reserva_veterinario` | `notificar_nueva_reserva_veterinario` | **Todos** los veterinarios | ❌ cae en `default` |
| `usuario_nuevo` | `notificar_nuevo_usuario_admin` | **Todos** los admins (≠ el nuevo usuario) | ❌ cae en `default` |

> Las policies replican el fan-out: cada admin y cada veterinario recibe **su propia fila** de notificación, por lo que el filtro `usuario_id` del cliente coincide con el modelo de permisos. ✓

### 9.3 Funcionamiento verificado

| Aspecto | Implementación | Estado |
|---|---|---|
| Listado | `SELECT ... eq('usuario_id', uid).order('created_at', desc)` | ✅ |
| Realtime | `postgres_changes` con `filter usuario_id = uid` (eventos `all` en cliente, `insert`+`update` en admin/vet) | ✅ Las 9 tablas están en `supabase_realtime` |
| Badge / campanita | Conteo `select('id').eq('leida', false)` + incremento en `insert` y recálculo en `update`; muestra `99+` | ✅ Funciona (lectura) |
| Marcar leída individual | `UPDATE ... eq('id', ...)` al tocar | ❌ **D2 — sin `GRANT UPDATE`** |
| Marcar todas | `UPDATE ... eq('usuario_id', uid).eq('leida', false)` | ❌ **D2** |
| Push / FCM | Ninguna dependencia ni permiso en el manifiesto | ❌ No implementado (solo internas) |

> Consecuencia de D2: el badge **nunca baja a 0** y la pantalla muestra el error *"No se pudo marcar como leída."*. Es el defecto con mayor impacto visible para el usuario final.

---

## 10. Integración con Supabase

### 10.1 Estado general verificado

| Aspecto | Resultado |
|---|---|
| Esquema `public` | 10 tablas, todas con RLS habilitado |
| `relforcerowsecurity` | `false` en todas (el owner `postgres` no está forzado; irrelevante porque las RPC son `SECURITY DEFINER` con owner superusuario) |
| Policies | 22 sobre 9 tablas; `citas` y `vacunas` sin policies ⇒ **0 filas** para `authenticated` |
| Funciones | 24 en `public`: 17 usadas por la app + `es_administrador()` + 6 triggers |
| Seguridad de funciones | Todas las de app: `SECURITY DEFINER` + `SET search_path TO ''` ✅ (buena práctica, sin riesgo de search_path hijacking) |
| Triggers | 7, todos `AFTER ... FOR EACH ROW`, todos `ENABLED` |
| Realtime | Publicación `supabase_realtime`: 9 tablas, `insert/update/delete/truncate = true` |
| Identidad | Todas las PK son `bigint GENERATED ALWAYS AS IDENTITY` (no `serial`) |
| ENUMs propios | Ninguno |
| Vistas / Comentarios | Ninguno / ninguno |
| UNIQUE adicionales | Ninguno |

### 10.2 Tablas reales y su uso

| Tabla | Columnas | Uso en la app | Estado |
|---|---|---|---|
| `perfiles` | `id uuid PK → auth.users`, `nombre text`, `rol text CHECK(cliente/veterinario/administrador) DEFAULT 'cliente'`, `created_at` | Router de rol, cabecera de usuario, nombre del veterinario | ✅ En uso |
| `mascotas` | `id`, `usuario_id`, `nombre`, `especie`, `raza`, `fecha_nacimiento`, `sexo`, `peso numeric(6,2)`, `observaciones`, `propietario`, `created_at` | Registro/listado cliente, panel vet, reportes | ✅ En uso |
| `reservas` | ver §8.1 | Reservas cliente/vet/admin | ✅ En uso |
| `historial_medico` | `id`, `usuario_id`, `mascota_id`, `veterinario_id`, `fecha date`, `tipo`, `descripcion`, `diagnostico`, `tratamiento`, `vacuna`, `observaciones`, `veterinario`, `created_at` | Registro y consulta de atenciones | ✅ En uso |
| `consultas` | ver §7.1 | Consultas cliente/admin | ✅ En uso |
| `notificaciones` | ver §9.1 | Bandeja + badges | ✅ En uso |
| `productos` | `id`, `nombre`, `descripcion`, `categoria`, `precio numeric(10,2) CHECK ≥ 0`, `stock int CHECK ≥ 0 DEFAULT 0`, `imagen_url`, `activo bool DEFAULT true`, `created_at` | Tienda cliente + CRUD admin | ✅ En uso |
| `servicios` | `id`, `nombre`, `descripcion`, `precio numeric(10,2) CHECK ≥ 0`, `duracion_minutos int`, `activo bool DEFAULT true`, `created_at` | Catálogo cliente + CRUD admin | ✅ En uso |
| `citas` | `id`, `usuario_id`, `mascota_id`, `servicio_id`, `fecha_hora timestamptz`, `motivo`, `estado text DEFAULT 'pendiente'`, `created_at` | **Ninguna** | ⚠️ **Esquema muerto** (modelo normalizado mejor que `reservas`, pero sin policies ⇒ inaccesible) |
| `vacunas` | `id`, `usuario_id`, `mascota_id`, `nombre_vacuna`, `fecha_aplicacion`, `proxima_fecha`, `observaciones`, `created_at` | **Ninguna** (la app usa `historial_medico.vacuna`) | ⚠️ **Esquema muerto** (pierde `proxima_fecha`) |

### 10.3 RPCs de la app (16/16 verificadas, contratos 100 % coincidentes)

| RPC | Argumentos | Retorno | Guard |
|---|---|---|---|
| `es_administrador()` | — | `boolean` | — |
| `listar_perfiles_admin()` | — | `TABLE(id, nombre, rol, created_at)` | `es_administrador()` |
| `listar_mascotas_admin()` | — | `TABLE(... , propietario, nombre_propietario)` | `es_administrador()` |
| `listar_reservas_admin()` | — | `TABLE(... , nombre_mascota, especie_mascota)` | `es_administrador()` |
| `listar_productos_admin()` | — | `TABLE(9 cols)` | `es_administrador()` |
| `listar_servicios_admin()` | — | `TABLE(8 cols)` | `es_administrador()` |
| `obtener_estadisticas_admin()` | — | `TABLE(total_mascotas, total_reservas, reservas_atendidas)` | `es_administrador()` |
| `obtener_reportes_admin()` | — | `jsonb` (5 claves) | `es_administrador()` |
| `crear_producto_admin(...)` | `p_nombre, p_descripcion, p_categoria, p_precio, p_stock, p_imagen_url` | `bigint` | `es_administrador()` + validaciones |
| `editar_producto_admin(...)` | `p_producto_id, ...` | `void` | `es_administrador()` + validaciones |
| `actualizar_stock_producto_admin(p_producto_id, p_stock)` | | `void` | `es_administrador()` + stock ≥ 0 |
| `cambiar_estado_producto_admin(p_producto_id, p_activo)` | | `void` | `es_administrador()` |
| `guardar_servicio_admin(p_servicio_id, p_nombre, p_descripcion, p_precio, p_duracion_minutos)` | | `bigint` | `es_administrador()` + validaciones |
| `cambiar_estado_servicio_admin(p_servicio_id, p_activo)` | | `void` | `es_administrador()` |
| `cambiar_estado_reserva_admin(p_reserva_id, p_estado)` | | `void` | `es_administrador()` + estado ∈ 4 valores |
| `cambiar_estado_consulta(p_consulta_id, p_estado)` | | `void` | `es_administrador()` + estado ∈ 2 valores |
| `cambiar_rol_usuario(p_usuario_id, p_nuevo_rol)` | | `void` | `es_administrador()` + **no puede quitarse el último admin** + **no puede cambiarse el propio rol** |

> `cambiar_rol_usuario` es notable en su diseño: previene el auto-degradación y el "último administrador huérfano". Buen detalle de robustez.

### 10.4 Tablas sin permisos suficientes (D1, D2)

| Tabla | `authenticated` tiene | `authenticated` necesita | Falta |
|---|---|---|---|
| `reservas` | `INSERT, SELECT` | `UPDATE` sobre `estado` | **UPDATE** |
| `notificaciones` | `SELECT` | `UPDATE` sobre `leida` | **UPDATE** |
| `consultas` | `INSERT, SELECT` | nada (el admin usa RPC) | — correcto |
| `mascotas` | `INSERT, SELECT, UPDATE` | nada más | — correcto |
| `historial_medico` | `INSERT, SELECT` | nada más | — correcto |
| `perfiles` | `SELECT` | nada (el admin usa RPC) | — correcto |
| `productos` / `servicios` | `SELECT` | nada (el admin usa RPC) | — correcto |

> La **asimetría es la prueba** de que se trata de un descuido: `productos`/`servicios`/`perfiles` deliberadamente no tienen `INSERT`/`UPDATE` porque todo pasa por RPC. Pero `reservas` y `notificaciones` **sí** tienen policies de UPDATE escritas y los flujos de la app dependen de ellas → el `REVOKE`/`GRANT` se hizo sin incluir esas dos.

---

## 11. Dependencias entre pantallas y tablas

| Pantalla | Tablas directas | RPC | Realtime |
|---|---|---|---|
| `main.dart` | `perfiles` (nombre, rol), `servicios` (probe) | — | — |
| `auth/login.dart` | Auth | — | — |
| `cliente/inicio.dart` | `mascotas`, `reservas`, `historial_medico`, `notificaciones` | — | 4 tablas, filtro `usuario_id` |
| `cliente/registro_mascotas.dart` | `mascotas` | — | `mascotas` |
| `cliente/servicios.dart` | `servicios`, `perfiles` | — | — |
| `cliente/reservas_citas.dart` | `mascotas`, `reservas` | — | `reservas`, `mascotas` |
| `cliente/control_vacunas.dart` | `mascotas`, `historial_medico` | — | `mascotas`, `historial_medico` |
| `cliente/historial.dart` | `mascotas`, `historial_medico` | — | `mascotas`, `historial_medico` |
| `cliente/tienda.dart` | `productos` | — | `productos` |
| `cliente/consultas.dart` | `consultas` | — | `consultas` |
| `cliente/contacto.dart` | — | — | — |
| `notificaciones/notificaciones.dart` | `notificaciones` | — | `notificaciones` |
| `veterinario/panel_veterinario.dart` | `mascotas`, `notificaciones` | — | `mascotas`, `notificaciones` |
| `veterinario/detalle_mascota_veterinario.dart` | `perfiles`, `historial_medico` | — | `historial_medico` (`mascota_id`) |
| `veterinario/citas_veterinario.dart` | `reservas`, `perfiles`, `historial_medico` | — | `reservas` (global) |
| `administrador/panel_administrador.dart` | `notificaciones`, `perfiles`, `mascotas`, `reservas` | `listar_perfiles_admin`, `obtener_estadisticas_admin`, `cambiar_rol_usuario` | `perfiles`, `mascotas`, `reservas`, `notificaciones` |
| `administrador/gestion_servicios.dart` | `servicios` | `listar_servicios_admin`, `guardar_servicio_admin`, `cambiar_estado_servicio_admin` | `servicios` |
| `administrador/gestion_productos.dart` | `productos` | `listar_productos_admin`, `crear_producto_admin`, `editar_producto_admin`, `actualizar_stock_producto_admin`, `cambiar_estado_producto_admin` | `productos` |
| `administrador/gestion_mascotas.dart` | — | `listar_mascotas_admin` | `mascotas` |
| `administrador/gestion_reservas_admin.dart` | — | `listar_reservas_admin`, `cambiar_estado_reserva_admin` | `reservas` |
| `administrador/gestion_consultas_admin.dart` | `consultas` | `cambiar_estado_consulta` | `consultas` (solo `insert`) |
| `administrador/reportes_admin.dart` | — | `obtener_reportes_admin` | `perfiles`, `mascotas`, `reservas`, `historial_medico` |

---

## 12. Problemas y errores encontrados

### 12.1 Críticos (bloquean funcionalidad en runtime)

| ID | Severidad | Hallazgo | Impacto | Referencia |
|---|---|---|---|---|
| **D1** | 🔴 Crítica | `GRANT UPDATE` ausente en `public.reservas` | **Roto:** cancelar reserva (cliente), confirmar/cancelar/atender cita (vet). En "atender", el historial queda registrado y la reserva sigue en `'Confirmada'` | grants §13b · `reservas_citas.dart:268-273` · `citas_veterinario.dart:134-137,360-364` |
| **D2** | 🔴 Crítica | `GRANT UPDATE` ausente en `public.notificaciones` | **Roto:** marcar leída / marcar todas para los 3 roles ⇒ el badge nunca se limpia | grants §13b · `notificaciones.dart:108-111,148-152` |
| **D3** | 🔴 Crítica | Policy de INSERT de `reservas` usa `(fecha + hora) > now()` con `hora` sin zona horaria | La validación "cita futura" se evalúa con **4 h de desfase** (UTC-4) | policy §8 · `reservas_citas.dart:486-489` |

### 12.2 Altos

| ID | Severidad | Hallazgo | Referencia |
|---|---|---|---|
| D4 | 🟠 Alta | `notificar_consulta_atendida` no valida `NEW.usuario_id IS NULL`, pero `consultas.usuario_id` es nullable y `notificaciones.usuario_id` es NOT NULL ⇒ un `UPDATE` de estado sobre una consulta sin dueño aborta por violación NOT NULL (el trigger `notificar_cambio_reserva` **sí** tiene la guarda) | trigger §11 · columnas §2 |
| D5 | 🟠 Alta | `reservas.estado` sin `CHECK`; la validación solo existe en la RPC de admin. La policy de UPDATE del cliente tampoco lo restringe (`WITH CHECK (estado = 'Cancelada')` solo) ⇒ si seotpga `GRANT UPDATE` sin endurecer la policy, un cliente podría auto-estar "Atendida" una reserva ya atendida | columnas §2 · policies §8 |
| D6 | 🟠 Alta | Esquema no versionado: **cero archivos `.sql`/migraciones** en el repo. Toda la lógica de negocio (16 RPCs, 7 triggers, 22 policies) vive únicamente en el dashboard de Supabase ⇒ sin historial, sin rollback, sin reproducibilidad en otro entorno | repositorio |
| D7 | 🟠 Alta | `EXECUTE` concedido a `PUBLIC` en `notificar_consulta_atendida` y `notificar_nueva_consulta_admin` (las otras 4 funciones trigger no lo tienen). Riesgo práctico bajo (una función `RETURNS trigger` no es invocable vía PostgREST) pero es higiene de privilegios inconsistente | grants §13c |
| D8 | 🟠 Alta | `consultas.estado` y `perfiles.rol` tienen `CHECK`, pero `reservas.estado`, `historial_medico.tipo`, `mascotas.especie` y `mascotas.sexo` **no** ⇒ valores arbitrarios desde el cliente (la app sí los valida en UI, pero la BD no) | checks §5 |

### 12.3 Medios

| ID | Severidad | Hallazgo | Referencia |
|---|---|---|---|
| D9 | 🟡 Media | El panel admin de consultas solo escucha `insert` en realtime ⇒ un cambio de estado desde otra sesión no se refleja sin refrescar | `gestion_consultas_admin.dart:143-153` |
| D10 | 🟡 Media | 3 tipos de notificación generados por triggers (`reserva_admin`, `reserva_veterinario`, `usuario_nuevo`) no tienen icono/color propio ⇒ todos caen en el estilo genérico | `notificaciones.dart:184-212` |
| D11 | 🟡 Media | Servicios del formulario de reserva hardcodeados, sin leer la tabla `servicios` ⇒ desalineación posible con el catálogo real | `reservas_citas.dart:73-80` |
| D12 | 🟡 Media | **Cero índices** de soporte en las columnas por las que la app filtra/ordena (`reservas(usuario_id, fecha)`, `consultas(usuario_id, created_at)`, `historial_medico(mascota_id, fecha)`, `mascotas(usuario_id)`) ⇒ seq scan + sort en las pantallas más usadas | índices §7 |
| D13 | 🟡 Media | `debugPrint` con datos de depuración en el envío de reservas | `reservas_citas.dart:472-477` |
| D14 | 🟡 Media | Tablas `citas` y `vacunas` sin policies RLS ⇒ accesibles solo por `service_role`; quedan como esquema muerto. `citas` además usa `'pendiente'` en minúscula frente a `'Pendiente'` | policies §8 · tablas §2 |
| D15 | 🟡 Media | `productos.precio numeric(10,2)` y `mascotas.peso numeric(6,2)` sin `CHECK` de rango superior; `precio` y `stock` sí lo tienen | columnas §2 |

### 12.4 Bajos / cosméticos

| ID | Severidad | Hallazgo | Referencia |
|---|---|---|---|
| D16 | ⚪ Baja | Modelos `cita.dart` y `mascota.dart` vacíos; `database_helper.dart` vacío; `lib/core/**` y `lib/widgets/` sin archivos ⇒ estructura_dirs suggests una arquitectura no implementada | `lib/` |
| D17 | ⚪ Baja | Uso intensivo de `Map<String, dynamic>` sin tipos ⇒ errores de campo en runtime en vez de compilación | todo `lib/features/` |
| D18 | ⚪ Baja | Pantalla de contacto con datos placeholder ("por confirmar") | `contacto.dart` |
| D19 | ⚪ Baja | `shared_preferences` declarado en `dev_dependencies` sin uso | `pubspec.yaml` |
| D20 | ⚪ Baja | `es_administrador()` es `SECURITY DEFINER` y consulta `perfiles` recursivamente por rol ⇒ se usa como predicado en policies; funciona, pero cada evaluación es un subplan sobre `perfiles` (sin índice por `rol`) | functions §10 |

---

## 13. Funcionalidades incompletas

| Módulo | Qué falta | Prioridad sugerida |
|---|---|---|
| Consultas | Respuesta in-app, asignación a veterinario, trazabilidad del responsable, hilo de conversación | Alta (es el requerimiento central del rol veterinario en la propuesta) |
| Reservas | Asignación de veterinario, validación de disponibilidad/solapamiento, reprogramación | Alta |
| Notificaciones | Generación visible en app (ya existe en BD, solo falta mapear los tipos), push (opcional) | Media |
| Tienda | Carrito/pedido (el modelo actual es catálogo) | Media |
| Historial | Edición de registros, adjuntos/fotografías | Baja |
| Perfil | Pantalla de perfil del usuario (los datos de `perfiles` solo se leen en la cabecera) | Media |

---

## 14. Funcionalidades pendientes

- Módulo de consultas médicas para veterinario (bandeja, respuesta, cierre con trazabilidad).
- Comunicación bidireccional cliente↔veterinario↔admin dentro de la app.
- Asignación y agenda de veterinarios para reservas.
- Auditoría operativa (quién atendidas/cambió el estado y cuándo) visible en la UI.
- Versionado del esquema SQL en el repositorio (carpeta `supabase/migrations/` + herramienta de despliegue).
- Pruebas automatizadas de contrato (que el JSON de cada RPC y cada column.exists coincidan con lo que Dart espera).
- Manejo de errores homogéneo y manejo de `AuthException` vs `PostgrestException` differentiate.

---

## 15. Propuesta de arquitectura

### 15.1 Evaluación de la distribución propuesta

| Rol | Responsabilidades propuestas | Estado verificado | Reutilizable | A desarrollar |
|---|---|---|---|---|
| **Administrador** | Supervisa el sistema; gestiona usuarios, servicios y productos; gestiona reservas; atiende consultas administrativas; **asigna consultas médicas a veterinarios** | ✅ Todo lo anterior existe y funciona (vía RPC). **La asignación a veterinarios NO existe** | 5 pantallas + 9 RPCs admin ya operative; triggers de notificación ya notifican a admins | Columna `asignado_a` + RPC de asignación + selector en `gestion_consultas_admin.dart` + bandeja en el panel del vet |
| **Veterinario** | Recibe consultas médicas asignadas; **responde directamente a los clientes**; atiende reservas asignadas; registra historiales; consulta mascotas | 🟡 Parcial:_historial ✅, consulta de mascotas ✅, **reservas sin filtro de asignación** y **sin consultas** | `detalle_mascota_veterinario.dart` (registro de atención, ya RLS-correcto), `citas_veterinario.dart` (lógica de atender) | Nueva pantalla `consultas_veterinario.dart`; `veterinario_id` en `reservas` + filtro; RPC `responder_consulta` |
| **Cliente** | Registra mascotas ✅; realiza reservas ✅; envía consultas ✅; **recibe respuestas** ❌; consulta estados ✅; recibe notificaciones ⚠️ (llega, pero no se puede marcar leída) | 🟡 Casi todo, salvo respuestas y el bug D2 | Flujos existentes completos | Vista de respuesta en `consultas.dart`; mapear tipos de notificación |

### 15.2 Decisión de diseño clave (recomendación)

Adoptar **asignación explícita por `veterinario_id`/`asignado_a`** en lugar del modelo actual "cualquier veterinario ve todo". Razón: el modelo actual escala mal (N veterinarios × N reservas = todos ven todo) y no permite cumplir la responsabilidad propuesta. Complemento: añadir un campo `estado` para consultas que distingue `Pendiente` / `Asignada` / `En_revision` / `Atendida` sin romper los valores actuales (mantener `Pendiente` y `Atendida` como subconjunto compatible).

---

## 16. Plan de mejoras por etapas

### Etapa 0 — Corrección inmediata de bloqueos (30 min, solo SQL)

Ejecutar el **Anexo A** (F1–F3). Sin esto, tres funciones están rotas en producción. **No requiere cambios en Dart.**

### Etapa 1 — Robustez de BD (1–2 h, solo SQL)

Anexo A (F4–F7): CHECK de estados, guarda NULL en el trigger, índices, `REVOKE EXECUTE` a PUBLIC.

### Etapa 2 — Higiene del proyecto (1 día)

Versionar el esquema: crear `supabase/migrations/0001_schema_inicial.sql` a partir de lo verificado, `0002_funciones_admin.sql`, `0003_triggers.sql`, `0004_policies.sql`, y documentar el flujo de despliegue.

### Etapa 3 — Consultas evolucionadas (3–5 días)

Anexo B: columnas nuevas + `consulta_mensajes` + RPC `responder_consulta` + policies para veterinario + bandeja en la app + respuesta en la UI del cliente.

### Etapa 4 — Reservas con asignación (2–3 días)

Columna `veterinario_id` en `reservas`, RPC de asignación, filtro "mis citas" en el panel del vet, validación de disponibilidad (índice único parcial o función de comprobación de solapamiento), y regla de transición en BD.

### Etapa 5 — Notificaciones pulidas (1 día)

Mapear los 3 tipos faltantes en la UI, añadir "tipos" documentados, y opcionalmente push (FCM) para cliente.

### Etapa 6 — Calidad (continuo)

Modelos Dart tipados para `Mascota`, `Reserva`, `Consulta`, `Notificacion`; un `SupabaseService` base con manejo de errores unificado; tests de contrato de las RPCs.

---

## 17. Archivos que sería necesario modificar

> Orientativo para la evolución; **nada de esto se ha ejecutado**.

**Solo BD (Anexo A, sin tocar Dart):** esquema `public` completo.

**Dart — Etapa 3 (consultas):**
- `lib/features/cliente/screens/consultas.dart` — mostrar respuesta/estado/responsable.
- `lib/features/administrador/screens/gestion_consultas_admin.dart` — selector de tipo, campo de respuesta, asignar veterinario, realtime `all` (D9).
- `lib/features/veterinario/screens/consultas_veterinario.dart` — **nuevo**.
- `lib/features/veterinario/screens/panel_veterinario.dart` — acceso a la nueva bandeja + badge.
- `lib/features/notificaciones/screens/notificaciones.dart` — mapear `reserva_admin`, `reserva_veterinario`, `usuario_nuevo` (D10).

**Dart — Etapa 4 (reservas):**
- `lib/features/cliente/screens/reservas_citas.dart` — servicios desde BD, zona horaria, mostrar veterinario asignado.
- `lib/features/veterinario/screens/citas_veterinario.dart` — filtro "mis citas", manejar `veterinario_id`.
- `lib/features/administrador/screens/gestion_reservas_admin.dart` — asignar veterinario.

**Dart — calidad (Etapa 6):**
- `lib/models/mascota.dart`, `lib/models/cita.dart` — implementar.
- `lib/models/` — nuevos: `reserva.dart`, `consulta.dart`, `notificacion.dart`, `perfil.dart`.
- `lib/services/` — `reserva_service.dart`, `consulta_service.dart`, `notificacion_service.dart`, `auth_service.dart` (centralizar la lógica Supabase duplicada).
- `lib/core/` — `core/theme/app_theme.dart` (hoy el tema está inline en `main.dart:100-104`), `core/widgets/` (badge de notificaciones reutilizable, estados vacío/cargando/error).
- `lib/database/database_helper.dart` — eliminar o implementar (placeholder muerto).

**Repositorio:**
- `supabase/migrations/*.sql` — **nuevo** (versionado del esquema).
- `test/` — tests de contrato de RPCs y de widgets por módulo.

---

## 18. Riesgos de los cambios

| Riesgo | Detalle | Mitigación |
|---|---|---|
| **Ruptura de contrato app↔BD** | Renombrar/eliminar columnas, cambiar firmas de RPC o valores de estado rompe flujos en producción | Todo cambio **aditivo**; nunca eliminar `Pendiente`/`Atendida`; versionar migraciones y probarlas en un proyecto Supabase de staging |
| **Sobre-permisos al conceder UPDATE** | Un `GRANT UPDATE` amplio abriría la puerta a que un cliente modifique `titulo`/`mensaje` de una notificación o `nombre`/`comentario` de una reserva | Usar **grants a nivel de columna**: `GRANT UPDATE (estado)` y `GRANT UPDATE (leida)` |
| **Auto-estado fraudulento** | Con `UPDATE` concedido, la policy de `reservas` permitiría al cliente fijar `estado='Cancelada'` sobre una reserva `'Atendida'` | Endurecer la policy: exigir `USING (estado = 'Pendiente')` y añadir `CHECK` de estados válidos |
| **Concurrencia** | Transiciones de estado y atención de citas requieren atomicidad | Mover las transiciones sensibles a RPC `SECURITY DEFINER` (una sola statement + validaciones) en lugar de `UPDATE` directo |
| **Inconsistencia historial↔reserva** | Ya ocurre hoy (D1): el historial se commitea y el update de la reserva falla | Envolver "registrar atención + marcar atendida" en **una sola RPC transaccional** |
| **Realtime / costo / carga** | La publicación cubre 9 tablas y el código suscribe a 20+ canales; con muchos usuarios, el volumen de eventos crece | Filtrar siempre por `usuario_id`; evaluar `REPLICA IDENTITY`;XAEvitar suscripciones globales innecesarias |
| **Fallo del trigger rompe la operación** | Un trigger que viola una constraint aborta la transacción de negocio (D4) | Guardas `IS NULL` en todos los triggers; `NOT NULL` en `consultas.usuario_id` |
| **Zona horaria** | `hora` sin TZ + `now()` en UTC ⇒ validaciones y cálculos de agenda incorrectos | Enviar `timestamptz` o comparar con `now() AT TIME ZONE 'America/La_Paz'`; documentar la zona del negocio |
| **Regresión de UX** | Cambios en navegación por rol o en estados visibles pueden afectar datos históricos | Mantener las pantallas actuales y añadir vistas nuevas, sin reemplazar |
| **Esquema no versionado** | Cambios manuales en el dashboard no son auditables ⇒ rollback imposible | Adoptar migraciones en el repo antes de tocar el esquema de forma estructural |

---

## 19. Verificación contra Supabase: estado de comprobación

### 19.1 Verificado (V) — ya no requiere acción

| Ítem | Resultado |
|---|---|
| Existencia y definición de las 8 tablas usadas | ✅ Confirmadas con columnas, tipos y nullabilidad exactos |
| Las 2 tablas no usadas (`citas`, `vacunas`) | ✅ Confirmadas; esquema muerto |
| PK/FK y reglas de borrado | ✅ `usuario_id → auth.users` con `CASCADE` en `mascotas`/`historial_medico`/`notificaciones` y `NO ACTION` en `consultas`/`reservas`; `mascota_id → mascotas` con `CASCADE` en `historial_medico`/`citas`/`vacunas` y `SET NULL` en `reservas` |
| CHECK constraints | ✅ 6 checks (consultas.estado, perfiles.rol, productos.precio, productos.stock, reservas.personas, servicios.precio) |
| Defaults | ✅ Confirmados (incl. `consultas.estado='Pendiente'`, `reservas.estado='Pendiente'`, `perfiles.rol='cliente'`) |
| Índices | ✅ Solo PKs + `idx_notificaciones_usuario_fecha` |
| Políticas RLS | ✅ 22 policies, 9 tablas; `citas`/`vacunas` sin policies |
| Estado RLS | ✅ Habilitado en las 10 tablas, `FORCE` desactivado |
| Funciones y definiciones SQL | ✅ 24 funciones, 17 RPCs de app con contrato exacto |
| Triggers | ✅ 7 triggers activos con su función |
| Publicación Realtime | ✅ `supabase_realtime` con las 9 tablas de la app |
| Roles y grants | ✅ `authenticated`/`anon`/`service_role`/`postgres` — y **aquí se detectaron D1 y D2** |
| ENUMs propios | ✅ Ninguno |
| Vistas / comentarios / UNIQUE extra | ✅ Ninguno |

### 19.2 Pendiente de verificación manual

| Ítem | Cómo verificarlo | Por qué importa |
|---|---|---|
| Trigger `crear_perfil_usuario()` sobre `auth.users` | `SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgrelid = 'auth.users'::regclass AND NOT tgisinternal;` | La §11 filtró `event_object_schema = 'public'`, por eso no apareció. Sin él, ningún usuario nuevo tendría perfil y el router por rol fallaría |
| `ALTER DEFAULT PRIVILEGES` del esquema `public` | `SELECT pg_get_userbyid(defaclrole), defaclobjtype, defaclacl FROM pg_default_acl WHERE defaclnamespace = 'public'::regnamespace;` | Si asigna `ALL` a `authenticated`, **las tablas nuevas nacerían con UPDATE** → el error D1/D2 se repetiría en cada tabla nueva |
| Configuración de Auth | Dashboard → Authentication → Providers / URL Configuration / Email | Los `emailRedirectTo`/`redirectTo` de la app usan `petcare://confirm-email` y `petcare://reset-password`; deben coincidir con las URLs permitidas y con los deep links de Android/iOS |
| Confirmación de email obligatoria | Dashboard → Authentication → Email → "Confirm email" | Si está activa, `signUp` no crea sesión hasta confirmar; la app no maneja ese estado (navega a `/app` de inmediato) |
| Volumen de datos por tabla y usuarios por rol | `SELECT relname, n_live_tup FROM pg_stat_user_tables WHERE schemaname='public' ORDER BY n_live_tup DESC;` y `SELECT rol, count(*) FROM perfiles GROUP BY rol;` | Dimensiona índices, volumen de notificaciones (fan-out a todos los admins/vets) y riesgo de la política "último admin" |
| Comportamiento real de la app bajo D1/D2 | Reproducir en la app: marcar una notificación como leída / cancelar una reserva | Confirmación empírica de los dos bloqueos antes de aplicar el Anexo A |

---

## 20. Anexo A — SQL de corrección propuesto (**NO EJECUTADO**)

> ⚠️ **Este SQL no se ha ejecutado.** Se entrega para que lo revises y lo apliques manualmente en Supabase SQL Editor.
> **Orden recomendado:** F1 → F2 → F3 → F4 → F5 → F6 → F7, ejecutando los bloques por separado y comprobando el resultado de cada uno.
> **Respaldo:** antes de ejecutar, exporta el esquema actual desde Dashboard → Database → Database schema dump.

### F1 — Desbloquear los UPDATE que la app ya intenta hacer (prioridad máxima)

```sql
-- F1.1 Reservas: la app solo necesita cambiar 'estado'.
-- Grant a nivel de COLUMNA para que el cliente/vet no pueda alterar nombre, telefono, fecha, etc.
GRANT UPDATE (estado) ON public.reservas TO authenticated;

-- F1.2 Notificaciones: la app solo necesita cambiar 'leida'.
GRANT UPDATE (leida) ON public.notificaciones TO authenticated;
```

> Tras aplicar F1, **endurecer la policy** del cliente para que solo pueda cancelar reservas pendientes:

```sql
-- F1.3 Policy de cancelación: solo desde 'Pendiente' y siempre hacia 'Cancelada'.
DROP POLICY IF EXISTS "Usuarios pueden cancelar sus reservas" ON public.reservas;

CREATE POLICY "Usuarios pueden cancelar sus reservas"
  ON public.reservas
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = usuario_id AND estado = 'Pendiente')
  WITH CHECK (auth.uid() = usuario_id AND estado = 'Cancelada');
```

### F2 — Restringir los estados válidos en la BD

```sql
-- F2.1 CHECK de estados en reservas (la RPC admin ya valida; la BD debe validar también).
ALTER TABLE public.reservas
  DROP CONSTRAINT IF EXISTS reservas_estado_check;

ALTER TABLE public.reservas
  ADD CONSTRAINT reservas_estado_check
  CHECK (estado IN ('Pendiente', 'Confirmada', 'Atendida', 'Cancelada'));

-- F2.2 CHECK del tipo de atención (valores que la app ya usa en el dropdown).
ALTER TABLE public.historial_medico
  DROP CONSTRAINT IF EXISTS historial_medico_tipo_check;

ALTER TABLE public.historial_medico
  ADD CONSTRAINT historial_medico_tipo_check
  CHECK (tipo IS NULL OR tipo IN ('Consulta', 'Vacunación', 'Control', 'Emergencia', 'Otro'));

-- F2.3 CHECK de especie y sexo (valores que la app ya restringe en la UI).
ALTER TABLE public.mascotas
  DROP CONSTRAINT IF EXISTS mascotas_especie_check,
  DROP CONSTRAINT IF EXISTS mascotas_sexo_check;

ALTER TABLE public.mascotas
  ADD CONSTRAINT mascotas_especie_check CHECK (especie IN ('Perro', 'Gato', 'Otro')),
  ADD CONSTRAINT mascotas_sexo_check    CHECK (sexo IS NULL OR sexo IN ('Macho', 'Hembra'));
```

### F3 — Corregir la zona horaria de la validación de citas (D3)

```sql
-- F3.1 Policy de INSERT de reservas: comparar contra la hora local del negocio.
DROP POLICY IF EXISTS "Usuarios pueden crear sus reservas" ON public.reservas;

CREATE POLICY "Usuarios pueden crear sus reservas"
  ON public.reservas
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = usuario_id
    AND length(trim(BOTH FROM nombre)) > 0
    AND telefono ~ '^[0-9]{8}$'
    AND personas BETWEEN 1 AND 50
    AND (fecha + hora) > (now() AT TIME ZONE 'America/La_Paz')::timestamp
  );

-- F3.2 Alternativa más robusta (recomendada a medio plazo): mover la comparación
-- a una columna timestamptz para eliminar la ambigüedad.
-- ALTER TABLE public.reservas ADD COLUMN fecha_hora timestamptz;
-- UPDATE public.reservas
--    SET fecha_hora = (fecha + hora) AT TIME ZONE 'America/La_Paz';
-- ALTER TABLE public.reservas ALTER COLUMN fecha_hora SET NOT NULL;
```

### F4 — Evitar que un trigger rompa la operación de negocio (D4)

```sql
-- F4.1 Reemplazar la función del trigger de "consulta atendida" con guarda NULL.
CREATE OR REPLACE FUNCTION public.notificar_consulta_atendida()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF NEW.usuario_id IS NULL THEN
        RETURN NEW;
    END IF;

    IF OLD.estado = 'Pendiente' AND NEW.estado = 'Atendida' THEN
        INSERT INTO public.notificaciones (usuario_id, titulo, mensaje, tipo)
        VALUES (
            NEW.usuario_id,
            'Consulta atendida',
            'Tu consulta ha sido atendida. Ingresa a PetCare para revisar su estado.',
            'consulta_atendida'
        );
    END IF;

    RETURN NEW;
END;
$function$;

-- F4.2 Reforzar la obligatoriedad del dueño de la consulta (tras verificar que no
-- hay filas huérfanas: SELECT count(*) FROM public.consultas WHERE usuario_id IS NULL).
-- ALTER TABLE public.consultas ALTER COLUMN usuario_id SET NOT NULL;
```

### F5 — Índices de soporte para las consultas que la app realmente ejecuta

```sql
CREATE INDEX IF NOT EXISTS idx_reservas_usuario_fecha   ON public.reservas (usuario_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_reservas_fecha            ON public.reservas (fecha DESC, hora DESC);
CREATE INDEX IF NOT EXISTS idx_consultas_usuario_created ON public.consultas (usuario_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_consultas_created         ON public.consultas (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_historial_mascota_fecha   ON public.historial_medico (mascota_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_historial_usuario         ON public.historial_medico (usuario_id);
CREATE INDEX IF NOT EXISTS idx_mascotas_usuario          ON public.mascotas (usuario_id);
CREATE INDEX IF NOT EXISTS idx_productos_activo_nombre   ON public.productos (activo, nombre);
CREATE INDEX IF NOT EXISTS idx_servicios_activo          ON public.servicios (activo);
```

### F6 — Higiene de privilegios (D7)

```sql
REVOKE EXECUTE ON FUNCTION public.notificar_consulta_atendida()      FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notificar_nueva_consulta_admin()   FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notificar_cambio_reserva()         FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notificar_nueva_reserva_admin()    FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notificar_nueva_reserva_veterinario() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notificar_nuevo_historial()        FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notificar_nuevo_usuario_admin()    FROM PUBLIC;
```

### F7 — Transacción atómica para "atender cita" (evita la inconsistencia de D1)

```sql
-- F7. Registrar la atención Y marcar la reserva como atendida en una sola transacción.
CREATE OR REPLACE FUNCTION public.atender_cita(
  p_reserva_id    bigint,
  p_tipo          text,
  p_descripcion   text,
  p_diagnostico   text,
  p_tratamiento   text,
  p_vacuna        text,
  p_observaciones text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_mascota_id bigint;
  v_usuario_id uuid;
  v_fecha      date := (now() AT TIME ZONE 'America/La_Paz')::date;
  v_nombre     text;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE id = auth.uid() AND rol = 'veterinario'
    ) THEN
        RAISE EXCEPTION 'Solo un veterinario puede atender citas';
    END IF;

    SELECT r.mascota_id, r.usuario_id
      INTO v_mascota_id, v_usuario_id
      FROM public.reservas r
     WHERE r.id = p_reserva_id
       AND r.estado = 'Confirmada';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe o no está en estado Confirmada';
    END IF;

    SELECT nombre INTO v_nombre FROM public.perfiles WHERE id = auth.uid();

    INSERT INTO public.historial_medico (
        usuario_id, mascota_id, veterinario_id, fecha, tipo,
        descripcion, diagnostico, tratamiento, vacuna, observaciones, veterinario
    )
    VALUES (
        v_usuario_id, v_mascota_id, auth.uid(), v_fecha, p_tipo,
        p_descripcion, p_diagnostico, p_tratamiento, p_vacuna, p_observaciones, v_nombre
    );

    UPDATE public.reservas SET estado = 'Atendida' WHERE id = p_reserva_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.atender_cita(bigint, text, text, text, text, text, text) TO authenticated;
```

> Con F7, el flujo del veterinario debe invocar `rpc('atender_cita', ...)` en lugar de los dos `INSERT`/`UPDATE` separados (`citas_veterinario.dart:337` y `:360`), quedando atómico y sin depender de `GRANT UPDATE` para el `estado`.

---

## 21. Anexo B — SQL propuesto para el sistema de consultas evolucionado (Etapa 3)

> **NO EJECUTADO.** Requiere cambios adicionales en la app (ver §17).
```sql
-- B.1 Columnas nuevas (aditivas, nullable → no rompen datos existentes).
ALTER TABLE public.consultas
  ADD COLUMN IF NOT EXISTS tipo           text,
  ADD COLUMN IF NOT EXISTS asignado_a     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS respuesta      text,
  ADD COLUMN IF NOT EXISTS respondida_por uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS respondida_en  timestamptz,
  ADD COLUMN IF NOT EXISTS mascota_id     bigint REFERENCES public.mascotas(id) ON DELETE SET NULL;

-- B.2 CHECK de los tipos de consulta y de los estados (sin tocar 'Pendiente'/'Atendida').
ALTER TABLE public.consultas
  DROP CONSTRAINT IF EXISTS consultas_estado_check;

ALTER TABLE public.consultas
  ADD CONSTRAINT consultas_estado_check
  CHECK (estado IN ('Pendiente', 'Asignada', 'En_revision', 'Atendida'));

ALTER TABLE public.consultas
  ADD CONSTRAINT consultas_tipo_check
  CHECK (tipo IS NULL OR tipo IN ('Administrativa', 'Médica'));

-- B.3 Hilo de mensajes.
CREATE TABLE IF NOT EXISTS public.consulta_mensajes (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  consulta_id  bigint NOT NULL REFERENCES public.consultas(id) ON DELETE CASCADE,
  emisor_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  texto        text NOT NULL CHECK (length(trim(BOTH FROM texto)) > 0),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_consulta_mensajes_consulta
  ON public.consulta_mensajes (consulta_id, created_at);

ALTER TABLE public.consulta_mensajes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participantes leen el hilo de la consulta"
  ON public.consulta_mensajes FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.consultas c
      WHERE c.id = consulta_id
        AND (c.usuario_id = auth.uid() OR c.asignado_a = auth.uid() OR public.es_administrador())
    )
  );

CREATE POLICY "Participantes escriben en el hilo"
  ON public.consulta_mensajes FOR INSERT TO authenticated
  WITH CHECK (
    emisor_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.consultas c
      WHERE c.id = consulta_id
        AND (c.usuario_id = auth.uid() OR c.asignado_a = auth.uid() OR public.es_administrador())
    )
  );

-- B.4 RPC para responder (escribe respuesta, cambia estado y notifica con el texto).
CREATE OR REPLACE FUNCTION public.responder_consulta(
  p_consulta_id bigint,
  p_respuesta  text,
  p_estado     text DEFAULT 'Atendida'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_consulta public.consultas%ROWTYPE;
  v_titulo   text;
BEGIN
    SELECT * INTO v_consulta FROM public.consultas WHERE id = p_consulta_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La consulta no existe';
    END IF;

    IF NOT (
        public.es_administrador()
        OR (v_consulta.asignado_a = auth.uid() AND EXISTS (
              SELECT 1 FROM public.perfiles WHERE id = auth.uid() AND rol = 'veterinario'))
    ) THEN
        RAISE EXCEPTION 'No tienes permisos para responder esta consulta';
    END IF;

    IF p_respuesta IS NULL OR length(trim(BOTH FROM p_respuesta)) < 10 THEN
        RAISE EXCEPTION 'La respuesta debe tener al menos 10 caracteres';
    END IF;

    UPDATE public.consultas
       SET respuesta      = p_respuesta,
           respondida_por = auth.uid(),
           respondida_en  = now(),
           estado         = p_estado
     WHERE id = p_consulta_id;

    INSERT INTO public.consulta_mensajes (consulta_id, emisor_id, texto)
    VALUES (p_consulta_id, auth.uid(), p_respuesta);

    IF v_consulta.usuario_id IS NOT NULL THEN
        v_titulo := CASE p_estado WHEN 'Atendida' THEN 'Consulta respondida' ELSE 'Consulta actualizada' END;
        INSERT INTO public.notificaciones (usuario_id, titulo, mensaje, tipo)
        VALUES (
            v_consulta.usuario_id,
            v_titulo,
            LEFT(p_respuesta, 160),
            'consulta_atendida'
        );
    END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.responder_consulta(bigint, text, text) TO authenticated;

-- B.5 Policy: el veterinario asignado puede leer y actualizar su consulta.
CREATE POLICY "Veterinarios ven consultas asignadas"
  ON public.consultas FOR SELECT TO authenticated
  USING (asignado_a = auth.uid());

CREATE POLICY "Veterinarios atienden consultas asignadas"
  ON public.consultas FOR UPDATE TO authenticated
  USING (asignado_a = auth.uid())
  WITH CHECK (asignado_a = auth.uid());

-- B.6 RPC para asignar la consulta a un veterinario (desde el panel admin).
CREATE OR REPLACE FUNCTION public.asignar_consulta(p_consulta_id bigint, p_veterinario_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
    IF NOT public.es_administrador() THEN
        RAISE EXCEPTION 'No tienes permisos para asignar consultas';
    END IF;

    IF p_veterinario_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.perfiles WHERE id = p_veterinario_id AND rol = 'veterinario'
    ) THEN
        RAISE EXCEPTION 'El usuario indicado no es un veterinario';
    END IF;

    UPDATE public.consultas
       SET asignado_a = p_veterinario_id,
           estado = CASE WHEN p_veterinario_id IS NULL THEN 'Pendiente' ELSE 'Asignada' END
     WHERE id = p_consulta_id;

    IF p_veterinario_id IS NOT NULL THEN
        INSERT INTO public.notificaciones (usuario_id, titulo, mensaje, tipo)
        VALUES (
            p_veterinario_id,
            'Consulta asignada',
            'Se te ha asignado una consulta que requiere atención médica.',
            'consulta_asignada'
        );
    END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.asignar_consulta(bigint, uuid) TO authenticated;

-- B.7 Publicar las tablas nuevas en Realtime.
ALTER PUBLICATION supabase_realtime ADD TABLE public.consulta_mensajes;
```

---

## 22. Contradicciones detectadas entre documentación, código y base de datos

| # | Contradicción | Detalle |
|---|---|---|
| 1 | **Docs ↔ BD** | `doc/06_base_de_datos.md` describe la tabla `citas`; la BD la tiene, pero **la app nunca la usa** (usa `reservas`) y **no tiene policies RLS** ⇒ es inaccesible |
| 2 | **Docs ↔ BD** | La documentación contempla la tabla `vacunas` con `proxima_fecha`; la app **no la usa** (lee `historial_medico.vacuna`), por lo que el control de "próxima fecha de vacuna" no está disponible |
| 3 | **Código ↔ BD** | `lib/models/cita.dart` y `lib/models/mascota.dart` están vacíos pese a que `citas` y `mascotas` existen en BD ⇒ el modelo de dominio nunca se implementó y la app trabaja con `Map<String, dynamic>` |
| 4 | **Código ↔ BD** | La app documenta/maneja los tipos `consulta_admin` y `consulta_atendida`, pero **no conoce** `reserva_admin`, `reserva_veterinario` ni `usuario_nuevo`, que los triggers sí generan |
| 5 | **Docs ↔ Código** | La documentación describe "notificaciones al veterinario ante nuevas reservas" ⇒ **existe** el trigger, pero la UI del veterinario no distingue ese tipo |
| 6 | **Código ↔ BD** | El formulario de reserva ofrece 6 servicios hardcodeados; la tabla `servicios` (administrable vía RPC) puede tener otros ⇒ divergencia silenciosa |
| 7 | **Código ↔ BD** | `citas.estado` usa `'pendiente'` (minúscula) y `reservas.estado` usa `'Pendiente'` ⇒ dos convenciones de estado en el mismo esquema |
| 8 | **Código ↔ BD** | `reservas` guarda `servicio` como texto, mientras `citas` (no usada) tiene `servicio_id` normalizado ⇒ el modelo mejor diseñado es el que está desconectado |
| 9 | **BD ↔ diseño** | Existen policies de UPDATE en `reservas` y `notificaciones` **sin `GRANT UPDATE`** ⇒ policies inertes (D1/D2). Esta es la contradicción más grave: el diseño de seguridad declara una intención que los privilegios no permiten |

---

## 23. Resumen ejecutivo para dirección

1. **El proyecto está bien estructurado en código** (arquitectura feature-first, 20 pantallas funcionales, 16 RPCs seguras, triggers de notificación, RLS por rol, Realtime bien usado). No requiere reescritura.
2. **La base de datos está por delante del código**, no al revés: hay 24 funciones, 7 triggers, 22 policies y 3 índices que la app solo aprovecha parcialmente.
3. **Hay 3 bloqueos reales en producción** (D1, D2, D3) que no se detectan leyendo el código Dart, solo contrastando con `GRANT`s y policies. Se corrigen con ~10 líneas de SQL, sin tocar Flutter.
4. **El requerimiento de "consultas médicas asignadas a veterinarios con respuesta al cliente" no está implementado** y es la brecha funcional más grande respecto a la arquitectura propuesta.
5. **El mayor riesgo de gestión** es que el esquema no está versionado: todo el trabajo de BD vive en el dashboard y no se puede auditar ni revertir.
6. **Orden recomendado**: Anexo A (F1–F3, hoy mismo) → reproducir en la app para confirmar → Etapa 1 (Anexo A F4–F7) → versionar migraciones → Etapas 3–4 (consultas y reservas con asignación).

---

*Auditoría generada el 2026-11-16 · Esquema verificado contra Supabase el 2026-11-16 · Ninguna operación de escritura ejecutada sobre la base de datos.*
