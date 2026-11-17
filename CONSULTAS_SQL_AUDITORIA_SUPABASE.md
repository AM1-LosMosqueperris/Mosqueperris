# Consultas SQL de auditoría para Supabase (solo lectura)

> **Propósito:** obtener metadatos y configuración relevantes del proyecto Supabase/PostgreSQL para contrastar con lo observado en el código de PetCare Santa Cruz.
> **Tipo:** consultas **SOLO LECTURA** (`SELECT` sobre catálogos/vistas del sistema e `information_schema`).
> **No incluye:** `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `TRUNCATE`, `GRANT/REVOKE`, creación de objetos ni ejecución de funciones que modifiquen datos.
> **Seguridad:** no expone contraseñas, tokens, claves privadas ni secretos de la app. Aun así, algunas salidas pueden incluir **definiciones de funciones/RPC, políticas RLS, estructura de tablas o configuración de roles/permisos** que pueden considerarse sensibles en ciertos contextos; revísalas antes de compartirlas.
> **Permisos:** en Supabase SQL Editor normalmente se ejecutan con privilegios elevados; si usas otro rol, algunas vistas/consultas pueden devolver resultados parciales o requerir permisos adicionales (se indica cuando aplica).
> **Esquema:** la mayoría de consultas filtran por `public` (y referencias a tablas de la app) porque es el foco del proyecto; incluyen también catálogos globales útiles (extensiones, publicaciones, roles, ENUMs).

---

## 0. Resumen de resultados verificados (ejecutado)

> **Estado:** consultas ejecutadas en Supabase SQL Editor. Los resultados están embebidos debajo de cada consulta.
> **Fecha de ejecución:** 2026-11-16
> **Alcance verificado:** esquema `public` completo, RLS, funciones, triggers, Realtime, roles y permisos.
> **Contraste:** el análisis derivado está en `AUDITORIA_TECNICA_PETCARE.md` (secciones 20–23).

### 0.1 Confirmado

| Elemento | Resultado verificado |
|---|---|
| Tablas en `public` | 10: `citas`, `consultas`, `historial_medico`, `mascotas`, `notificaciones`, `perfiles`, `productos`, `reservas`, `servicios`, `vacunas` |
| RLS habilitado | Las 10 tablas con `relrowsecurity = true` (ninguna con `relforcerowsecurity`) |
| Políticas RLS | 22 policies en 9 tablas. `citas` y `vacunas` **sin ninguna policy** → inaccesibles |
| Funciones `public` | 24 (17 RPCs de app + `es_administrador` + 6 funciones trigger) |
| Triggers | 7, todos `AFTER ... FOR EACH ROW`, todos habilitados |
| Realtime | Publicación `supabase_realtime` con las 9 tablas de la app (insert/update/delete/truncate) |
| ENUMs propios | Ninguno. Todos los estados son `text` + `CHECK` |
| Vistas | Ninguna |
| UNIQUE extra | Ninguno (solo PKs) |
| Extensiones | `pgcrypto`, `uuid-ossp`, `supabase_vault`, `pg_stat_statements` |

### 0.2 Hallazgos críticos derivados de los resultados

1. **Falta `GRANT UPDATE` en `reservas`** → el rol `authenticated` solo tiene `INSERT, SELECT`. Esto **bloquea** el cancelar reserva (cliente), el confirmar/cancelar y el "atender" cita (veterinario). Las políticas RLS de UPDATE **sí existen** (escritas y luego olvidadas al revocar privilegios).
2. **Falta `GRANT UPDATE` en `notificaciones`** → solo `SELECT`. **Bloquea** "marcar como leída" y "marcar todas como leídas" en los tres roles. La política RLS de UPDATE también existe.
3. **Zona horaria** en la policy de INSERT de `reservas`: `(fecha + hora) > now()` interpreta la hora local como **UTC** (Supabase). La app envía hora local naive (`reservas_citas.dart:486-489`) → desfase de 4 h en Santa Cruz (UTC-4).
4. **`reservas.estado` no tiene CHECK** (a diferencia de `consultas.estado` y `perfiles.rol`). La validación vive solo en la RPC admin.
5. **`notificar_consulta_atendida` no valida `NEW.usuario_id IS NULL`** (sí lo hace `notificar_cambio_reserva`), pero `consultas.usuario_id` es nullable y `notificaciones.usuario_id` es NOT NULL → un `UPDATE` de estado podría abortar por violación de NOT NULL.
6. **Tipos de notificación no mapeados en la UI**: los triggers generan `reserva_admin`, `reserva_veterinario` y `usuario_nuevo`, pero `notificaciones.dart:184-212` solo reconoce `reserva`, `historial_medico`, `consulta_admin`, `consulta_atendida`.
7. **`citas` y `vacunas` son esquema muerto**: existen, tienen RLS activo pero **sin policies** (⇒ 0 filas para `authenticated`) y la app no las usa. `citas.estado` además usa minúsculas (`'pendiente'`) frente a `'Pendiente'` en `reservas`.
8. **Índices faltantes** en las columnas por las que la app filtra/ordena (`reservas.usuario_id/fecha`, `consultas.usuario_id/created_at`, `historial_medico.mascota_id/fecha`, `mascotas.usuario_id`).
9. **`EXECUTE` sobre `PUBLIC` en `notificar_consulta_atendida` y `notificar_nueva_consulta_admin`**, inconsistente con las demás funciones trigger.

### 0.3 Checklist de ejecución actualizado

| # | Sección | Estado |
|---|---|---|
| 1 | Tablas de `public` | ✅ Ejecutada |
| 2 | Columnas y tipos | ✅ Ejecutada |
| 3 | PK y FK | ✅ Ejecutada |
| 4 | Relaciones | ✅ Ejecutada |
| 5 | CHECK | ✅ Ejecutada |
| 6 | Defaults | ✅ Ejecutada |
| 7 | Índices | ✅ Ejecutada |
| 8 | Políticas RLS | ✅ Ejecutada |
| 9 | Estado RLS | ✅ Ejecutada |
| 10 | Funciones | ✅ Ejecutada |
| 10b | RPCs de la app | ✅ Ejecutada (16/16 presentes) |
| 11 | Triggers | ✅ Ejecutada |
| 12 | Publicaciones Realtime | ✅ Ejecutada |
| 13 | Roles y permisos | ✅ Ejecutada |
| 14 | ENUMs | ✅ Ejecutada (ninguno propio) |
| 15 | Otras estructuras | ✅ Ejecutada |

> **Pendiente de verificación manual (fuera del alcance de estas consultas):**
> - Trigger `crear_perfil_usuario()` sobre `auth.users` (la §11 filtró por `event_object_schema = 'public'`, por eso no aparece).
> - Configuración de Auth en el Dashboard (proveedores, URLs de redirección `petcare://...`, confirmación de email).
> - Default privileges del esquema `public` (`ALTER DEFAULT PRIVILEGES`), que puede re-asignar `ALL` a `anon`/`authenticated` en tablas nuevas.
> - Volumen real de datos y de usuarios por rol (para dimensionar índices y revisar rendimiento).

---

## 1. Tablas del esquema `public`

**Qué devuelve:** listado de tablas base en `public` con tipo y propietario (útil para confirmar qué tablas existen realmente).

```sql
-- 1. Todas las tablas del esquema public
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relkind AS object_kind, -- r = tabla ordinaria, p = particionada
  pg_get_userbyid(c.relowner) AS owner,
  obj_description(c.oid, 'pg_class') AS table_comment
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p')
ORDER BY c.relname;
```
| schema_name | table_name       | object_kind | owner    | table_comment |
| ----------- | ---------------- | ----------- | -------- | ------------- |
| public      | citas            | r           | postgres | null          |
| public      | consultas        | r           | postgres | null          |
| public      | historial_medico | r           | postgres | null          |
| public      | mascotas         | r           | postgres | null          |
| public      | notificaciones   | r           | postgres | null          |
| public      | perfiles         | r           | postgres | null          |
| public      | productos        | r           | postgres | null          |
| public      | reservas         | r           | postgres | null          |
| public      | servicios        | r           | postgres | null          |
| public      | vacunas          | r           | postgres | null          |
---

## 2. Columnas y tipos de datos

**Qué devuelve:** todas las columnas de tablas en `public`, tipo, nulabilidad, default, identidad, collation y comentarios (para comparar con los campos inferidos en el código).

```sql
-- 2. Todas las columnas y sus tipos de datos (esquema public)
SELECT
  c.table_schema,
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.udt_name,
  c.character_maximum_length,
  c.numeric_precision,
  c.numeric_scale,
  c.is_nullable,
  c.column_default,
  c.is_identity,
  c.identity_generation,
  c.collation_name
FROM information_schema.columns c
WHERE c.table_schema = 'public'
ORDER BY c.table_name, c.ordinal_position;
```
| table_schema | table_name       | ordinal_position | column_name      | data_type                | udt_name    | character_maximum_length | numeric_precision | numeric_scale | is_nullable | column_default    | is_identity | identity_generation | collation_name |
| ------------ | ---------------- | ---------------- | ---------------- | ------------------------ | ----------- | ------------------------ | ----------------- | ------------- | ----------- | ----------------- | ----------- | ------------------- | -------------- |
| public       | citas            | 1                | id               | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | YES         | ALWAYS              | null           |
| public       | citas            | 2                | usuario_id       | uuid                     | uuid        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | citas            | 3                | mascota_id       | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | NO          | null                | null           |
| public       | citas            | 4                | servicio_id      | bigint                   | int8        | null                     | 64                | 0             | YES         | null              | NO          | null                | null           |
| public       | citas            | 5                | fecha_hora       | timestamp with time zone | timestamptz | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | citas            | 6                | motivo           | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | citas            | 7                | estado           | text                     | text        | null                     | null              | null          | YES         | 'pendiente'::text | NO          | null                | null           |
| public       | citas            | 8                | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | YES         | now()             | NO          | null                | null           |
| public       | consultas        | 1                | id               | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | YES         | ALWAYS              | null           |
| public       | consultas        | 2                | nombre           | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | consultas        | 3                | telefono         | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | consultas        | 4                | mensaje          | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | consultas        | 5                | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | YES         | now()             | NO          | null                | null           |
| public       | consultas        | 6                | usuario_id       | uuid                     | uuid        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | consultas        | 7                | estado           | text                     | text        | null                     | null              | null          | NO          | 'Pendiente'::text | NO          | null                | null           |
| public       | historial_medico | 1                | id               | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | YES         | ALWAYS              | null           |
| public       | historial_medico | 2                | usuario_id       | uuid                     | uuid        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | historial_medico | 3                | mascota_id       | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | NO          | null                | null           |
| public       | historial_medico | 4                | fecha            | date                     | date        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | historial_medico | 5                | tipo             | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | historial_medico | 6                | descripcion      | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | historial_medico | 7                | veterinario      | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | historial_medico | 8                | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | YES         | now()             | NO          | null                | null           |
| public       | historial_medico | 9                | diagnostico      | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | historial_medico | 10               | tratamiento      | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | historial_medico | 11               | vacuna           | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | historial_medico | 12               | observaciones    | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | historial_medico | 13               | veterinario_id   | uuid                     | uuid        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | mascotas         | 1                | id               | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | YES         | ALWAYS              | null           |
| public       | mascotas         | 2                | usuario_id       | uuid                     | uuid        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | mascotas         | 3                | nombre           | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | mascotas         | 4                | especie          | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | mascotas         | 5                | raza             | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | mascotas         | 6                | fecha_nacimiento | date                     | date        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | mascotas         | 7                | sexo             | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | mascotas         | 8                | peso             | numeric                  | numeric     | null                     | 6                 | 2             | YES         | null              | NO          | null                | null           |
| public       | mascotas         | 9                | observaciones    | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | mascotas         | 10               | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | YES         | now()             | NO          | null                | null           |
| public       | mascotas         | 11               | propietario      | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | notificaciones   | 1                | id               | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | YES         | ALWAYS              | null           |
| public       | notificaciones   | 2                | usuario_id       | uuid                     | uuid        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | notificaciones   | 3                | titulo           | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | notificaciones   | 4                | mensaje          | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | notificaciones   | 5                | tipo             | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | notificaciones   | 6                | leida            | boolean                  | bool        | null                     | null              | null          | NO          | false             | NO          | null                | null           |
| public       | notificaciones   | 7                | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | NO          | now()             | NO          | null                | null           |
| public       | perfiles         | 1                | id               | uuid                     | uuid        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | perfiles         | 2                | nombre           | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | perfiles         | 3                | rol              | text                     | text        | null                     | null              | null          | NO          | 'cliente'::text   | NO          | null                | null           |
| public       | perfiles         | 4                | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | YES         | now()             | NO          | null                | null           |
| public       | productos        | 1                | id               | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | YES         | ALWAYS              | null           |
| public       | productos        | 2                | nombre           | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | productos        | 3                | descripcion      | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | productos        | 4                | categoria        | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | productos        | 5                | precio           | numeric                  | numeric     | null                     | 10                | 2             | YES         | null              | NO          | null                | null           |
| public       | productos        | 6                | stock            | integer                  | int4        | null                     | 32                | 0             | YES         | 0                 | NO          | null                | null           |
| public       | productos        | 7                | imagen_url       | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | productos        | 8                | activo           | boolean                  | bool        | null                     | null              | null          | YES         | true              | NO          | null                | null           |
| public       | productos        | 9                | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | YES         | now()             | NO          | null                | null           |
| public       | reservas         | 1                | id               | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | YES         | ALWAYS              | null           |
| public       | reservas         | 2                | nombre           | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | reservas         | 3                | telefono         | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | reservas         | 4                | fecha            | date                     | date        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | reservas         | 5                | hora             | time without time zone   | time        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | reservas         | 6                | personas         | integer                  | int4        | null                     | 32                | 0             | NO          | 1                 | NO          | null                | null           |
| public       | reservas         | 7                | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | YES         | now()             | NO          | null                | null           |
| public       | reservas         | 8                | usuario_id       | uuid                     | uuid        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | reservas         | 9                | mascota          | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | reservas         | 10               | servicio         | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | reservas         | 11               | comentario       | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | reservas         | 12               | estado           | text                     | text        | null                     | null              | null          | NO          | 'Pendiente'::text | NO          | null                | null           |
| public       | reservas         | 13               | mascota_id       | bigint                   | int8        | null                     | 64                | 0             | YES         | null              | NO          | null                | null           |
| public       | servicios        | 1                | id               | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | YES         | ALWAYS              | null           |
| public       | servicios        | 2                | nombre           | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | servicios        | 3                | descripcion      | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | servicios        | 4                | precio           | numeric                  | numeric     | null                     | 10                | 2             | YES         | null              | NO          | null                | null           |
| public       | servicios        | 5                | duracion_minutos | integer                  | int4        | null                     | 32                | 0             | YES         | null              | NO          | null                | null           |
| public       | servicios        | 6                | activo           | boolean                  | bool        | null                     | null              | null          | YES         | true              | NO          | null                | null           |
| public       | servicios        | 7                | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | YES         | now()             | NO          | null                | null           |
| public       | vacunas          | 1                | id               | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | YES         | ALWAYS              | null           |
| public       | vacunas          | 2                | usuario_id       | uuid                     | uuid        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | vacunas          | 3                | mascota_id       | bigint                   | int8        | null                     | 64                | 0             | NO          | null              | NO          | null                | null           |
| public       | vacunas          | 4                | nombre_vacuna    | text                     | text        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | vacunas          | 5                | fecha_aplicacion | date                     | date        | null                     | null              | null          | NO          | null              | NO          | null                | null           |
| public       | vacunas          | 6                | proxima_fecha    | date                     | date        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | vacunas          | 7                | observaciones    | text                     | text        | null                     | null              | null          | YES         | null              | NO          | null                | null           |
| public       | vacunas          | 8                | created_at       | timestamp with time zone | timestamptz | null                     | null              | null          | YES         | now()             | NO          | null                | null           |
---

## 3. Claves primarias y claves foráneas

**Qué devuelve:** constraints de tipo PK y FK en `public`, columnas involucradas y reglas de actualización/borrado (relaciones entre tablas).
**Útil para:** validar relaciones asumidas por el código (`usuario_id`, `mascota_id`, etc.).

```sql
-- 3. Claves primarias y foráneas (public)
SELECT
  tc.table_schema,
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type, -- PRIMARY KEY / FOREIGN KEY
  kcu.column_name,
  kcu.ordinal_position,
  ccu.table_schema AS foreign_table_schema,
  ccu.table_name   AS foreign_table_name,
  ccu.column_name  AS foreign_column_name,
  rc.update_rule,
  rc.delete_rule,
  rc.match_option
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
  AND tc.constraint_type = 'FOREIGN KEY'
LEFT JOIN information_schema.referential_constraints rc
  ON rc.constraint_name = tc.constraint_name
  AND rc.constraint_schema = tc.table_schema
WHERE tc.table_schema = 'public'
  AND tc.constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name, kcu.ordinal_position;
```
| table_schema | table_name       | constraint_name                      | constraint_type | column_name    | ordinal_position | foreign_table_schema | foreign_table_name | foreign_column_name | update_rule | delete_rule | match_option |
| ------------ | ---------------- | ------------------------------------ | --------------- | -------------- | ---------------- | -------------------- | ------------------ | ------------------- | ----------- | ----------- | ------------ |
| public       | citas            | citas_mascota_id_fkey                | FOREIGN KEY     | mascota_id     | 1                | public               | mascotas           | id                  | NO ACTION   | CASCADE     | NONE         |
| public       | citas            | citas_servicio_id_fkey               | FOREIGN KEY     | servicio_id    | 1                | public               | servicios          | id                  | NO ACTION   | SET NULL    | NONE         |
| public       | citas            | citas_usuario_id_fkey                | FOREIGN KEY     | usuario_id     | 1                | null                 | null               | null                | NO ACTION   | CASCADE     | NONE         |
| public       | citas            | citas_pkey                           | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
| public       | consultas        | consultas_usuario_id_fkey            | FOREIGN KEY     | usuario_id     | 1                | null                 | null               | null                | NO ACTION   | NO ACTION   | NONE         |
| public       | consultas        | consultas_pkey                       | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
| public       | historial_medico | historial_medico_mascota_id_fkey     | FOREIGN KEY     | mascota_id     | 1                | public               | mascotas           | id                  | NO ACTION   | CASCADE     | NONE         |
| public       | historial_medico | historial_medico_usuario_id_fkey     | FOREIGN KEY     | usuario_id     | 1                | null                 | null               | null                | NO ACTION   | CASCADE     | NONE         |
| public       | historial_medico | historial_medico_veterinario_id_fkey | FOREIGN KEY     | veterinario_id | 1                | null                 | null               | null                | NO ACTION   | NO ACTION   | NONE         |
| public       | historial_medico | historial_medico_pkey                | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
| public       | mascotas         | mascotas_usuario_id_fkey             | FOREIGN KEY     | usuario_id     | 1                | null                 | null               | null                | NO ACTION   | CASCADE     | NONE         |
| public       | mascotas         | mascotas_pkey                        | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
| public       | notificaciones   | notificaciones_usuario_id_fkey       | FOREIGN KEY     | usuario_id     | 1                | null                 | null               | null                | NO ACTION   | CASCADE     | NONE         |
| public       | notificaciones   | notificaciones_pkey                  | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
| public       | perfiles         | perfiles_id_fkey                     | FOREIGN KEY     | id             | 1                | null                 | null               | null                | NO ACTION   | CASCADE     | NONE         |
| public       | perfiles         | perfiles_pkey                        | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
| public       | productos        | productos_pkey                       | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
| public       | reservas         | reservas_mascota_id_fkey             | FOREIGN KEY     | mascota_id     | 1                | public               | mascotas           | id                  | NO ACTION   | SET NULL    | NONE         |
| public       | reservas         | reservas_usuario_id_fkey             | FOREIGN KEY     | usuario_id     | 1                | null                 | null               | null                | NO ACTION   | NO ACTION   | NONE         |
| public       | reservas         | reservas_pkey                        | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
| public       | servicios        | servicios_pkey                       | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
| public       | vacunas          | vacunas_mascota_id_fkey              | FOREIGN KEY     | mascota_id     | 1                | public               | mascotas           | id                  | NO ACTION   | CASCADE     | NONE         |
| public       | vacunas          | vacunas_usuario_id_fkey              | FOREIGN KEY     | usuario_id     | 1                | null                 | null               | null                | NO ACTION   | CASCADE     | NONE         |
| public       | vacunas          | vacunas_pkey                         | PRIMARY KEY     | id             | 1                | null                 | null               | null                | null        | null        | null         |
---

## 4. Relaciones entre tablas (vista consolidada FK)

**Qué devuelve:** resumen de relaciones FK (tabla origen → tabla destino) para entender el grafo de dependencias.

```sql
-- 4. Relaciones entre tablas (solo claves foráneas)
SELECT
  tc.table_name AS source_table,
  string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS source_columns,
  ccu.table_name AS target_table,
  string_agg(ccu.column_name, ', ' ORDER BY kcu.ordinal_position) AS target_columns,
  tc.constraint_name,
  rc.update_rule,
  rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints rc
  ON rc.constraint_name = tc.constraint_name
  AND rc.constraint_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
GROUP BY tc.table_name, ccu.table_name, tc.constraint_name, rc.update_rule, rc.delete_rule
ORDER BY tc.table_name, tc.constraint_name;
```
| source_table     | source_columns | target_table | target_columns | constraint_name                  | update_rule | delete_rule |
| ---------------- | -------------- | ------------ | -------------- | -------------------------------- | ----------- | ----------- |
| citas            | mascota_id     | mascotas     | id             | citas_mascota_id_fkey            | NO ACTION   | CASCADE     |
| citas            | servicio_id    | servicios    | id             | citas_servicio_id_fkey           | NO ACTION   | SET NULL    |
| historial_medico | mascota_id     | mascotas     | id             | historial_medico_mascota_id_fkey | NO ACTION   | CASCADE     |
| reservas         | mascota_id     | mascotas     | id             | reservas_mascota_id_fkey         | NO ACTION   | SET NULL    |
| vacunas          | mascota_id     | mascotas     | id             | vacunas_mascota_id_fkey          | NO ACTION   | CASCADE     |
---

## 5. Restricciones CHECK

**Qué devuelve:** constraints `CHECK` en `public` y sus expresiones (útil para validar estados/valores permitidos reales).

```sql
-- 5. Restricciones CHECK
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  con.conname AS constraint_name,
  pg_get_constraintdef(con.oid, true) AS check_definition
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND con.contype = 'c'
ORDER BY c.relname, con.conname;
```
| schema_name | table_name | constraint_name         | check_definition                                                                       |
| ----------- | ---------- | ----------------------- | -------------------------------------------------------------------------------------- |
| public      | consultas  | consultas_estado_check  | CHECK (estado = ANY (ARRAY['Pendiente'::text, 'Atendida'::text]))                      |
| public      | perfiles   | perfiles_rol_check      | CHECK (rol = ANY (ARRAY['cliente'::text, 'veterinario'::text, 'administrador'::text])) |
| public      | productos  | productos_precio_check  | CHECK (precio >= 0::numeric)                                                           |
| public      | productos  | productos_stock_check   | CHECK (stock >= 0)                                                                     |
| public      | reservas   | reservas_personas_check | CHECK (personas >= 1 AND personas <= 50)                                               |
| public      | servicios  | servicios_precio_check  | CHECK (precio >= 0::numeric)                                                           |
---

## 6. Valores predeterminados y propiedades de columnas

**Qué devuelve:** defaults, identidad, nulabilidad y tipo por columna (complementa la sección 2 con foco en defaults/identidad).

```sql
-- 6. Valores predeterminados e identidad de columnas
SELECT
  table_schema,
  table_name,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default,
  is_identity,
  identity_generation
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (column_default IS NOT NULL OR is_identity = 'YES')
ORDER BY table_name, ordinal_position;
```
| table_schema | table_name       | column_name | data_type                | udt_name    | is_nullable | column_default    | is_identity | identity_generation |
| ------------ | ---------------- | ----------- | ------------------------ | ----------- | ----------- | ----------------- | ----------- | ------------------- |
| public       | citas            | id          | bigint                   | int8        | NO          | null              | YES         | ALWAYS              |
| public       | citas            | estado      | text                     | text        | YES         | 'pendiente'::text | NO          | null                |
| public       | citas            | created_at  | timestamp with time zone | timestamptz | YES         | now()             | NO          | null                |
| public       | consultas        | id          | bigint                   | int8        | NO          | null              | YES         | ALWAYS              |
| public       | consultas        | created_at  | timestamp with time zone | timestamptz | YES         | now()             | NO          | null                |
| public       | consultas        | estado      | text                     | text        | NO          | 'Pendiente'::text | NO          | null                |
| public       | historial_medico | id          | bigint                   | int8        | NO          | null              | YES         | ALWAYS              |
| public       | historial_medico | created_at  | timestamp with time zone | timestamptz | YES         | now()             | NO          | null                |
| public       | mascotas         | id          | bigint                   | int8        | NO          | null              | YES         | ALWAYS              |
| public       | mascotas         | created_at  | timestamp with time zone | timestamptz | YES         | now()             | NO          | null                |
| public       | notificaciones   | id          | bigint                   | int8        | NO          | null              | YES         | ALWAYS              |
| public       | notificaciones   | leida       | boolean                  | bool        | NO          | false             | NO          | null                |
| public       | notificaciones   | created_at  | timestamp with time zone | timestamptz | NO          | now()             | NO          | null                |
| public       | perfiles         | rol         | text                     | text        | NO          | 'cliente'::text   | NO          | null                |
| public       | perfiles         | created_at  | timestamp with time zone | timestamptz | YES         | now()             | NO          | null                |
| public       | productos        | id          | bigint                   | int8        | NO          | null              | YES         | ALWAYS              |
| public       | productos        | stock       | integer                  | int4        | YES         | 0                 | NO          | null                |
| public       | productos        | activo      | boolean                  | bool        | YES         | true              | NO          | null                |
| public       | productos        | created_at  | timestamp with time zone | timestamptz | YES         | now()             | NO          | null                |
| public       | reservas         | id          | bigint                   | int8        | NO          | null              | YES         | ALWAYS              |
| public       | reservas         | personas    | integer                  | int4        | NO          | 1                 | NO          | null                |
| public       | reservas         | created_at  | timestamp with time zone | timestamptz | YES         | now()             | NO          | null                |
| public       | reservas         | estado      | text                     | text        | NO          | 'Pendiente'::text | NO          | null                |
| public       | servicios        | id          | bigint                   | int8        | NO          | null              | YES         | ALWAYS              |
| public       | servicios        | activo      | boolean                  | bool        | YES         | true              | NO          | null                |
| public       | servicios        | created_at  | timestamp with time zone | timestamptz | YES         | now()             | NO          | null                |
| public       | vacunas          | id          | bigint                   | int8        | NO          | null              | YES         | ALWAYS              |
| public       | vacunas          | created_at  | timestamp with time zone | timestamptz | YES         | now()             | NO          | null                |
---

## 7. Índices

**Qué devuelve:** índices en tablas de `public`, definición, unicidad, condición parcial y columnas indexadas.

```sql
-- 7. Índices en tablas public
SELECT
  schemaname AS schema_name,
  tablename  AS table_name,
  indexname  AS index_name,
  indexdef   AS index_definition
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
```
| schema_name | table_name       | index_name                       | index_definition                                                                                                 |
| ----------- | ---------------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| public      | citas            | citas_pkey                       | CREATE UNIQUE INDEX citas_pkey ON public.citas USING btree (id)                                                  |
| public      | consultas        | consultas_pkey                   | CREATE UNIQUE INDEX consultas_pkey ON public.consultas USING btree (id)                                          |
| public      | historial_medico | historial_medico_pkey            | CREATE UNIQUE INDEX historial_medico_pkey ON public.historial_medico USING btree (id)                            |
| public      | mascotas         | mascotas_pkey                    | CREATE UNIQUE INDEX mascotas_pkey ON public.mascotas USING btree (id)                                            |
| public      | notificaciones   | idx_notificaciones_usuario_fecha | CREATE INDEX idx_notificaciones_usuario_fecha ON public.notificaciones USING btree (usuario_id, created_at DESC) |
| public      | notificaciones   | notificaciones_pkey              | CREATE UNIQUE INDEX notificaciones_pkey ON public.notificaciones USING btree (id)                                |
| public      | perfiles         | perfiles_pkey                    | CREATE UNIQUE INDEX perfiles_pkey ON public.perfiles USING btree (id)                                            |
| public      | productos        | productos_pkey                   | CREATE UNIQUE INDEX productos_pkey ON public.productos USING btree (id)                                          |
| public      | reservas         | reservas_pkey                    | CREATE UNIQUE INDEX reservas_pkey ON public.reservas USING btree (id)                                            |
| public      | servicios        | servicios_pkey                   | CREATE UNIQUE INDEX servicios_pkey ON public.servicios USING btree (id)                                          |
| public      | vacunas          | vacunas_pkey                     | CREATE UNIQUE INDEX vacunas_pkey ON public.vacunas USING btree (id)                                              |
---

## 8. Políticas RLS

**Qué devuelve:** todas las políticas de Row Level Security en `public` (roles, comandos, `USING`, `WITH CHECK`).
**Permisos/sensibilidad:** puede revelar reglas de acceso; requiere visibilidad sobre `pg_policies` (normalmente disponible en SQL Editor).

```sql
-- 8. Políticas RLS (public)
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual       AS using_expression,
  with_check AS with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```
| schemaname | tablename        | policyname                                     | permissive | roles                | cmd    | using_expression                                                                                                                             | with_check_expression                                                                                                                                                                                                                                                                               |
| ---------- | ---------------- | ---------------------------------------------- | ---------- | -------------------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| public     | consultas        | Administradores pueden ver todas las consultas | PERMISSIVE | {authenticated}      | SELECT | es_administrador()                                                                                                                           | null                                                                                                                                                                                                                                                                                                |
| public     | consultas        | Usuarios pueden actualizar sus consultas       | PERMISSIVE | {authenticated}      | UPDATE | (auth.uid() = usuario_id)                                                                                                                    | (auth.uid() = usuario_id)                                                                                                                                                                                                                                                                           |
| public     | consultas        | Usuarios pueden crear sus consultas            | PERMISSIVE | {authenticated}      | INSERT | null                                                                                                                                         | ((auth.uid() = usuario_id) AND (length(TRIM(BOTH FROM mensaje)) >= 10) AND (estado = 'Pendiente'::text))                                                                                                                                                                                            |
| public     | consultas        | Usuarios pueden ver sus consultas              | PERMISSIVE | {authenticated}      | SELECT | (auth.uid() = usuario_id)                                                                                                                    | null                                                                                                                                                                                                                                                                                                |
| public     | historial_medico | Consultar historial propio                     | PERMISSIVE | {authenticated}      | SELECT | ((auth.uid() = usuario_id) OR (EXISTS ( SELECT 1<br>   FROM perfiles p<br>  WHERE ((p.id = auth.uid()) AND (p.rol = 'veterinario'::text))))) | null                                                                                                                                                                                                                                                                                                |
| public     | historial_medico | Veterinarios registran atenciones              | PERMISSIVE | {authenticated}      | INSERT | null                                                                                                                                         | ((veterinario_id = auth.uid()) AND (EXISTS ( SELECT 1<br>   FROM perfiles p<br>  WHERE ((p.id = auth.uid()) AND (p.rol = 'veterinario'::text)))) AND (EXISTS ( SELECT 1<br>   FROM mascotas m<br>  WHERE ((m.id = historial_medico.mascota_id) AND (m.usuario_id = historial_medico.usuario_id))))) |
| public     | mascotas         | Usuarios pueden actualizar sus mascotas        | PERMISSIVE | {authenticated}      | UPDATE | (auth.uid() = usuario_id)                                                                                                                    | (auth.uid() = usuario_id)                                                                                                                                                                                                                                                                           |
| public     | mascotas         | Usuarios pueden registrar sus mascotas         | PERMISSIVE | {authenticated}      | INSERT | null                                                                                                                                         | (auth.uid() = usuario_id)                                                                                                                                                                                                                                                                           |
| public     | mascotas         | Usuarios pueden ver sus mascotas               | PERMISSIVE | {authenticated}      | SELECT | (auth.uid() = usuario_id)                                                                                                                    | null                                                                                                                                                                                                                                                                                                |
| public     | mascotas         | Veterinarios pueden ver mascotas               | PERMISSIVE | {authenticated}      | SELECT | (EXISTS ( SELECT 1<br>   FROM perfiles p<br>  WHERE ((p.id = auth.uid()) AND (p.rol = 'veterinario'::text))))                                | null                                                                                                                                                                                                                                                                                                |
| public     | notificaciones   | Usuarios consultan sus notificaciones          | PERMISSIVE | {authenticated}      | SELECT | (auth.uid() = usuario_id)                                                                                                                    | null                                                                                                                                                                                                                                                                                                |
| public     | notificaciones   | Usuarios marcan sus notificaciones             | PERMISSIVE | {authenticated}      | UPDATE | (auth.uid() = usuario_id)                                                                                                                    | (auth.uid() = usuario_id)                                                                                                                                                                                                                                                                           |
| public     | perfiles         | Usuarios consultan su perfil                   | PERMISSIVE | {authenticated}      | SELECT | (auth.uid() = id)                                                                                                                            | null                                                                                                                                                                                                                                                                                                |
| public     | productos        | Lectura publica de productos                   | PERMISSIVE | {anon,authenticated} | SELECT | (activo = true)                                                                                                                              | null                                                                                                                                                                                                                                                                                                |
| public     | reservas         | Usuarios pueden cancelar sus reservas          | PERMISSIVE | {authenticated}      | UPDATE | (auth.uid() = usuario_id)                                                                                                                    | ((auth.uid() = usuario_id) AND (estado = 'Cancelada'::text))                                                                                                                                                                                                                                        |
| public     | reservas         | Usuarios pueden crear sus reservas             | PERMISSIVE | {authenticated}      | INSERT | null                                                                                                                                         | ((auth.uid() = usuario_id) AND (length(TRIM(BOTH FROM nombre)) > 0) AND (telefono ~ '^[0-9]{8}$'::text) AND ((personas >= 1) AND (personas <= 50)) AND ((fecha + hora) > now()))                                                                                                                    |
| public     | reservas         | Usuarios pueden ver sus reservas               | PERMISSIVE | {authenticated}      | SELECT | (auth.uid() = usuario_id)                                                                                                                    | null                                                                                                                                                                                                                                                                                                |
| public     | reservas         | Veterinarios pueden actualizar reservas        | PERMISSIVE | {authenticated}      | UPDATE | (EXISTS ( SELECT 1<br>   FROM perfiles p<br>  WHERE ((p.id = auth.uid()) AND (p.rol = 'veterinario'::text))))                                | (EXISTS ( SELECT 1<br>   FROM perfiles p<br>  WHERE ((p.id = auth.uid()) AND (p.rol = 'veterinario'::text))))                                                                                                                                                                                       |
| public     | reservas         | Veterinarios pueden ver todas las reservas     | PERMISSIVE | {authenticated}      | SELECT | (EXISTS ( SELECT 1<br>   FROM perfiles p<br>  WHERE ((p.id = auth.uid()) AND (p.rol = 'veterinario'::text))))                                | null                                                                                                                                                                                                                                                                                                |
| public     | servicios        | Lectura publica de servicios                   | PERMISSIVE | {anon,authenticated} | SELECT | (activo = true)                                                                                                                              | null                                                                                                                                                                                                                                                                                                |
---

## 9. Estado RLS de cada tabla

**Qué devuelve:** si RLS está habilitado y si se fuerza para el owner en cada tabla de `public`.

```sql
-- 9. Estado RLS por tabla
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p')
ORDER BY c.relname;
```
| schema_name | table_name       | rls_enabled | rls_forced |
| ----------- | ---------------- | ----------- | ---------- |
| public      | citas            | true        | false      |
| public      | consultas        | true        | false      |
| public      | historial_medico | true        | false      |
| public      | mascotas         | true        | false      |
| public      | notificaciones   | true        | false      |
| public      | perfiles         | true        | false      |
| public      | productos        | true        | false      |
| public      | reservas         | true        | false      |
| public      | servicios        | true        | false      |
| public      | vacunas          | true        | false      |
---

## 10. Funciones PostgreSQL y sus definiciones

**Qué devuelve:** funciones en `public` (incluye posibles RPCs expuestos por Supabase), argumentos, tipo de retorno, lenguaje, volatilidad, seguridad y definición SQL.
**Permisos/sensibilidad:** las definiciones pueden contener lógica de negocio; `prosecdef` indica funciones `SECURITY DEFINER` (relevante para seguridad).

```sql
-- 10. Funciones en esquema public y sus definiciones
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  pg_get_function_result(p.oid) AS result_type,
  l.lanname AS language,
  p.provolatile AS volatility, -- i=immutable, s=stable, v=volatile
  p.prosecdef AS security_definer,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_language l ON l.oid = p.prolang
WHERE n.nspname = 'public'
ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);
```
| schema_name | function_name                       | arguments                                                                                                      | result_type                                                                                                                                                                                                                                                                            | language | volatility | security_definer | definition                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ----------- | ----------------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ---------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| public      | actualizar_stock_producto_admin     | p_producto_id bigint, p_stock integer                                                                          | void                                                                                                                                                                                                                                                                                   | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.actualizar_stock_producto_admin(p_producto_id bigint, p_stock integer)<br> RETURNS void<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para actualizar el stock';<br>    END IF;<br><br>    IF p_stock IS NULL OR p_stock < 0 THEN<br>        RAISE EXCEPTION 'El stock no puede ser negativo';<br>    END IF;<br><br>    UPDATE public.productos<br>    SET stock = p_stock<br>    WHERE id = p_producto_id;<br><br>    IF NOT FOUND THEN<br>        RAISE EXCEPTION 'Producto no encontrado';<br>    END IF;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| public      | cambiar_estado_consulta             | p_consulta_id bigint, p_estado text                                                                            | void                                                                                                                                                                                                                                                                                   | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.cambiar_estado_consulta(p_consulta_id bigint, p_estado text)<br> RETURNS void<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para modificar consultas';<br>    END IF;<br><br>    IF p_estado IS NULL OR p_estado NOT IN ('Pendiente', 'Atendida') THEN<br>        RAISE EXCEPTION 'Estado no válido';<br>    END IF;<br><br>    UPDATE public.consultas<br>    SET estado = p_estado<br>    WHERE id = p_consulta_id;<br><br>    IF NOT FOUND THEN<br>        RAISE EXCEPTION 'Consulta no encontrada';<br>    END IF;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| public      | cambiar_estado_producto_admin       | p_producto_id bigint, p_activo boolean                                                                         | void                                                                                                                                                                                                                                                                                   | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.cambiar_estado_producto_admin(p_producto_id bigint, p_activo boolean)<br> RETURNS void<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para cambiar el estado';<br>    END IF;<br><br>    IF p_activo IS NULL THEN<br>        RAISE EXCEPTION 'El estado no es válido';<br>    END IF;<br><br>    UPDATE public.productos<br>    SET activo = p_activo<br>    WHERE id = p_producto_id;<br><br>    IF NOT FOUND THEN<br>        RAISE EXCEPTION 'Producto no encontrado';<br>    END IF;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| public      | cambiar_estado_reserva_admin        | p_reserva_id bigint, p_estado text                                                                             | void                                                                                                                                                                                                                                                                                   | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.cambiar_estado_reserva_admin(p_reserva_id bigint, p_estado text)<br> RETURNS void<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para modificar reservas';<br>    END IF;<br><br>    IF p_estado IS NULL OR p_estado NOT IN (<br>        'Pendiente',<br>        'Confirmada',<br>        'Atendida',<br>        'Cancelada'<br>    ) THEN<br>        RAISE EXCEPTION 'Estado no válido';<br>    END IF;<br><br>    UPDATE public.reservas<br>    SET estado = p_estado<br>    WHERE id = p_reserva_id;<br><br>    IF NOT FOUND THEN<br>        RAISE EXCEPTION 'Reserva no encontrada';<br>    END IF;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| public      | cambiar_estado_servicio_admin       | p_servicio_id bigint, p_activo boolean                                                                         | void                                                                                                                                                                                                                                                                                   | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.cambiar_estado_servicio_admin(p_servicio_id bigint, p_activo boolean)<br> RETURNS void<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para realizar esta operación';<br>    END IF;<br><br>    IF p_activo IS NULL THEN<br>        RAISE EXCEPTION 'El estado indicado no es válido';<br>    END IF;<br><br>    UPDATE public.servicios<br>    SET activo = p_activo<br>    WHERE id = p_servicio_id;<br><br>    IF NOT FOUND THEN<br>        RAISE EXCEPTION 'El servicio no existe';<br>    END IF;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| public      | cambiar_rol_usuario                 | p_usuario_id uuid, p_nuevo_rol text                                                                            | void                                                                                                                                                                                                                                                                                   | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.cambiar_rol_usuario(p_usuario_id uuid, p_nuevo_rol text)<br> RETURNS void<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>DECLARE<br>    v_rol_actual TEXT;<br>    v_cantidad_admins INTEGER;<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para realizar esta operación';<br>    END IF;<br><br>    IF p_nuevo_rol NOT IN ('cliente', 'veterinario', 'administrador') THEN<br>        RAISE EXCEPTION 'El rol indicado no es válido';<br>    END IF;<br><br>    IF p_usuario_id = auth.uid() THEN<br>        RAISE EXCEPTION 'No puedes cambiar tu propio rol';<br>    END IF;<br><br>    SELECT rol<br>    INTO v_rol_actual<br>    FROM public.perfiles<br>    WHERE id = p_usuario_id;<br><br>    IF NOT FOUND THEN<br>        RAISE EXCEPTION 'El usuario no existe';<br>    END IF;<br><br>    -- Evitar dejar el sistema sin administradores.<br>    IF v_rol_actual = 'administrador'<br>       AND p_nuevo_rol <> 'administrador' THEN<br><br>        SELECT COUNT(*)<br>        INTO v_cantidad_admins<br>        FROM public.perfiles<br>        WHERE rol = 'administrador';<br><br>        IF v_cantidad_admins <= 1 THEN<br>            RAISE EXCEPTION 'No puedes quitar el último administrador';<br>        END IF;<br>    END IF;<br><br>    UPDATE public.perfiles<br>    SET rol = p_nuevo_rol<br>    WHERE id = p_usuario_id;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public      | crear_perfil_usuario                |                                                                                                                | trigger                                                                                                                                                                                                                                                                                | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.crear_perfil_usuario()<br> RETURNS trigger<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    INSERT INTO public.perfiles (id, nombre, rol)<br>    VALUES (<br>        NEW.id,<br>        COALESCE(<br>            NULLIF(NEW.raw_user_meta_data ->> 'full_name', ''),<br>            NULLIF(NEW.raw_user_meta_data ->> 'name', ''),<br>            'Usuario'<br>        ),<br>        'cliente'<br>    )<br>    ON CONFLICT (id) DO NOTHING;<br><br>    RETURN NEW;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| public      | crear_producto_admin                | p_nombre text, p_descripcion text, p_categoria text, p_precio numeric, p_stock integer, p_imagen_url text      | bigint                                                                                                                                                                                                                                                                                 | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.crear_producto_admin(p_nombre text, p_descripcion text, p_categoria text, p_precio numeric, p_stock integer, p_imagen_url text)<br> RETURNS bigint<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>DECLARE<br>    v_id bigint;<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para registrar productos';<br>    END IF;<br><br>    IF p_nombre IS NULL OR length(trim(p_nombre)) = 0 THEN<br>        RAISE EXCEPTION 'El nombre es obligatorio';<br>    END IF;<br><br>    IF p_precio IS NOT NULL AND p_precio < 0 THEN<br>        RAISE EXCEPTION 'El precio no puede ser negativo';<br>    END IF;<br><br>    IF p_stock IS NULL OR p_stock < 0 THEN<br>        RAISE EXCEPTION 'El stock no puede ser negativo';<br>    END IF;<br><br>    INSERT INTO public.productos (<br>        nombre, descripcion, categoria, precio,<br>        stock, imagen_url, activo<br>    )<br>    VALUES (<br>        trim(p_nombre), p_descripcion, p_categoria,<br>        p_precio, p_stock, p_imagen_url, true<br>    )<br>    RETURNING id INTO v_id;<br><br>    RETURN v_id;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| public      | editar_producto_admin               | p_producto_id bigint, p_nombre text, p_descripcion text, p_categoria text, p_precio numeric, p_imagen_url text | void                                                                                                                                                                                                                                                                                   | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.editar_producto_admin(p_producto_id bigint, p_nombre text, p_descripcion text, p_categoria text, p_precio numeric, p_imagen_url text)<br> RETURNS void<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para editar productos';<br>    END IF;<br><br>    IF p_nombre IS NULL OR length(trim(p_nombre)) = 0 THEN<br>        RAISE EXCEPTION 'El nombre es obligatorio';<br>    END IF;<br><br>    IF p_precio IS NOT NULL AND p_precio < 0 THEN<br>        RAISE EXCEPTION 'El precio no puede ser negativo';<br>    END IF;<br><br>    UPDATE public.productos<br>    SET nombre = trim(p_nombre),<br>        descripcion = p_descripcion,<br>        categoria = p_categoria,<br>        precio = p_precio,<br>        imagen_url = p_imagen_url<br>    WHERE id = p_producto_id;<br><br>    IF NOT FOUND THEN<br>        RAISE EXCEPTION 'Producto no encontrado';<br>    END IF;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| public      | es_administrador                    |                                                                                                                | boolean                                                                                                                                                                                                                                                                                | sql      | v          | true             | CREATE OR REPLACE FUNCTION public.es_administrador()<br> RETURNS boolean<br> LANGUAGE sql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>    SELECT EXISTS (<br>        SELECT 1<br>        FROM public.perfiles<br>        WHERE id = auth.uid()<br>          AND rol = 'administrador'<br>    );<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| public      | guardar_servicio_admin              | p_servicio_id bigint, p_nombre text, p_descripcion text, p_precio numeric, p_duracion_minutos integer          | bigint                                                                                                                                                                                                                                                                                 | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.guardar_servicio_admin(p_servicio_id bigint, p_nombre text, p_descripcion text, p_precio numeric, p_duracion_minutos integer)<br> RETURNS bigint<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>DECLARE<br>    v_id BIGINT;<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para realizar esta operación';<br>    END IF;<br><br>    IF p_nombre IS NULL OR LENGTH(TRIM(p_nombre)) = 0 THEN<br>        RAISE EXCEPTION 'El nombre del servicio es obligatorio';<br>    END IF;<br><br>    IF p_precio IS NOT NULL AND p_precio < 0 THEN<br>        RAISE EXCEPTION 'El precio no puede ser negativo';<br>    END IF;<br><br>    IF p_duracion_minutos IS NOT NULL AND p_duracion_minutos <= 0 THEN<br>        RAISE EXCEPTION 'La duración debe ser mayor que cero';<br>    END IF;<br><br>    IF p_servicio_id IS NULL THEN<br>        INSERT INTO public.servicios (<br>            nombre,<br>            descripcion,<br>            precio,<br>            duracion_minutos<br>        )<br>        VALUES (<br>            TRIM(p_nombre),<br>            NULLIF(TRIM(COALESCE(p_descripcion, '')), ''),<br>            p_precio,<br>            p_duracion_minutos<br>        )<br>        RETURNING id INTO v_id;<br>    ELSE<br>        UPDATE public.servicios<br>        SET<br>            nombre = TRIM(p_nombre),<br>            descripcion = NULLIF(TRIM(COALESCE(p_descripcion, '')), ''),<br>            precio = p_precio,<br>            duracion_minutos = p_duracion_minutos<br>        WHERE id = p_servicio_id<br>        RETURNING id INTO v_id;<br><br>        IF NOT FOUND THEN<br>            RAISE EXCEPTION 'El servicio no existe';<br>        END IF;<br>    END IF;<br><br>    RETURN v_id;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                         |
| public      | listar_mascotas_admin               |                                                                                                                | TABLE(id bigint, usuario_id uuid, nombre text, especie text, raza text, fecha_nacimiento date, sexo text, peso numeric, observaciones text, created_at timestamp with time zone, propietario text, nombre_propietario text)                                                            | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.listar_mascotas_admin()<br> RETURNS TABLE(id bigint, usuario_id uuid, nombre text, especie text, raza text, fecha_nacimiento date, sexo text, peso numeric, observaciones text, created_at timestamp with time zone, propietario text, nombre_propietario text)<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para realizar esta operación';<br>    END IF;<br><br>    RETURN QUERY<br>    SELECT<br>        m.id,<br>        m.usuario_id,<br>        m.nombre,<br>        m.especie,<br>        m.raza,<br>        m.fecha_nacimiento,<br>        m.sexo,<br>        m.peso,<br>        m.observaciones,<br>        m.created_at,<br>        m.propietario,<br>        p.nombre<br>    FROM public.mascotas m<br>    LEFT JOIN public.perfiles p<br>        ON p.id = m.usuario_id<br>    ORDER BY m.created_at DESC NULLS LAST;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| public      | listar_perfiles_admin               |                                                                                                                | TABLE(id uuid, nombre text, rol text, created_at timestamp with time zone)                                                                                                                                                                                                             | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.listar_perfiles_admin()<br> RETURNS TABLE(id uuid, nombre text, rol text, created_at timestamp with time zone)<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para realizar esta operación';<br>    END IF;<br><br>    RETURN QUERY<br>    SELECT<br>        p.id,<br>        p.nombre,<br>        p.rol,<br>        p.created_at<br>    FROM public.perfiles p<br>    ORDER BY p.created_at DESC;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| public      | listar_productos_admin              |                                                                                                                | TABLE(id bigint, nombre text, descripcion text, categoria text, precio numeric, stock integer, imagen_url text, activo boolean, created_at timestamp with time zone)                                                                                                                   | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.listar_productos_admin()<br> RETURNS TABLE(id bigint, nombre text, descripcion text, categoria text, precio numeric, stock integer, imagen_url text, activo boolean, created_at timestamp with time zone)<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para ver los productos';<br>    END IF;<br><br>    RETURN QUERY<br>    SELECT<br>        p.id,<br>        p.nombre,<br>        p.descripcion,<br>        p.categoria,<br>        p.precio,<br>        p.stock,<br>        p.imagen_url,<br>        p.activo,<br>        p.created_at<br>    FROM public.productos AS p<br>    ORDER BY p.nombre;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| public      | listar_reservas_admin               |                                                                                                                | TABLE(id bigint, nombre text, telefono text, fecha date, hora time without time zone, personas integer, created_at timestamp with time zone, usuario_id uuid, mascota text, servicio text, comentario text, estado text, mascota_id bigint, nombre_mascota text, especie_mascota text) | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.listar_reservas_admin()<br> RETURNS TABLE(id bigint, nombre text, telefono text, fecha date, hora time without time zone, personas integer, created_at timestamp with time zone, usuario_id uuid, mascota text, servicio text, comentario text, estado text, mascota_id bigint, nombre_mascota text, especie_mascota text)<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para realizar esta operación';<br>    END IF;<br><br>    RETURN QUERY<br>    SELECT<br>        r.id,<br>        r.nombre,<br>        r.telefono,<br>        r.fecha,<br>        r.hora,<br>        r.personas,<br>        r.created_at,<br>        r.usuario_id,<br>        r.mascota,<br>        r.servicio,<br>        r.comentario,<br>        r.estado,<br>        r.mascota_id,<br>        m.nombre,<br>        m.especie<br>    FROM public.reservas r<br>    LEFT JOIN public.mascotas m<br>        ON m.id = r.mascota_id<br>    ORDER BY r.fecha DESC, r.hora DESC;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public      | listar_servicios_admin              |                                                                                                                | TABLE(id bigint, nombre text, descripcion text, precio numeric, duracion_minutos integer, activo boolean, created_at timestamp with time zone)                                                                                                                                         | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.listar_servicios_admin()<br> RETURNS TABLE(id bigint, nombre text, descripcion text, precio numeric, duracion_minutos integer, activo boolean, created_at timestamp with time zone)<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para realizar esta operación';<br>    END IF;<br><br>    RETURN QUERY<br>    SELECT<br>        s.id,<br>        s.nombre,<br>        s.descripcion,<br>        s.precio,<br>        s.duracion_minutos,<br>        s.activo,<br>        s.created_at<br>    FROM public.servicios s<br>    ORDER BY s.created_at DESC;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| public      | notificar_cambio_reserva            |                                                                                                                | trigger                                                                                                                                                                                                                                                                                | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.notificar_cambio_reserva()<br> RETURNS trigger<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NEW.usuario_id IS NULL THEN<br>        RETURN NEW;<br>    END IF;<br><br>    IF NEW.estado IS NOT DISTINCT FROM OLD.estado THEN<br>        RETURN NEW;<br>    END IF;<br><br>    IF NEW.estado IN ('Confirmada', 'Cancelada', 'Atendida') THEN<br>        INSERT INTO public.notificaciones (<br>            usuario_id,<br>            titulo,<br>            mensaje,<br>            tipo<br>        )<br>        VALUES (<br>            NEW.usuario_id,<br>            CASE NEW.estado<br>                WHEN 'Confirmada' THEN 'Cita confirmada'<br>                WHEN 'Cancelada' THEN 'Cita cancelada'<br>                WHEN 'Atendida' THEN 'Cita atendida'<br>            END,<br>            CASE NEW.estado<br>                WHEN 'Confirmada' THEN<br>                    'Tu cita para ' \|\|<br>                    COALESCE(NULLIF(NEW.mascota, ''), 'tu mascota') \|\|<br>                    ' ha sido confirmada.'<br>                WHEN 'Cancelada' THEN<br>                    'Tu cita para ' \|\|<br>                    COALESCE(NULLIF(NEW.mascota, ''), 'tu mascota') \|\|<br>                    ' ha sido cancelada.'<br>                WHEN 'Atendida' THEN<br>                    'La atención de ' \|\|<br>                    COALESCE(NULLIF(NEW.mascota, ''), 'tu mascota') \|\|<br>                    ' ha sido registrada.'<br>            END,<br>            'reserva'<br>        );<br>    END IF;<br><br>    RETURN NEW;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public      | notificar_consulta_atendida         |                                                                                                                | trigger                                                                                                                                                                                                                                                                                | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.notificar_consulta_atendida()<br> RETURNS trigger<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF OLD.estado = 'Pendiente'<br>       AND NEW.estado = 'Atendida' THEN<br><br>        INSERT INTO public.notificaciones (<br>            usuario_id,<br>            titulo,<br>            mensaje,<br>            tipo<br>        )<br>        VALUES (<br>            NEW.usuario_id,<br>            'Consulta atendida',<br>            'Tu consulta ha sido atendida. Ingresa a PetCare para revisar su estado.',<br>            'consulta_atendida'<br>        );<br><br>    END IF;<br><br>    RETURN NEW;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| public      | notificar_nueva_consulta_admin      |                                                                                                                | trigger                                                                                                                                                                                                                                                                                | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.notificar_nueva_consulta_admin()<br> RETURNS trigger<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    INSERT INTO public.notificaciones (<br>        usuario_id,<br>        titulo,<br>        mensaje,<br>        tipo<br>    )<br>    SELECT<br>        p.id,<br>        'Nueva consulta',<br>        'Un cliente ha enviado una consulta: '<br>            \|\| LEFT(COALESCE(NEW.mensaje, ''), 100),<br>        'consulta_admin'<br>    FROM public.perfiles p<br>    WHERE p.rol = 'administrador';<br><br>    RETURN NEW;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public      | notificar_nueva_reserva_admin       |                                                                                                                | trigger                                                                                                                                                                                                                                                                                | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.notificar_nueva_reserva_admin()<br> RETURNS trigger<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    INSERT INTO public.notificaciones (<br>        usuario_id,<br>        titulo,<br>        mensaje,<br>        tipo<br>    )<br>    SELECT<br>        p.id,<br>        'Nueva reserva',<br>        'Un cliente ha registrado una nueva reserva para '<br>            \|\| COALESCE(NEW.mascota, 'una mascota')<br>            \|\| '.',<br>        'reserva_admin'<br>    FROM public.perfiles p<br>    WHERE p.rol = 'administrador';<br><br>    RETURN NEW;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| public      | notificar_nueva_reserva_veterinario |                                                                                                                | trigger                                                                                                                                                                                                                                                                                | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.notificar_nueva_reserva_veterinario()<br> RETURNS trigger<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    INSERT INTO public.notificaciones (<br>        usuario_id,<br>        titulo,<br>        mensaje,<br>        tipo<br>    )<br>    SELECT<br>        p.id,<br>        'Nueva reserva',<br>        'Se ha registrado una nueva reserva para '<br>            \|\| COALESCE(NEW.mascota, 'una mascota')<br>            \|\| '. Revisa las citas pendientes.',<br>        'reserva_veterinario'<br>    FROM public.perfiles p<br>    WHERE p.rol = 'veterinario';<br><br>    RETURN NEW;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| public      | notificar_nuevo_historial           |                                                                                                                | trigger                                                                                                                                                                                                                                                                                | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.notificar_nuevo_historial()<br> RETURNS trigger<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>DECLARE<br>    nombre_mascota TEXT;<br>BEGIN<br>    IF NEW.usuario_id IS NULL THEN<br>        RETURN NEW;<br>    END IF;<br><br>    SELECT m.nombre<br>    INTO nombre_mascota<br>    FROM public.mascotas AS m<br>    WHERE m.id = NEW.mascota_id;<br><br>    INSERT INTO public.notificaciones (<br>        usuario_id,<br>        titulo,<br>        mensaje,<br>        tipo<br>    )<br>    VALUES (<br>        NEW.usuario_id,<br>        'Nuevo registro médico',<br>        'Se registró una nueva atención médica para ' \|\|<br>        COALESCE(NULLIF(nombre_mascota, ''), 'tu mascota') \|\| '.',<br>        'historial_medico'<br>    );<br><br>    RETURN NEW;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| public      | notificar_nuevo_usuario_admin       |                                                                                                                | trigger                                                                                                                                                                                                                                                                                | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.notificar_nuevo_usuario_admin()<br> RETURNS trigger<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NEW.rol = 'cliente' THEN<br>        INSERT INTO public.notificaciones (<br>            usuario_id,<br>            titulo,<br>            mensaje,<br>            tipo<br>        )<br>        SELECT<br>            p.id,<br>            'Nuevo usuario registrado',<br>            'Se ha registrado un nuevo cliente en PetCare.',<br>            'usuario_nuevo'<br>        FROM public.perfiles p<br>        WHERE p.rol = 'administrador'<br>          AND p.id <> NEW.id;<br>    END IF;<br><br>    RETURN NEW;<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| public      | obtener_estadisticas_admin          |                                                                                                                | TABLE(total_mascotas bigint, total_reservas bigint, reservas_atendidas bigint)                                                                                                                                                                                                         | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.obtener_estadisticas_admin()<br> RETURNS TABLE(total_mascotas bigint, total_reservas bigint, reservas_atendidas bigint)<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para realizar esta operación';<br>    END IF;<br><br>    RETURN QUERY<br>    SELECT<br>        (SELECT COUNT(*) FROM public.mascotas),<br>        (SELECT COUNT(*) FROM public.reservas),<br>        (<br>            SELECT COUNT(*)<br>            FROM public.reservas<br>            WHERE estado = 'Atendida'<br>        );<br>END;<br>$function$<br>                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| public      | obtener_reportes_admin              |                                                                                                                | jsonb                                                                                                                                                                                                                                                                                  | plpgsql  | v          | true             | CREATE OR REPLACE FUNCTION public.obtener_reportes_admin()<br> RETURNS jsonb<br> LANGUAGE plpgsql<br> SECURITY DEFINER<br> SET search_path TO ''<br>AS $function$<br>BEGIN<br>    IF NOT public.es_administrador() THEN<br>        RAISE EXCEPTION 'No tienes permisos para realizar esta operación';<br>    END IF;<br><br>    RETURN jsonb_build_object(<br><br>        'total_usuarios',<br>        (SELECT COUNT(*) FROM public.perfiles),<br><br>        'mascotas_por_especie',<br>        COALESCE((<br>            SELECT jsonb_agg(<br>                jsonb_build_object(<br>                    'especie', especie,<br>                    'cantidad', cantidad<br>                )<br>                ORDER BY cantidad DESC<br>            )<br>            FROM (<br>                SELECT especie, COUNT(*) AS cantidad<br>                FROM public.mascotas<br>                GROUP BY especie<br>            ) datos<br>        ), '[]'::JSONB),<br><br>        'reservas_por_estado',<br>        COALESCE((<br>            SELECT jsonb_agg(<br>                jsonb_build_object(<br>                    'estado', estado,<br>                    'cantidad', cantidad<br>                )<br>                ORDER BY cantidad DESC<br>            )<br>            FROM (<br>                SELECT estado, COUNT(*) AS cantidad<br>                FROM public.reservas<br>                GROUP BY estado<br>            ) datos<br>        ), '[]'::JSONB),<br><br>        'servicios_solicitados',<br>        COALESCE((<br>            SELECT jsonb_agg(<br>                jsonb_build_object(<br>                    'servicio', servicio,<br>                    'cantidad', cantidad<br>                )<br>                ORDER BY cantidad DESC<br>            )<br>            FROM (<br>                SELECT<br>                    COALESCE(servicio, 'Sin especificar') AS servicio,<br>                    COUNT(*) AS cantidad<br>                FROM public.reservas<br>                GROUP BY COALESCE(servicio, 'Sin especificar')<br>            ) datos<br>        ), '[]'::JSONB),<br><br>        'total_atenciones',<br>        (SELECT COUNT(*) FROM public.historial_medico)<br>    );<br>END;<br>$function$<br> |
---
**Consulta complementaria (foco en las RPCs usadas por el código):**

```sql
-- 10b. Verificación de RPCs referenciados en el código de la app
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  pg_get_function_result(p.oid) AS result_type,
  p.prosecdef AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'listar_mascotas_admin',
    'listar_reservas_admin',
    'listar_productos_admin',
    'listar_servicios_admin',
    'listar_perfiles_admin',
    'obtener_estadisticas_admin',
    'obtener_reportes_admin',
    'crear_producto_admin',
    'editar_producto_admin',
    'actualizar_stock_producto_admin',
    'cambiar_estado_producto_admin',
    'guardar_servicio_admin',
    'cambiar_estado_servicio_admin',
    'cambiar_estado_reserva_admin',
    'cambiar_estado_consulta',
    'cambiar_rol_usuario'
  )
ORDER BY p.proname;
```
| schema_name | function_name                   | arguments                                                                                                      | result_type                                                                                                                                                                                                                                                                            | security_definer |
| ----------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| public      | actualizar_stock_producto_admin | p_producto_id bigint, p_stock integer                                                                          | void                                                                                                                                                                                                                                                                                   | true             |
| public      | cambiar_estado_consulta         | p_consulta_id bigint, p_estado text                                                                            | void                                                                                                                                                                                                                                                                                   | true             |
| public      | cambiar_estado_producto_admin   | p_producto_id bigint, p_activo boolean                                                                         | void                                                                                                                                                                                                                                                                                   | true             |
| public      | cambiar_estado_reserva_admin    | p_reserva_id bigint, p_estado text                                                                             | void                                                                                                                                                                                                                                                                                   | true             |
| public      | cambiar_estado_servicio_admin   | p_servicio_id bigint, p_activo boolean                                                                         | void                                                                                                                                                                                                                                                                                   | true             |
| public      | cambiar_rol_usuario             | p_usuario_id uuid, p_nuevo_rol text                                                                            | void                                                                                                                                                                                                                                                                                   | true             |
| public      | crear_producto_admin            | p_nombre text, p_descripcion text, p_categoria text, p_precio numeric, p_stock integer, p_imagen_url text      | bigint                                                                                                                                                                                                                                                                                 | true             |
| public      | editar_producto_admin           | p_producto_id bigint, p_nombre text, p_descripcion text, p_categoria text, p_precio numeric, p_imagen_url text | void                                                                                                                                                                                                                                                                                   | true             |
| public      | guardar_servicio_admin          | p_servicio_id bigint, p_nombre text, p_descripcion text, p_precio numeric, p_duracion_minutos integer          | bigint                                                                                                                                                                                                                                                                                 | true             |
| public      | listar_mascotas_admin           |                                                                                                                | TABLE(id bigint, usuario_id uuid, nombre text, especie text, raza text, fecha_nacimiento date, sexo text, peso numeric, observaciones text, created_at timestamp with time zone, propietario text, nombre_propietario text)                                                            | true             |
| public      | listar_perfiles_admin           |                                                                                                                | TABLE(id uuid, nombre text, rol text, created_at timestamp with time zone)                                                                                                                                                                                                             | true             |
| public      | listar_productos_admin          |                                                                                                                | TABLE(id bigint, nombre text, descripcion text, categoria text, precio numeric, stock integer, imagen_url text, activo boolean, created_at timestamp with time zone)                                                                                                                   | true             |
| public      | listar_reservas_admin           |                                                                                                                | TABLE(id bigint, nombre text, telefono text, fecha date, hora time without time zone, personas integer, created_at timestamp with time zone, usuario_id uuid, mascota text, servicio text, comentario text, estado text, mascota_id bigint, nombre_mascota text, especie_mascota text) | true             |
| public      | listar_servicios_admin          |                                                                                                                | TABLE(id bigint, nombre text, descripcion text, precio numeric, duracion_minutos integer, activo boolean, created_at timestamp with time zone)                                                                                                                                         | true             |
| public      | obtener_estadisticas_admin      |                                                                                                                | TABLE(total_mascotas bigint, total_reservas bigint, reservas_atendidas bigint)                                                                                                                                                                                                         | true             |
| public      | obtener_reportes_admin          |                                                                                                                | jsonb                                                                                                                                                                                                                                                                                  | true             |
---

## 11. Triggers y funciones que ejecutan

**Qué devuelve:** triggers en `public`, tabla asociada, momento/evento, función ejecutada y definición del trigger.
**Relevancia:** permite verificar generación de notificaciones, auditoría y cambios de estado.

```sql
-- 11. Triggers y funciones asociadas (public)
SELECT
  event_object_schema AS schema_name,
  event_object_table  AS table_name,
  trigger_name,
  action_timing,      -- BEFORE / AFTER / INSTEAD OF
  string_agg(event_manipulation, ', ' ORDER BY event_manipulation) AS events,
  action_orientation, -- ROW / STATEMENT
  action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
GROUP BY event_object_schema, event_object_table, trigger_name, action_timing, action_orientation, action_statement
ORDER BY event_object_table, trigger_name;
```
| schema_name | table_name       | trigger_name                      | action_timing | events | action_orientation | action_statement                                       |
| ----------- | ---------------- | --------------------------------- | ------------- | ------ | ------------------ | ------------------------------------------------------ |
| public      | consultas        | trigger_consulta_atendida_cliente | AFTER         | UPDATE | ROW                | EXECUTE FUNCTION notificar_consulta_atendida()         |
| public      | consultas        | trigger_nueva_consulta_admin      | AFTER         | INSERT | ROW                | EXECUTE FUNCTION notificar_nueva_consulta_admin()      |
| public      | historial_medico | trigger_notificar_nuevo_historial | AFTER         | INSERT | ROW                | EXECUTE FUNCTION notificar_nuevo_historial()           |
| public      | perfiles         | trigger_nuevo_usuario_admin       | AFTER         | INSERT | ROW                | EXECUTE FUNCTION notificar_nuevo_usuario_admin()       |
| public      | reservas         | trigger_notificar_cambio_reserva  | AFTER         | UPDATE | ROW                | EXECUTE FUNCTION notificar_cambio_reserva()            |
| public      | reservas         | trigger_nueva_reserva_admin       | AFTER         | INSERT | ROW                | EXECUTE FUNCTION notificar_nueva_reserva_admin()       |
| public      | reservas         | trigger_nueva_reserva_veterinario | AFTER         | INSERT | ROW                | EXECUTE FUNCTION notificar_nueva_reserva_veterinario() |
```sql
-- 11b. Detalle desde el catálogo pg_trigger (excluye triggers internos)
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  t.tgname  AS trigger_name,
  pg_get_triggerdef(t.oid, true) AS trigger_definition,
  p.proname AS function_name,
  pn.nspname AS function_schema,
  t.tgenabled AS enabled_state
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_proc p ON p.oid = t.tgfoid
LEFT JOIN pg_namespace pn ON pn.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND NOT t.tgisinternal
ORDER BY c.relname, t.tgname;
```
| schema_name | table_name       | trigger_name                      | trigger_definition                                                                                                                                                                        | function_name                       | function_schema | enabled_state |
| ----------- | ---------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | --------------- | ------------- |
| public      | consultas        | trigger_consulta_atendida_cliente | CREATE TRIGGER trigger_consulta_atendida_cliente AFTER UPDATE OF estado ON consultas FOR EACH ROW EXECUTE FUNCTION notificar_consulta_atendida()                                          | notificar_consulta_atendida         | public          | O             |
| public      | consultas        | trigger_nueva_consulta_admin      | CREATE TRIGGER trigger_nueva_consulta_admin AFTER INSERT ON consultas FOR EACH ROW EXECUTE FUNCTION notificar_nueva_consulta_admin()                                                      | notificar_nueva_consulta_admin      | public          | O             |
| public      | historial_medico | trigger_notificar_nuevo_historial | CREATE TRIGGER trigger_notificar_nuevo_historial AFTER INSERT ON historial_medico FOR EACH ROW EXECUTE FUNCTION notificar_nuevo_historial()                                               | notificar_nuevo_historial           | public          | O             |
| public      | perfiles         | trigger_nuevo_usuario_admin       | CREATE TRIGGER trigger_nuevo_usuario_admin AFTER INSERT ON perfiles FOR EACH ROW EXECUTE FUNCTION notificar_nuevo_usuario_admin()                                                         | notificar_nuevo_usuario_admin       | public          | O             |
| public      | reservas         | trigger_notificar_cambio_reserva  | CREATE TRIGGER trigger_notificar_cambio_reserva AFTER UPDATE OF estado ON reservas FOR EACH ROW WHEN (old.estado IS DISTINCT FROM new.estado) EXECUTE FUNCTION notificar_cambio_reserva() | notificar_cambio_reserva            | public          | O             |
| public      | reservas         | trigger_nueva_reserva_admin       | CREATE TRIGGER trigger_nueva_reserva_admin AFTER INSERT ON reservas FOR EACH ROW EXECUTE FUNCTION notificar_nueva_reserva_admin()                                                         | notificar_nueva_reserva_admin       | public          | O             |
| public      | reservas         | trigger_nueva_reserva_veterinario | CREATE TRIGGER trigger_nueva_reserva_veterinario AFTER INSERT ON reservas FOR EACH ROW EXECUTE FUNCTION notificar_nueva_reserva_veterinario()                                             | notificar_nueva_reserva_veterinario | public          | O             |
---

## 12. Publicaciones Realtime

**Qué devuelve:** publicaciones y tablas incluidas (Supabase suele usar `supabase_realtime`); permite confirmar qué tablas emiten eventos `postgres_changes`.
**Permisos:** la lectura de `pg_publication*` suele estar disponible, pero puede variar según el rol.

```sql
-- 12. Publicaciones Realtime y tablas publicadas
SELECT
  p.pubname AS publication_name,
  p.puballtables,
  p.pubinsert,
  p.pubupdate,
  p.pubdelete,
  p.pubtruncate,
  pt.schemaname AS schema_name,
  pt.tablename  AS table_name
FROM pg_publication p
LEFT JOIN pg_publication_tables pt ON pt.pubname = p.pubname
WHERE pt.schemaname = 'public' OR pt.schemaname IS NULL
ORDER BY p.pubname, pt.schemaname, pt.tablename;
```
| publication_name  | puballtables | pubinsert | pubupdate | pubdelete | pubtruncate | schema_name | table_name       |
| ----------------- | ------------ | --------- | --------- | --------- | ----------- | ----------- | ---------------- |
| supabase_realtime | false        | true      | true      | true      | true        | public      | consultas        |
| supabase_realtime | false        | true      | true      | true      | true        | public      | historial_medico |
| supabase_realtime | false        | true      | true      | true      | true        | public      | mascotas         |
| supabase_realtime | false        | true      | true      | true      | true        | public      | notificaciones   |
| supabase_realtime | false        | true      | true      | true      | true        | public      | perfiles         |
| supabase_realtime | false        | true      | true      | true      | true        | public      | productos        |
| supabase_realtime | false        | true      | true      | true      | true        | public      | reservas         |
| supabase_realtime | false        | true      | true      | true      | true        | public      | servicios        |
| supabase_realtime | false        | true      | true      | true      | true        | public      | vacunas          |
```sql
-- 12b. Verificación rápida: tablas de interés para la app en publicaciones
SELECT pubname, schemaname, tablename
FROM pg_publication_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'perfiles','mascotas','reservas','historial_medico',
    'consultas','notificaciones','productos','servicios'
  )
ORDER BY tablename, pubname;
```
| pubname           | schemaname | tablename        |
| ----------------- | ---------- | ---------------- |
| supabase_realtime | public     | consultas        |
| supabase_realtime | public     | historial_medico |
| supabase_realtime | public     | mascotas         |
| supabase_realtime | public     | notificaciones   |
| supabase_realtime | public     | perfiles         |
| supabase_realtime | public     | productos        |
| supabase_realtime | public     | reservas         |
| supabase_realtime | public     | servicios        |
---

## 13. Roles y permisos relevantes

**Qué devuelve:** roles de BD visibles y privilegios de tabla/función en `public` (útil para revisar el acceso de `anon`, `authenticated`, `service_role`, etc.).
**Permisos/sensibilidad:** no consulta contraseñas ni hashes (no se usa `pg_authid`), pero expone configuración de roles y grants; puede requerir privilegios para ver todo.
**Nota:** en Supabase, RLS y grants trabajan juntos.

```sql
-- 13. Roles disponibles (sin credenciales)
SELECT
  rolname,
  rolsuper,
  rolinherit,
  rolcreaterole,
  rolcreatedb,
  rolcanlogin,
  rolreplication,
  rolbypassrls
FROM pg_roles
ORDER BY rolname;
```
| rolname                     | rolsuper | rolinherit | rolcreaterole | rolcreatedb | rolcanlogin | rolreplication | rolbypassrls |
| --------------------------- | -------- | ---------- | ------------- | ----------- | ----------- | -------------- | ------------ |
| anon                        | false    | true       | false         | false       | false       | false          | false        |
| authenticated               | false    | true       | false         | false       | false       | false          | false        |
| authenticator               | false    | false      | false         | false       | true        | false          | false        |
| dashboard_user              | false    | true       | true          | true        | false       | true           | false        |
| pg_checkpoint               | false    | true       | false         | false       | false       | false          | false        |
| pg_create_subscription      | false    | true       | false         | false       | false       | false          | false        |
| pg_database_owner           | false    | true       | false         | false       | false       | false          | false        |
| pg_execute_server_program   | false    | true       | false         | false       | false       | false          | false        |
| pg_maintain                 | false    | true       | false         | false       | false       | false          | false        |
| pg_monitor                  | false    | true       | false         | false       | false       | false          | false        |
| pg_read_all_data            | false    | true       | false         | false       | false       | false          | false        |
| pg_read_all_settings        | false    | true       | false         | false       | false       | false          | false        |
| pg_read_all_stats           | false    | true       | false         | false       | false       | false          | false        |
| pg_read_server_files        | false    | true       | false         | false       | false       | false          | false        |
| pg_signal_backend           | false    | true       | false         | false       | false       | false          | false        |
| pg_stat_scan_tables         | false    | true       | false         | false       | false       | false          | false        |
| pg_use_reserved_connections | false    | true       | false         | false       | false       | false          | false        |
| pg_write_all_data           | false    | true       | false         | false       | false       | false          | false        |
| pg_write_server_files       | false    | true       | false         | false       | false       | false          | false        |
| pgbouncer                   | false    | true       | false         | false       | true        | false          | false        |
| postgres                    | false    | true       | true          | true        | true        | true           | true         |
| service_role                | false    | true       | false         | false       | false       | false          | true         |
| supabase_admin              | true     | true       | true          | true        | true        | true           | true         |
| supabase_auth_admin         | false    | false      | true          | false       | true        | false          | false        |
| supabase_etl_admin          | false    | true       | false         | false       | true        | true           | true         |
| supabase_privileged_role    | false    | true       | false         | false       | false       | false          | false        |
| supabase_read_only_user     | false    | true       | false         | false       | true        | false          | true         |
| supabase_realtime_admin     | false    | false      | false         | false       | false       | false          | false        |
| supabase_replication_admin  | false    | true       | false         | false       | true        | true           | false        |
| supabase_storage_admin      | false    | false      | true          | false       | true        | false          | false        |
```sql
-- 13b. Privilegios sobre tablas en public
SELECT
  table_schema,
  table_name,
  grantee,
  string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
GROUP BY table_schema, table_name, grantee
ORDER BY table_name, grantee;
```
| table_schema | table_name       | grantee       | privileges                                                    |
| ------------ | ---------------- | ------------- | ------------------------------------------------------------- |
| public       | citas            | authenticated | SELECT                                                        |
| public       | citas            | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | citas            | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | consultas        | authenticated | INSERT, SELECT                                                |
| public       | consultas        | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | consultas        | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | historial_medico | authenticated | INSERT, SELECT                                                |
| public       | historial_medico | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | historial_medico | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | mascotas         | authenticated | INSERT, SELECT, UPDATE                                        |
| public       | mascotas         | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | mascotas         | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | notificaciones   | authenticated | SELECT                                                        |
| public       | notificaciones   | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | notificaciones   | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | perfiles         | authenticated | SELECT                                                        |
| public       | perfiles         | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | perfiles         | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | productos        | anon          | SELECT                                                        |
| public       | productos        | authenticated | SELECT                                                        |
| public       | productos        | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | productos        | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | reservas         | authenticated | INSERT, SELECT                                                |
| public       | reservas         | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | reservas         | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | servicios        | anon          | SELECT                                                        |
| public       | servicios        | authenticated | SELECT                                                        |
| public       | servicios        | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | servicios        | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | vacunas          | authenticated | SELECT                                                        |
| public       | vacunas          | postgres      | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
| public       | vacunas          | service_role  | DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE |
```sql
-- 13c. Privilegios sobre funciones/RPC en public
SELECT
  routine_schema,
  routine_name,
  grantee,
  string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public'
GROUP BY routine_schema, routine_name, grantee
ORDER BY routine_name, grantee;
```
| routine_schema | routine_name                        | grantee       | privileges |
| -------------- | ----------------------------------- | ------------- | ---------- |
| public         | actualizar_stock_producto_admin     | authenticated | EXECUTE    |
| public         | actualizar_stock_producto_admin     | postgres      | EXECUTE    |
| public         | actualizar_stock_producto_admin     | service_role  | EXECUTE    |
| public         | cambiar_estado_consulta             | authenticated | EXECUTE    |
| public         | cambiar_estado_consulta             | postgres      | EXECUTE    |
| public         | cambiar_estado_consulta             | service_role  | EXECUTE    |
| public         | cambiar_estado_producto_admin       | authenticated | EXECUTE    |
| public         | cambiar_estado_producto_admin       | postgres      | EXECUTE    |
| public         | cambiar_estado_producto_admin       | service_role  | EXECUTE    |
| public         | cambiar_estado_reserva_admin        | authenticated | EXECUTE    |
| public         | cambiar_estado_reserva_admin        | postgres      | EXECUTE    |
| public         | cambiar_estado_reserva_admin        | service_role  | EXECUTE    |
| public         | cambiar_estado_servicio_admin       | authenticated | EXECUTE    |
| public         | cambiar_estado_servicio_admin       | postgres      | EXECUTE    |
| public         | cambiar_estado_servicio_admin       | service_role  | EXECUTE    |
| public         | cambiar_rol_usuario                 | authenticated | EXECUTE    |
| public         | cambiar_rol_usuario                 | postgres      | EXECUTE    |
| public         | cambiar_rol_usuario                 | service_role  | EXECUTE    |
| public         | crear_perfil_usuario                | postgres      | EXECUTE    |
| public         | crear_perfil_usuario                | service_role  | EXECUTE    |
| public         | crear_producto_admin                | authenticated | EXECUTE    |
| public         | crear_producto_admin                | postgres      | EXECUTE    |
| public         | crear_producto_admin                | service_role  | EXECUTE    |
| public         | editar_producto_admin               | authenticated | EXECUTE    |
| public         | editar_producto_admin               | postgres      | EXECUTE    |
| public         | editar_producto_admin               | service_role  | EXECUTE    |
| public         | es_administrador                    | authenticated | EXECUTE    |
| public         | es_administrador                    | postgres      | EXECUTE    |
| public         | es_administrador                    | service_role  | EXECUTE    |
| public         | guardar_servicio_admin              | authenticated | EXECUTE    |
| public         | guardar_servicio_admin              | postgres      | EXECUTE    |
| public         | guardar_servicio_admin              | service_role  | EXECUTE    |
| public         | listar_mascotas_admin               | authenticated | EXECUTE    |
| public         | listar_mascotas_admin               | postgres      | EXECUTE    |
| public         | listar_mascotas_admin               | service_role  | EXECUTE    |
| public         | listar_perfiles_admin               | authenticated | EXECUTE    |
| public         | listar_perfiles_admin               | postgres      | EXECUTE    |
| public         | listar_perfiles_admin               | service_role  | EXECUTE    |
| public         | listar_productos_admin              | authenticated | EXECUTE    |
| public         | listar_productos_admin              | postgres      | EXECUTE    |
| public         | listar_productos_admin              | service_role  | EXECUTE    |
| public         | listar_reservas_admin               | authenticated | EXECUTE    |
| public         | listar_reservas_admin               | postgres      | EXECUTE    |
| public         | listar_reservas_admin               | service_role  | EXECUTE    |
| public         | listar_servicios_admin              | authenticated | EXECUTE    |
| public         | listar_servicios_admin              | postgres      | EXECUTE    |
| public         | listar_servicios_admin              | service_role  | EXECUTE    |
| public         | notificar_cambio_reserva            | postgres      | EXECUTE    |
| public         | notificar_cambio_reserva            | service_role  | EXECUTE    |
| public         | notificar_consulta_atendida         | PUBLIC        | EXECUTE    |
| public         | notificar_consulta_atendida         | postgres      | EXECUTE    |
| public         | notificar_consulta_atendida         | service_role  | EXECUTE    |
| public         | notificar_nueva_consulta_admin      | PUBLIC        | EXECUTE    |
| public         | notificar_nueva_consulta_admin      | postgres      | EXECUTE    |
| public         | notificar_nueva_consulta_admin      | service_role  | EXECUTE    |
| public         | notificar_nueva_reserva_admin       | postgres      | EXECUTE    |
| public         | notificar_nueva_reserva_admin       | service_role  | EXECUTE    |
| public         | notificar_nueva_reserva_veterinario | postgres      | EXECUTE    |
| public         | notificar_nueva_reserva_veterinario | service_role  | EXECUTE    |
| public         | notificar_nuevo_historial           | postgres      | EXECUTE    |
| public         | notificar_nuevo_historial           | service_role  | EXECUTE    |
| public         | notificar_nuevo_usuario_admin       | postgres      | EXECUTE    |
| public         | notificar_nuevo_usuario_admin       | service_role  | EXECUTE    |
| public         | obtener_estadisticas_admin          | authenticated | EXECUTE    |
| public         | obtener_estadisticas_admin          | postgres      | EXECUTE    |
| public         | obtener_estadisticas_admin          | service_role  | EXECUTE    |
| public         | obtener_reportes_admin              | authenticated | EXECUTE    |
| public         | obtener_reportes_admin              | postgres      | EXECUTE    |
| public         | obtener_reportes_admin              | service_role  | EXECUTE    |
---

## 14. Tipos ENUM personalizados

**Qué devuelve:** tipos `ENUM` definidos por el usuario y sus valores (útil si estados como reserva/consulta/rol se modelan como enum).

```sql
-- 14. Tipos ENUM y valores
SELECT
  n.nspname AS schema_name,
  t.typname AS enum_name,
  e.enumsortorder AS sort_order,
  e.enumlabel AS enum_value
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
JOIN pg_namespace n ON n.oid = t.typnamespace
ORDER BY n.nspname, t.typname, e.enumsortorder;
```
| schema_name | enum_name                  | sort_order | enum_value                 |
| ----------- | -------------------------- | ---------- | -------------------------- |
| auth        | aal_level                  | 1          | aal1                       |
| auth        | aal_level                  | 2          | aal2                       |
| auth        | aal_level                  | 3          | aal3                       |
| auth        | code_challenge_method      | 1          | s256                       |
| auth        | code_challenge_method      | 2          | plain                      |
| auth        | factor_status              | 1          | unverified                 |
| auth        | factor_status              | 2          | verified                   |
| auth        | factor_type                | 1          | totp                       |
| auth        | factor_type                | 2          | webauthn                   |
| auth        | factor_type                | 3          | phone                      |
| auth        | factor_type                | 4          | recovery_code              |
| auth        | oauth_authorization_status | 1          | pending                    |
| auth        | oauth_authorization_status | 2          | approved                   |
| auth        | oauth_authorization_status | 3          | denied                     |
| auth        | oauth_authorization_status | 4          | expired                    |
| auth        | oauth_client_type          | 1          | public                     |
| auth        | oauth_client_type          | 2          | confidential               |
| auth        | oauth_registration_type    | 1          | dynamic                    |
| auth        | oauth_registration_type    | 2          | manual                     |
| auth        | oauth_response_type        | 1          | code                       |
| auth        | one_time_token_type        | 1          | confirmation_token         |
| auth        | one_time_token_type        | 2          | reauthentication_token     |
| auth        | one_time_token_type        | 3          | recovery_token             |
| auth        | one_time_token_type        | 4          | email_change_token_new     |
| auth        | one_time_token_type        | 5          | email_change_token_current |
| auth        | one_time_token_type        | 6          | phone_change_token         |
| realtime    | action                     | 1          | INSERT                     |
| realtime    | action                     | 2          | UPDATE                     |
| realtime    | action                     | 3          | DELETE                     |
| realtime    | action                     | 4          | TRUNCATE                   |
| realtime    | action                     | 5          | ERROR                      |
| realtime    | equality_op                | 1          | eq                         |
| realtime    | equality_op                | 2          | neq                        |
| realtime    | equality_op                | 3          | lt                         |
| realtime    | equality_op                | 4          | lte                        |
| realtime    | equality_op                | 5          | gt                         |
| realtime    | equality_op                | 6          | gte                        |
| realtime    | equality_op                | 7          | in                         |
| realtime    | equality_op                | 8          | like                       |
| realtime    | equality_op                | 9          | ilike                      |
| realtime    | equality_op                | 10         | is                         |
| realtime    | equality_op                | 11         | match                      |
| realtime    | equality_op                | 12         | imatch                     |
| realtime    | equality_op                | 13         | isdistinct                 |
| storage     | buckettype                 | 1          | STANDARD                   |
| storage     | buckettype                 | 2          | ANALYTICS                  |
| storage     | buckettype                 | 3          | VECTOR                     |
---

## 15. Otras estructuras relevantes

### 15.1 Extensiones instaladas

**Qué devuelve:** extensiones disponibles en la BD (p.ej. `pgcrypto`, `uuid-ossp`).

```sql
-- 15.1 Extensiones instaladas
SELECT extname, extversion, n.nspname AS schema_name
FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace
ORDER BY extname;
```
| extname            | extversion | schema_name |
| ------------------ | ---------- | ----------- |
| pg_stat_statements | 1.11       | extensions  |
| pgcrypto           | 1.3        | extensions  |
| plpgsql            | 1.0        | pg_catalog  |
| supabase_vault     | 0.3.1      | vault       |
| uuid-ossp          | 1.1        | extensions  |
### 15.2 Vistas en `public`

**Qué devuelve:** vistas y su definición (no observadas explícitamente en el código, pero útiles para la auditoría).

```sql
-- 15.2 Vistas en public
SELECT
  table_schema,
  table_name AS view_name,
  view_definition
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;
```
Success. No rows returned


### 15.3 Columnas identity/serial (IDs autogenerados)

**Qué devuelve:** columnas con default `nextval` o identidad generadas.

```sql
-- 15.3 Columnas identity/serial-related defaults
SELECT
  table_schema,
  table_name,
  column_name,
  column_default,
  is_identity,
  identity_generation
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    column_default LIKE 'nextval%'
    OR is_identity = 'YES'
  )
ORDER BY table_name, ordinal_position;
```
| table_schema | table_name       | column_name | column_default | is_identity | identity_generation |
| ------------ | ---------------- | ----------- | -------------- | ----------- | ------------------- |
| public       | citas            | id          | null           | YES         | ALWAYS              |
| public       | consultas        | id          | null           | YES         | ALWAYS              |
| public       | historial_medico | id          | null           | YES         | ALWAYS              |
| public       | mascotas         | id          | null           | YES         | ALWAYS              |
| public       | notificaciones   | id          | null           | YES         | ALWAYS              |
| public       | productos        | id          | null           | YES         | ALWAYS              |
| public       | reservas         | id          | null           | YES         | ALWAYS              |
| public       | servicios        | id          | null           | YES         | ALWAYS              |
| public       | vacunas          | id          | null           | YES         | ALWAYS              |
### 15.4 Constraints UNIQUE (además de PK)

**Qué devuelve:** restricciones de unicidad que pueden afectar la lógica de negocio (emails, códigos, etc.).

```sql
-- 15.4 Restricciones UNIQUE
SELECT
  tc.table_schema,
  tc.table_name,
  tc.constraint_name,
  string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'public'
  AND tc.constraint_type = 'UNIQUE'
GROUP BY tc.table_schema, tc.table_name, tc.constraint_name
ORDER BY tc.table_name, tc.constraint_name;
```
Success. No rows returned


### 15.5 Comentarios de tablas (documentación en BD)

**Qué devuelve:** comentarios almacenados en la BD, si existen.

```sql
-- 15.5 Comentarios de tablas
SELECT
  n.nspname AS schema_name,
  c.relname AS table_name,
  obj_description(c.oid, 'pg_class') AS comment
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p', 'v')
  AND obj_description(c.oid, 'pg_class') IS NOT NULL
ORDER BY c.relname;
```
Success. No rows returned


---

## Checklist de ejecución recomendado

1. Ejecutar las secciones **1–4** para confirmar tablas y relaciones reales.
2. Ejecutar **5–7** para constraints, defaults e índices.
3. Ejecutar **8–9** para RLS y **10–11** (incluida 10b) para funciones/RPCs y triggers (clave para `cambiar_estado_consulta`, la generación de notificaciones, etc.).
4. Ejecutar **12** (y 12b) para Realtime y **14** para ENUMs.
5. Ejecutar **13** y **15** para permisos y estructuras complementarias.
6. Guardar los resultados (CSV/JSON/capturas) y contrastarlos con `AUDITORIA_TECNICA_PETCARE.md`.

> Si alguna consulta falla por permisos, anótalo como "no verificable con el rol actual" y ejecútala con un rol con acceso a los catálogos (p.ej. el SQL Editor del proyecto Supabase).
