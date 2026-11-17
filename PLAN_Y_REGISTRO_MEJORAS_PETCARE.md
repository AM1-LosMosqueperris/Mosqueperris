# Plan y Registro de Mejoras — PetCare Santa Cruz

> **Documento de seguimiento** del proceso de corrección y mejora controlada del proyecto.
> **Alcance:** etapas 1 a 6 definidas en el plan de trabajo aprobado.
> **Regla operativa:** ninguna etapa avanza sin confirmación del usuario. El SQL siempre lo ejecuta el usuario manualmente en Supabase SQL Editor; el asistente **nunca** ejecuta SQL ni operaciones remotas.

---

## 0. Estado general

| Etapa | Alcance | SQL | Cambios Dart | Pruebas | Estado |
|---|---|---|---|---|---|
| **1** | Permisos y funcionamiento de reservas y notificaciones | ✅ Ejecutado por el usuario | ✅ Aplicados | ⚠️ `flutter analyze` OK · pruebas en app pendientes | 🟡 **Código listo, faltan pruebas manuales** |
| **2** | Fechas y horarios (UTC-4 Santa Cruz) | ✅ Opción A ejecutada y verificada (T1–T4) | ✅ Opción A aplicada (E2.3/E2.7/E2.8/E2.9) | ⚠️ `flutter analyze` OK · falta prueba en app | 🟡 **Opción A lista, falta prueba end-to-end** |
| **3** | Atención de reservas transaccional por veterinario | ✅ Ejecutado y verificado (V3-1/V3-2) | ✅ Implementado con fallback al flujo original | ⏳ | 🟢 **Lista, falta prueba en app** |
| **4** | Clasificación y asignación de consultas | ⏳ Pendiente | ⏳ Pendiente | ⏳ | ⚪ No iniciada |
| **5** | Respuestas personalizadas y conversación | ⏳ Pendiente | ⏳ Pendiente | ⏳ | ⚪ No iniciada |
| **6** | Seguridad, rendimiento y revisión general | ⏳ Pendiente | ⏳ Pendiente | ⏳ | ⚪ No iniciada |

**Documentos de referencia:**
- `AUDITORIA_TECNICA_PETCARE.md` — auditoría completa con contraste código ↔ esquema real.
- `CONSULTAS_SQL_AUDITORIA_SUPABASE.md` — consultas de auditoría con resultados ya ejecutados.

---

# ETAPA 1 — Permisos y funcionamiento de reservas y notificaciones

## 1.1 Problemas detectados

| ID | Severidad | Problema |
|---|---|---|
| P1.1 | 🔴 Crítica | `GRANT UPDATE` ausente en `public.reservas` (`authenticated` solo tenía `INSERT, SELECT`). Las policies RLS de UPDATE existían y eran correctas, pero **inertes**: en Postgres el privilegio de tabla se evalúa antes que RLS, así que las escrituras se rechazaban con `42501 permission denied`. Afectaba a: cancelar reserva (cliente), confirmar/cancelar (veterinario) y marcar cita como atendida (veterinario). |
| P1.2 | 🔴 Crítica | `GRANT UPDATE` ausente en `public.notificaciones` (`authenticated` solo tenía `SELECT`). "Marcar como leída" y "marcar todas como leídas" fallaban en los **tres roles** → el badge de la campanita nunca bajaba a 0. |
| P1.3 | 🟠 Media | La policy de cancelación del cliente no exigía que la reserva estuviera `Pendiente`. La UI sí lo exigía, la base de datos no → un cliente podía cancelar vía API una reserva ya atendida. |
| P1.4 | 🟠 Media | La policy del veterinario no restringía las transiciones de estado: podía llevar una cita de `Atendida` a `Pendiente` (reabrirla). |
| P1.5 | 🟡 Baja | `marcarComoLeida` filtraba solo por `id`, sin `usuario_id` → sin defensa en profundidad y sin aprovechar el índice `(usuario_id, created_at)`. |
| P1.6 | 🟡 Baja | `cambiarEstado` del veterinario no condicionaba el estado previo → riesgo de pisar una reserva que cambió de estado entre el render y el click. |
| P1.7 | 🟡 Baja | Tres tipos de notificación generados por triggers (`reserva_admin`, `reserva_veterinario`, `usuario_nuevo`) no estaban contemplados en la UI → caían en el icono genérico naranja. |

## 1.2 Archivos afectados

| Archivo | Cambio | Riesgo |
|---|---|---|
| `lib/features/notificaciones/screens/notificaciones.dart` | `marcarComoLeida`: añadir `.eq('usuario_id', usuario.id)` y `.select('id')` con detección de 0 filas | Bajo |
| `lib/features/notificaciones/screens/notificaciones.dart` | `marcarTodasComoLeidas`: añadir `.select('id')` con detección de 0 filas | Bajo |
| `lib/features/notificaciones/screens/notificaciones.dart` | `iconoTipo` / `colorTipo`: añadir `reserva_admin`, `reserva_veterinario`, `usuario_nuevo` | Bajo |
| `lib/features/veterinario/screens/citas_veterinario.dart` | `cambiarEstado`: añadir `.eq('estado','Pendiente')` y `.select('id')` con detección de 0 filas | Bajo |

**Archivos revisados y NO modificados** (ya correctos):
`lib/features/cliente/screens/reservas_citas.dart` (el cancel ya filtra por `usuario_id` y la UI ya exige `Pendiente`), `lib/features/administrador/screens/gestion_reservas_admin.dart` (usa RPC `cambiar_estado_reserva_admin`), `lib/features/cliente/screens/inicio.dart`, `lib/features/veterinario/screens/panel_veterinario.dart`, `lib/features/administrador/screens/panel_administrador.dart` (solo hacen `SELECT`).

## 1.3 Funcionalidad original (preservada)

- El cliente sigue cancelando **sus propias** reservas mediante el botón "Cancelar reserva", que solo aparece con estado `Pendiente`.
- El veterinario sigue confirmando y cancelando citas, y atendiendo citas confirmadas.
- El administrador sigue gestionando reservas mediante la RPC `cambiar_estado_reserva_admin` (ruta intacta, no dependía del `GRANT UPDATE`).
- Los tres roles siguen consultando, filtrando y marcando leídas sus notificaciones.
- **Ningún trigger, RPC, tabla, columna, ruta o pantalla fue eliminada, renombrada ni reemplazada.**

## 1.4 Cambios realizados

### Cambios en Supabase (SQL ejecutado por el usuario)

```sql
-- SQL-1 (URGENTE) — Permisos mínimos de UPDATE a nivel de COLUMNA
GRANT UPDATE (estado) ON public.reservas TO authenticated;
GRANT UPDATE (leida) ON public.notificaciones TO authenticated;

-- SQL-2 — Exigir 'Pendiente' para poder cancelar
DROP POLICY IF EXISTS "Usuarios pueden cancelar sus reservas" ON public.reservas;
CREATE POLICY "Usuarios pueden cancelar sus reservas"
  ON public.reservas FOR UPDATE TO authenticated
  USING (auth.uid() = usuario_id AND estado = 'Pendiente')
  WITH CHECK (auth.uid() = usuario_id AND estado = 'Cancelada');

-- SQL-3 — Alinear transiciones del veterinario con la UI
DROP POLICY IF EXISTS "Veterinarios pueden actualizar reservas" ON public.reservas;
CREATE POLICY "Veterinarios pueden actualizar reservas"
  ON public.reservas FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.perfiles p
            WHERE p.id = auth.uid() AND p.rol = 'veterinario')
    AND estado IN ('Pendiente', 'Confirmada')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.perfiles p
            WHERE p.id = auth.uid() AND p.rol = 'veterinario')
    AND estado IN ('Confirmada', 'Cancelada', 'Atendida')
  );
```

**Efectivo por actor tras el cambio:**

| Actor | Puede | No puede |
|---|---|---|
| Cliente | `UPDATE` de `estado` en sus propias reservas `Pendiente` → `Cancelada` | Modificar `nombre`, `telefono`, `fecha`, `hora`, `mascota_id`, `usuario_id`, `servicio`, `comentario`, `personas`; tocar reservas ajenas; reabrir citas |
| Veterinario | `UPDATE` de `estado`: `Pendiente`→`Confirmada`/`Cancelada`, `Confirmada`→`Atendida` | Reabrir (`→'Pendiente'`) o modificar citas ya cerradas; tocar datos personales de la reserva |
| Administrador | Cualquier estado vía RPC `cambiar_estado_reserva_admin` (SECURITY DEFINER, omite RLS) | — |
| Cualquiera | `UPDATE` de `leida` en sus propias notificaciones | Marcar como leída la notificación de otro usuario |

### Cambios en Dart

**`lib/features/notificaciones/screens/notificaciones.dart`**

1. `marcarComoLeida` — ahora filtra por `usuario_id` (defensa en profundidad) y usa `.select('id')` para detectar si 0 filas fueron afectadas (cambio de estado en otra sesión) → en ese caso recarga la lista en lugar de mostrar un error falso:
   ```dart
   final respuesta = await supabase
       .from('notificaciones')
       .update({'leida': true})
       .eq('id', notificacion['id'])
       .eq('usuario_id', usuario.id)
       .select('id');

   if (respuesta.isEmpty) {
     await cargarNotificaciones(mostrarCarga: false);
     return;
   }
   ```
2. `marcarTodasComoLeidas` — mismo patrón de detección de 0 filas.
3. `iconoTipo` — nuevos casos:
   - `reserva_admin` → `Icons.admin_panel_settings_outlined`
   - `reserva_veterinario` → `Icons.medical_information_outlined`
   - `usuario_nuevo` → `Icons.person_add_alt_outlined`
4. `colorTipo` — nuevos casos:
   - `reserva_admin` → `Colors.teal`
   - `reserva_veterinario` → `Colors.indigo`
   - `usuario_nuevo` → `Colors.blueGrey`

**`lib/features/veterinario/screens/citas_veterinario.dart`**

`cambiarEstado` — ahora exige que la cita siga `Pendiente` (igual que la UI) y detecta 0 filas afectadas:
```dart
final respuesta = await supabase
    .from('reservas')
    .update({'estado': nuevoEstado})
    .eq('id', reserva['id'])
    .eq('estado', 'Pendiente')
    .select('id');

if (respuesta.isEmpty) {
  await cargarReservas(mostrarCarga: false);
  // SnackBar naranja: "Esta cita ya no esta pendiente. Se actualizo la lista."
  return;
}
```

## 1.5 SQL requerido

| Bloque | Estado | Contenido |
|---|---|---|
| SQL-1 | ✅ **Ejecutado por el usuario** | 2 `GRANT UPDATE` a nivel de columna |
| SQL-2 | ✅ **Ejecutado por el usuario** | Policy de cancelación del cliente endurecida |
| SQL-3 | ✅ **Ejecutado por el usuario** | Policy del veterinario con transiciones restringidas |
| SQL-4 (V1–V3) | ✅ **Ejecutado y verificado** | Grants de columna y policies de UPDATE confirmados |
| SQL-4 (V4–V6) | ⏳ **Pendiente** | Estados presentes, registros huérfanos y publicación Realtime (no bloquean esta etapa) |

## 1.6 Pruebas realizadas

| # | Prueba | Método | Resultado |
|---|---|---|---|
| P1-A | Análisis estático del proyecto | `flutter analyze --no-pub` | ✅ **No issues found!** (2.5 s) |
| P1-B | Baseline previo a los cambios | `flutter analyze --no-pub` | ✅ No issues found! (4.0 s) |
| P1-C | Revisión del diff de los 4 puntos modificados | `git diff` | ✅ Solo se modificaron los puntos previstos; ninguna pantalla, método, consulta, ruta ni nombre fue alterado |
| P1-D | Verificación de catálogos de permisos (resultados ya aportados por el usuario) | `information_schema.role_table_grants` | ✅ `reservas` y `notificaciones` sin `UPDATE` → confirma P1.1 y P1.2 |
| P1-E | Verificación de políticas RLS vigentes (resultados ya aportados) | `pg_policies` | ✅ 22 policies en 9 tablas; confirma P1.3 y P1.4 |
| P1-F | Verificación posterior a aplicar el SQL — V1 (privilegios de tabla) | `information_schema.role_table_grants` | ✅ `reservas` = `INSERT, SELECT`; `notificaciones` = `SELECT` (sin UPDATE de tabla, por diseño) |
| P1-G | Verificación posterior a aplicar el SQL — V2 (privilegios por columna) | `information_schema.column_privileges` | ✅ 2 filas exactas: `notificaciones.leida` → UPDATE, `reservas.estado` → UPDATE |
| P1-H | Verificación posterior a aplicar el SQL — V3 (policies de UPDATE) | `pg_policies` | ✅ 2 policies con las expresiones esperadas: cliente `Pendiente`→`Cancelada`; veterinario `Pendiente/Confirmada`→`Confirmada/Cancelada/Atendida` |
| P1-I | Pruebas funcionales en la app | Manuales en dispositivo/emulador | ⏳ **PENDIENTE — no ejecutadas por el asistente** |

## 1.7 Pruebas manuales pendientes (a ejecutar por el usuario)

| # | Escenario | Resultado esperado |
|---|---|---|
| T1 | Cliente crea una reserva y la cancela | SnackBar verde "Reserva cancelada correctamente." · estado `Cancelada` · notificación "Cita cancelada" recibida |
| T2 | Cliente intenta cancelar una reserva `Atendida` | Botón no visible (UI) y rechazo por API (SQL-2) |
| T3 | Cliente intenta cancelar la reserva de otro cliente | Rechazado |
| T4 | Veterinario confirma una cita pendiente | "Cita confirmada correctamente." · notificación "Cita confirmada" al cliente |
| T5 | Veterinario atiende una cita confirmada | Historial creado + estado `Atendida` · notificación "Cita atendida" |
| T6 | Veterinario intenta modificar una cita `Atendida` | Sin botón en UI y bloqueado en BD (SQL-3) |
| T7 | Administrador cambia el estado desde el panel | Funciona vía RPC |
| T8 | Usuario marca 1 notificación como leída | Sin error rojo · el badge baja en 1 |
| T9 | Usuario pulsa "marcar todas" | Badge a 0 · Snackbar verde |
| T10 | Administrador y veterinario reciben "Nueva reserva" / "Nuevo usuario registrado" | Icono y color propios, no el genérico |
| T11 | Usuario A intenta marcar como leída la notificación de B | Rechazado |

## 1.8 Pendientes y riesgos conocidos

| # | Riesgo / pendiente | Impacto | Mitigación |
|---|---|---|---|
| R1 | La inconsistencia "historial creado + reserva sin cambiar" (P1.1) **sigue latente en diseño** | El `INSERT` en `historial_medico` y el `UPDATE` de la reserva son sentencias separadas con auto-commit. Con el `GRANT` ya aplicado el caso deja de ser fácil de reproduces, pero una caída de red entre ambas deja el historial sin cerrar la cita | **Etapa 3**: RPC transaccional `atender_cita()` |
| R2 | `flutter analyze` es análisis estático, no prueba de integración | No detecta fallos de permisos en runtime | T1–T11 son obligatorias antes de cerrar la Etapa 1 |
| R3 | SQL-4 (V1–V6) no ejecutado | No hay confirmación del estado final de permisos y policies | Ejecutar y pegar resultados |
| R4 | Las policies de `consultas` y `notificaciones` permiten UPDATE a nivel de tabla en su definición, pero el `GRANT` es de columna | Si alguien concediera `GRANT UPDATE` de tabla sobre `consultas`, un cliente podría auto-marcarse una consulta como `Atendida` | Revisar en Etapa 6 (-Endurecer `consultas` con `GRANT UPDATE` de columna o retirar la policy de UPDATE) |
| R5 | El esquema SQL no está versionado en el repositorio | Cambios en BD no son auditables ni reversibles | Versionar migraciones (propuesta en la auditoría, §16 Etapa 2 del plan general) |
| R6 | `ALTER DEFAULT PRIVILEGES` no verificado | Si asigna `ALL` a `authenticated`, **cada tabla nueva nacería con UPDATE** y el problema P1.1/P1.2 se repetiría | Verificar en Etapa 6 (consulta §19.2 de la auditoría) |
| R7 | La app sigue usando `Map<String, dynamic>` | Un campo mal escrito falla en runtime, no en compilación | Modelos tipados en Etapa 6 |

---

# ETAPA 2 — Fechas y horarios (UTC-4, Santa Cruz de la Sierra)

**Estado:** 🟢 **Opción A ejecutada y verificada** (SQL T1–T4 ✅, Dart ✅). Prueba end-to-end en app ⏳.
**Opción B:** ⏳ No iniciada (decisión pendiente).
**Arranque de B:** requiere ETAPA 1 y ETAPA 2 cerradas con pruebas en app confirmadas.

### Causa raíz confirmada (E2.1)

La policy de INSERT de `reservas` evalúa `(fecha + hora) > now()`.
- `fecha` (`date`) + `hora` (`time WITHOUT TIME ZONE`) → PostgreSQL produce un `timestamp WITHOUT TIME ZONE` = **reloj de pared local** que la app envió.
- `now()` es `timestamptz`. En una comparación mixta, PostgreSQL convierte el `timestamp` naive usando el `TimeZone` de la sesión, que en Supabase es **UTC**.

**Álgebra (B = −4, S = 0):** `(W − S) > (N − B)` ⇔ `W > N + (S − B)` = `W > N + 240 min`.

> **La policy no valida "es futuro": valida "faltan al menos 4 h 1 min".**

### Ejemplos medidos (ahora = 16/11 09:00 hora de Santa Cruz)

| Cliente elige | ¿Válido localmente? | ¿La policy acepta? | Veredicto |
|---|---|---|---|
| hoy 16/11 08:00 (pasado) | ❌ | `08:00Z > 13:00Z` → FALSE | Rechazada ✓ (y la app ni lo deja llegar) |
| **hoy 16/11 10:00 (1 h futuro)** | ✅ | `10:00Z > 13:00Z` → **FALSE** | 🔴 **Rechazada — falso negativo** |
| **hoy 16/11 12:00 (3 h futuro)** | ✅ | `12:00Z > 13:00Z` → **FALSE** | 🔴 **Rechazada** |
| **hoy 16/11 13:00 (4 h futuro)** | ✅ | `13:00Z > 13:00Z` → FALSE | 🔴 **Rechazada (borde exacto)** |
| hoy 16/11 13:01 | ✅ | TRUE | ✅ Aceptada ⇒ **anticipación mínima = 4 h 1 min** |
| mañana 17/11 01:00 | ✅ | TRUE | ✅ Aceptada |

**¿Se puede colar una cita en pasado?** Con `TimeZone = UTC`, **no**: `W > N + 4h > N` ⇒ siempre falso el pasado. Es *fail-closed* por accidente, no por diseño. **Sí se colarían** si la sesión de la BD usara `TimeZone ≤ UTC−6`, o si el dispositivo del cliente estuviera en una zona al oeste de UTC (el reloj enviado se vuelve el umbral).

### Hallazgos de la etapa

| # | Severidad | Hallazgo | Evidencia |
|---|---|---|---|
| E2.1 | 🔴 Crítica | La policy exige 4 h de anticipación en vez de "futuro" | Policy §8 + `reservas_citas.dart:486-489` |
| E2.2 | 🔴 Alta | La app envía hora local **naive** (sin offset ni zona) | `reservas_citas.dart:488-489` (`'HH:mm:00'`) |
| E2.3 | 🟠 Media | El `catch` del INSERT muestra el error crudo de PostgreSQL al usuario: `Text('Error al guardar la reserva: $e')` → "new row violates row-level security policy" | `reservas_citas.dart:515-526` ✅ verificado |
| E2.4 | 🟠 Media | **No hay unicidad de slot**: sin índice único ni `EXCLUDE` por (`fecha`,`hora`), y la app no consulta disponibilidad ⇒ N clientes pueden reservar el mismo horario | Índices §7 (solo `reservas_pkey`) |
| E2.5 | 🟡 Baja | Orden sin desempate por `hora` → orden intradía indeterminado | `reservas_citas.dart:178`, `citas_veterinario.dart:67` |
| E2.6 | 🟡 Baja | Orden descendente en las 3 vistas ⇒ las citas de hoy quedan al final de la lista | `reservas_citas.dart:178`, `citas_veterinario.dart:67`, RPC `ORDER BY r.fecha DESC, r.hora DESC` |
| E2.7 | 🟡 Baja | Formato inconsistente en el panel admin: fecha ISO + hora **con segundos** vs `dd/MM/yyyy · HH:MM` en cliente/vet/home | `gestion_reservas_admin.dart:374` vs `reservas_citas.dart:195-196` |
| E2.8 | 🟡 Baja | `DateTime.parse` sin `try/catch` en la lista del cliente → una fila corrupta tumba toda la lista | `reservas_citas.dart:185` |
| E2.9 | 🟡 Baja | **`inicio.dart:181-187`**: el `sort` de `citasFuturas` está **fuera** del `try/catch` del `where` (`:169-178`) → un `fecha`/`hora` malformado lanza `FormatException` no capturado y tumba `_cargarResumen` | `inicio.dart:181-187` ✅ verificado |
| E2.10 | 🟡 Baja | `personas` nunca se envía ⇒ siempre `1`; el CHECK `personas BETWEEN 1 AND 50` es inerte y no hay control de aforo | `reservas_citas.dart:478-490` |
| E2.11 | 🟡 Baja | La app usa la zona **del dispositivo**, no la del negocio (emulador en UTC ⇒ cambia la hora enviada) | `reservas_citas.dart:308,404` |
| E2.12 | 🟡 Baja | No se modela horario de atención: el `TimePicker` permite cualquier hora 0-23, fines de semana incluidos | `reservas_citas.dart:346-373` |
| E2.13 | 🟢 Info | `inicio.dart:173` parsea `'${fecha}T$hora'` **sin** 'Z' ⇒ hora local ⇒ el home del cliente **sí** clasifica bien "próximas citas" | `inicio.dart:168-187` ✅ verificado |
| E2.14 | 🟢 Info | `historial_medico.fecha` es `date` (fecha civil) ⇒ inmune. Todos los demás campos temporales son `date` o `timestamptz` ⇒ **`hora` es el único naive del sistema** | Análisis de columnas §2 |

### Cambios Dart aplicados (riesgo bajo, independientes del SQL)

| # | Hallazgo | Archivo | Cambio |
|---|---|---|---|
| E2.3 | 🟠 | `lib/features/cliente/screens/reservas_citas.dart` | Nuevo `_mensajeErrorReserva(codigo)` + `on PostgrestException` separado del `catch` genérico. Traduce `42501` → "Ese horario ya no está disponible. Elige otra fecha u hora.", `23505` → "Ese horario acaba de ser reservado por otro cliente.", `23502` → "Faltan datos por completar en la reserva." Ya **no** se muestra el error crudo de PostgreSQL al usuario |
| E2.8 | 🟡 | `lib/features/cliente/screens/reservas_citas.dart` | `DateTime.parse` → `Fechas.tryParseFecha` (devuelve `null` en vez de lanzar) ⇒ una fila corrupta ya no tumba toda la lista |
| E2.9 | 🟡 | `lib/features/cliente/screens/inicio.dart` | El filtro y el `sort` de `citasFuturas` usan `Fechas.tryParseFechaHora` ⇒ **cero excepciones posibles**; antes el `sort` estaba fuera del `try/catch` y una fila inválida tumbaba `_cargarResumen` |
| E2.7 | 🟡 | `lib/utils/fechas.dart` (**nuevo**), `citas_veterinario.dart`, `gestion_reservas_admin.dart` | Utilidad centralizada `Fechas` (`tryParseFecha`, `tryParseFechaHora`, `formatearFecha`, `formatearHora`, `formatearFechaHora`, `zonaNegocio`). El panel admin ya no muestra `"2026-11-16 | 14:30:00"` sino `dd/MM/yyyy · HH:MM` como el resto de pantallas |

**Notas de diseño de `Fechas`:**
- Devuelve siempre **hora local** y nunca aplica `toUtc()`: la columna `hora` guarda el reloj de pared local y un `toUtc()` desplazaría la cita 4 h.
- `tryParseFechaHora` es el reemplazo seguro de `DateTime.parse('${fecha}T$hora')` (misma semántica, sin excepciones).
- `zonaNegocio = 'America/La_Paz'` queda centralizada para la Opción B y para la ETAPA 3.

**Verificación:** `flutter analyze` → **No issues found!** (5.2 s).

### Opciones con coste

| | **Opción A** | **Opción B** | **Opción C** |
|---|---|---|---|
| Qué arregla | E2.1 | E2.1 + E2.5 + E2.6 + ambigüedad de zona | E2.1 + E2.4 + E2.10 + E2.12 |
| SQL | ~15 líneas | ~90 líneas | ~200 líneas |
| Flutter | **0 líneas** | 4 archivos | 5 archivos + UI de horarios |
| Riesgo de datos | Nulo | Bajo (aditivo) | Medio |
| Esfuerzo | 5 min | 2-3 h | 1-2 días |

### Recomendación

**Opción A de inmediato** (elimina E2.1 sin tocar Dart ni datos) **→ Opción B como salto de calidad**. La Opción C (horario de atención) encaja mejor en la ETAPA 3 (agenda del veterinario) y **depende** de B, así que B primero no es trabajo perdido.

**Descartado explícitamente:**
- ❌ Enviar la hora con offset a una columna `time` → PostgreSQL la rechazaría o truncaría.
- ❌ Cambiar el `TimeZone` global de la BD → afecta a `now()`, `current_date` y todas las comparaciones existentes.
- ❌ Confiar en `fecha + hora` sin `AT TIME ZONE` para "hoy" / "próximas 24 h".

### Reglas que se respetarán
- **No se alteran las reservas existentes**: el backfill de `fecha_hora` se calcula desde `fecha` + `hora` con la zona del negocio.
- Cambio **aditivo**: `fecha` y `hora` se conservan.
- La app sigue funcionando igual antes y después del SQL.

### SQL de la Opción A (propuesto, NO ejecutado)

```sql
-- A1. Corregir la validación de "cita futura" usando la zona del negocio.
--     now() AT TIME ZONE 'America/La_Paz' devuelve el reloj de pared de Santa Cruz,
--     comparable 1:1 con (fecha + hora).
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
    AND (fecha + hora) > (now() AT TIME ZONE 'America/La_Paz')
  );

-- A2. Índices de soporte para las consultas que la app ya ejecuta.
CREATE INDEX IF NOT EXISTS idx_reservas_usuario_fecha
  ON public.reservas (usuario_id, fecha DESC, hora DESC);

CREATE INDEX IF NOT EXISTS idx_reservas_fecha_hora
  ON public.reservas (fecha DESC, hora DESC);
```

**Notas:** `America/La_Paz` es la zona IANA de Bolivia (UTC−4, sin DST desde 2010) ⇒ offset constante, sin mantenimiento anual. Modifica: 1 policy + 2 índices. Idempotente: sí. No toca datos. No requiere cambios en Flutter.

---
# ETAPA 3 — Atención de reservas transaccional por veterinario

**Estado:** 🟢 **SQL ejecutado y verificado** · Dart implementado con fallback · Prueba en app ⏳.
**Nota sobre permisos:** la RPC quedó con `EXECUTE` para `PUBLIC` (default de PostgreSQL al crear funciones). **No es un riesgo funcional** porque la propia función valida `perfiles.rol = 'veterinario'` antes de actuar. Aun así, por consistencia con las RPCs de administración (que tienen `PUBLIC` revocado), se recomienda añadir el `REVOKE` en la ETAPA 6.
**Objetivo:** eliminar el riesgo **R1** (historial médico registrado + reserva sin cerrar).

## Diagnóstico del flujo actual

`citas_veterinario.dart` → `atenderCita(reserva)` ejecuta **dos escrituras independientes con auto-commit**:

| # | Operación | Archivo:línea | Nota |
|---|---|---|---|
| 1 | `SELECT` de `perfiles` (nombre del veterinario) | `:328-336` | Viaje extra innecesario |
| 2 | `SELECT` de deduplicación en `historial_medico` | `:340-357` | Búsqueda exacta por `(mascota_id, usuario_id, veterinario_id, descripcion, fecha)` |
| 3 | `INSERT` en `historial_medico` | `:337-355` | Solo si no existe duplicado |
| 4 | `UPDATE` de `reservas.estado` → `'Atendida'` | `:360-364` | Condicionado a `eq('estado','Confirmada')` |

### Riesgos confirmados

| # | Severidad | Riesgo | Evidencia |
|---|---|---|---|
| R1 | 🔴 Alta | **Fallo parcial**: si el paso 4 falla (red, timeout, sesión expirada), el paso 3 ya quedó commiteado ⇒ **queda una atención médica registrada con la cita en `'Confirmada'`**. El `catch` muestra un error pero el historial ya existe | `:337-355` y `:360-364`, sentencias separadas |
| R1b | 🟠 Media | **Carrera TOCTOU**: el `SELECT` de deduplicación (paso 2) y el `INSERT` (paso 3) no son atómicos ⇒ dos veterinarios pueden insertar dos registros idénticos a la vez | `:340-357` |
| R1c | 🟠 Media | **Doble atención concurrente**: dos veterinarios pueden abrir la misma cita `'Confirmada'` y ambos pasar los pasos 2-3; el paso 4 usa `eq('estado','Confirmada')` pero no bloquea la fila ⇒ ambos pueden escribir | `:360-364` |
| R1d | 🟡 Baja | La fecha del historial usa la fecha civil **del dispositivo** (`DateTime.now().toIso8601String().substring(0,10)`), no la del negocio | `:350-354`, `:362-364` |
| R1e | 🟡 Baja | El `catch` muestra el error crudo de Postgres al usuario: `'No se pudo registrar la atención: $e'` | `:392-407` |

## Hallazgo nuevo (crítico para el resto del proyecto)

> **E3.1 — Los dos flujos de veterinario usan conjuntos de `tipo` INCOMPATIBLES.**
>
> - `atenderCita` (`citas_veterinario.dart:199-201`) inicializa `tipo` con `reserva['servicio']`, que viene de la lista hardcodeada de `reservas_citas.dart:75-82`:
>   `Consulta veterinaria`, `Vacunación`, `Desparasitación`, `Peluquería`, `Control y seguimiento`, `Laboratorio`
> - `detalle_mascota_veterinario.dart:294-313` usa un desplegable con:
>   `Consulta`, `Vacunación`, `Control`, `Emergencia`, `Otro`
>
> Solo coinciden en `Vacunación`. **Esto invalida el CHECK `historial_medico_tipo_check` propuesto en la auditoría (Anexo A · F2.2)**: con esa restricción, 5 de los 6 servicios fallarían al registrar la atención.
>
> **Decisión pendiente del usuario:** (a) ampliar el CHECK a los 10 valores, (b) mapear los nombres de servicio a los tipos canónicos dentro de la RPC, o (c) normalizar la lista de servicios de `reservas_citas.dart` a los 5 tipos canónicos. La RPC de abajo **no** impone un CHECK de `tipo` (solo exige que no esté vacío) para no romper nada; la decisión se toma aparte.

## Propuesta: RPC transaccional `atender_cita`

Una sola sentencia PL/pgSQL que valida, inserta y cierra la cita **atómicamente**, conservando exactamente la lógica actual (incluida la deduplicación).

| Garantía | Cómo |
|---|---|
| Atomicidad | Un único `INSERT` + `UPDATE` dentro de la misma transacción de la RPC |
| Sin doble atención | `SELECT ... FOR UPDATE` sobre la reserva ⇒ la segunda transacción concurrente no encuentra la fila ya cerrada |
| Rol | Verifica `perfiles.rol = 'veterinario'` del solicitante |
| Estado válido | Exige `estado = 'Confirmada'`; si no, error de negocio claro |
| Deduplicación idéntica | Misma condición que el código actual: `(mascota_id, usuario_id, veterinario_id, descripcion, fecha)` |
| Comportamiento preservado | Si ya existe el duplicado, **no** inserta pero **sí** marca la cita como `'Atendida'` (igual que hoy) |
| Zona del negocio | `fecha` = `(now() AT TIME ZONE 'America/La_Paz')::date` en vez de la fecha del dispositivo |
| Menos viajes | El nombre del veterinario se resuelve en el servidor (elimina el `SELECT` de `perfiles`) |
| Notificaciones intactas | Los triggers `notificar_nuevo_historial` (INSERT) y `notificar_cambio_reserva` (UPDATE) siguen disparándose, ahora en la misma transacción |

### SQL (propuesto, **NO ejecutado**)

```sql
-- ============================================================
-- ETAPA 3 · RPC transaccional para atender citas
-- Crea: public.atender_cita(bigint, text, text, text, text, text, text)
-- No modifica: ninguna tabla, policy, trigger ni función existente
-- Idempotente: sí (CREATE OR REPLACE)
-- ============================================================

CREATE OR REPLACE FUNCTION public.atender_cita(
  p_reserva_id    bigint,
  p_tipo          text,
  p_descripcion   text,
  p_diagnostico   text DEFAULT NULL,
  p_tratamiento   text DEFAULT NULL,
  p_vacuna        text DEFAULT NULL,
  p_observaciones text DEFAULT NULL
)
RETURNS TABLE(historial_id bigint, registro_creado boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_mascota_id      bigint;
    v_usuario_id      uuid;
    v_fecha           date := (now() AT TIME ZONE 'America/La_Paz')::date;
    v_nombre          text;
    v_existente       bigint;
    v_historial       bigint := NULL;
    v_registro_creado boolean := false;
BEGIN
    -- 1) Solo un veterinario registrado puede atender citas.
    IF NOT EXISTS (
        SELECT 1 FROM public.perfiles
        WHERE id = auth.uid() AND rol = 'veterinario'
    ) THEN
        RAISE EXCEPTION 'Solo un veterinario puede atender citas';
    END IF;

    -- 2) Validaciones de entrada.
    IF p_tipo IS NULL OR length(trim(BOTH FROM p_tipo)) = 0 THEN
        RAISE EXCEPTION 'El tipo de atención es obligatorio';
    END IF;

    IF p_descripcion IS NULL OR length(trim(BOTH FROM p_descripcion)) < 3 THEN
        RAISE EXCEPTION 'La descripción de la atención es obligatoria';
    END IF;

    -- 3) Reserva válida, en estado Confirmada y bloqueada contra atenciones simultáneas.
    SELECT r.mascota_id, r.usuario_id
      INTO v_mascota_id, v_usuario_id
      FROM public.reservas r
     WHERE r.id = p_reserva_id
       AND r.estado = 'Confirmada'
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe o no está en estado Confirmada';
    END IF;

    IF v_mascota_id IS NULL OR v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'La reserva no tiene una mascota o un propietario vinculado';
    END IF;

    -- 4) Nombre del veterinario (se resuelve en el servidor).
    SELECT p.nombre INTO v_nombre
      FROM public.perfiles p
     WHERE p.id = auth.uid();

    v_nombre := COALESCE(NULLIF(trim(BOTH FROM v_nombre), ''), 'Veterinario');

    -- 5) Deduplicación: misma condición que usa hoy el cliente.
    SELECT h.id INTO v_existente
      FROM public.historial_medico h
     WHERE h.mascota_id = v_mascota_id
       AND h.usuario_id = v_usuario_id
       AND h.veterinario_id = auth.uid()
       AND h.descripcion = trim(BOTH FROM p_descripcion)
       AND h.fecha = v_fecha
     LIMIT 1;

    IF v_existente IS NULL THEN
        INSERT INTO public.historial_medico (
            usuario_id, mascota_id, veterinario_id, fecha, tipo,
            descripcion, diagnostico, tratamiento, vacuna,
            observaciones, veterinario
        )
        VALUES (
            v_usuario_id,
            v_mascota_id,
            auth.uid(),
            v_fecha,
            trim(BOTH FROM p_tipo),
            trim(BOTH FROM p_descripcion),
            NULLIF(trim(BOTH FROM COALESCE(p_diagnostico, '')), ''),
            NULLIF(trim(BOTH FROM COALESCE(p_tratamiento, '')), ''),
            NULLIF(trim(BOTH FROM COALESCE(p_vacuna, '')), ''),
            NULLIF(trim(BOTH FROM COALESCE(p_observaciones, '')), ''),
            v_nombre
        )
        RETURNING id INTO v_historial;

        v_registro_creado := true;
    ELSE
        -- Ya existía una atención idéntica: no se duplica, pero la cita se cierra igual.
        v_historial := v_existente;
        v_registro_creado := false;
    END IF;

    -- 6) Cerrar la cita en la MISMA transacción.
    UPDATE public.reservas
       SET estado = 'Atendida'
     WHERE id = p_reserva_id;

    RETURN QUERY SELECT v_historial, v_registro_creado;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.atender_cita(bigint, text, text, text, text, text, text) TO authenticated;
```

### Verificación posterior (solo lectura)

```sql
-- V3-1: La función existe con la firma esperada
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS argumentos,
       pg_get_function_result(p.oid)            AS retorno,
       p.prosecdef                              AS security_definer
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'atender_cita';

-- V3-2: Permisos de ejecución
SELECT routine_name, grantee, privilege_type
FROM information_schema.role_routine_grants
WHERE routine_schema = 'public' AND routine_name = 'atender_cita';

-- V3-3: Estado actual de las reservas (para comparar antes/después)
SELECT estado, count(*) FROM public.reservas GROUP BY estado ORDER BY 2 DESC;

-- V3-4: Historial reciente (para verificar que la atención se creó UNA sola vez)
SELECT id, usuario_id, mascota_id, veterinario_id, fecha, tipo, descripcion
FROM public.historial_medico
ORDER BY id DESC LIMIT 10;
```

## Plan de cambio en Dart (tras confirmar el SQL)

`lib/features/veterinario/screens/citas_veterinario.dart` → `atenderCita`:

1. **Añadir** la invocación de la RPC antes del `INSERT` actual.
2. **Mantener** el `INSERT` + `UPDATE` actuales como **ruta de respaldo**: si la RPC responde `42883` (función inexistente) o `PGRST202`, se cae al flujo legacy y se avisa por consola. Esto es necesario porque el esquema **no está versionado** y un entorno nuevo no tendría la RPC.
3. **No eliminar** el flujo actual hasta que la RPC esté verificada en los 3 escenarios.
4. Mensajes de error por código de negocio: `P0001` → mostrar el mensaje de la RPC; resto → mensaje genérico.

## Implementación Dart aplicada (2026-11-16)

`lib/features/veterinario/screens/citas_veterinario.dart` — **el flujo original NO se eliminó**, quedó como ruta de respaldo.

| Elemento | Estado |
|---|---|
| `_registrarAtencionConRpc(...)` | ✅ Nuevo. Invoca `supabase.rpc('atender_cita', ...)`. Devuelve `true` si la RPC ejecutó el registro, `false` si **no existe en el entorno** (códigos `42883`, `42P01`, `PGRST202` o mensaje con `atender_cita` + "no existe"/"not found"). Cualquier otro error se re-lanza |
| `_registrarAtencionFlujoAnterior(...)` | ✅ Nuevo. Contiene el flujo original **idéntico**: `SELECT` de `perfiles`, `SELECT` de deduplicación, `INSERT` en `historial_medico` con `fecha` en formato `YYYY-MM-DD`, y `UPDATE` de `reservas.estado` a `'Atendida'` condicionado a `eq('estado','Confirmada')` |
| `atenderCita(...)` | ✅ Ahora llama primero a la RPC y **solo** cae al flujo anterior si la RPC no está disponible |
| `_mensajeErrorAtencion(PostgrestException)` | ✅ Nuevo. `P0001` → muestra el mensaje de negocio de la RPC (p.ej. *"La reserva no existe o no está en estado Confirmada"*); el resto → mensaje genérico. **Ya no se muestra la excepción cruda de Postgres al usuario** |
| `catch` genérico | ✅ Mensaje genérico en lugar de `'No se pudo registrar la atención: $e'` |

**Comportamiento idéntico con o sin la RPC desplegada.** Por eso el cambio es seguro aunque el SQL todavía no se haya ejecutado.

**Verificación:** `flutter analyze` → **No issues found!** (2.5 s).

### Pruebas previstas

| # | Escenario | Resultado esperado |
|---|---|---|
| T3-1 | Vet atiende una cita `'Confirmada'` | Historial creado **y** estado `'Atendida'`, ambos atómicos · 2 notificaciones ("Nuevo registro médico" + "Cita atendida") |
| T3-2 | Repetir la misma atención (misma descripción, mismo día) | **No** se duplica el historial (`registro_creado = false`) pero la cita **sí** queda `'Atendida'` |
| T3-3 | Un cliente intenta usar la RPC | Error "Solo un veterinario puede atender citas" |
| T3-4 | Atender una cita ya `'Atendida'` o `'Pendiente'` | Error "La reserva no existe o no está en estado Confirmada" |
| T3-5 | Cortar la red a mitad del guardado | **Ninguna** escritura parcial (esto es justamente lo que arregla la RPC) |
| T3-6 | Dos veterinarios atienden la misma cita a la vez | Solo una gana; la otra recibe el error de estado |
| T3-7 | App sin la RPC desplegada (estado actual) | El flujo anterior se ejecuta igual y la consola muestra *"La RPC atender_cita no está disponible en este entorno"* |

---
# ETAPA 4 — Clasificación y asignación de consultas

**Estado:** 🟡 **Decisiones tomadas** (2026-11-16). SQL redactado ⏳; Dart ⏳.

## Decisiones del usuario

| # | Decisión | Valor elegido | Consecuencia técnica |
|---|---|---|---|
| D4.1 | Clasificación de la consulta | `consultas.tipo` con **2 valores**: `'Administrativa'` / `'Veterinaria'`, **default `'Administrativa'`** | `NOT NULL DEFAULT 'Administrativa'` ⇒ el INSERT actual del cliente (que no envía `tipo`) sigue funcionando y cae en la bandeja del admin, que puede reclasificarla |
| D4.2 | Estados de la consulta | **Mantener 2 estados** (`Pendiente` / `Atendida`) + solo el campo `asignado_a` | **No se toca** el CHECK `consultas_estado_check` ni la RPC `cambiar_estado_consulta`. El ciclo se ve por `asignado_a` + `respuesta`: sin asignar → asignada → respondida |
| D4.3 | Visibilidad de las consultas veterinarias sin asignar | **Pool: todos los veterinarios las ven** | Policy de SELECT para vets: `(tipo = 'Veterinaria' AND asignado_a IS NULL) OR asignado_a = auth.uid()`. Las **administrativas sin asignar siguen siendo solo del admin** |
| D4.4 | Registro de la respuesta | **Respuesta única** en `consultas.respuesta` (+ `respondida_por`, `respondida_en`) | El hilo de conversación (`consulta_mensajes`) queda para la ETAPA 5, sin bloquear la ETAPA 4 |

## Requisito de la ETAPA 4 que estas decisiones cubren

> «Un veterinario no puede responder consultas asignadas a otros veterinarios, salvo que exista una autorización específica.»

Se cumple con **auto-reclamación atómica**: cuando un veterinario responde una consulta veterinaria **sin asignar**, la RPC le asigna la consulta (`asignado_a = auth.uid()`) dentro de la misma transacción con `SELECT ... FOR UPDATE`. El segundo veterinario concurrente recibe *"La consulta ya fue atendida"* en lugar de duplicar la respuesta.

## Piezas SQL previstas

| # | Objeto | Tipo | Qué hace |
|---|---|---|---|
| 1 | `consultas` + 5 columnas | `ALTER TABLE` | `tipo`, `asignado_a`, `mascota_id`, `respuesta`, `respondida_por`, `respondida_en` |
| 2 | `consultas_tipo_check` | `CHECK` | `tipo IN ('Administrativa','Veterinaria')` |
| 3 | Policy INSERT del cliente | `DROP`/`CREATE` | Endurece: impide que el cliente inserte `respuesta`/`asignado_a` y valide que `mascota_id` sea suya |
| 4 | Policy SELECT de veterinarios | `CREATE` | Pool + consultas propias |
| 5 | RPC `asignar_consulta` | `CREATE` | Solo admin. Asigna/desasigna y notifica al vet |
| 6 | RPC `responder_consulta` | `CREATE` | Admin o vet (propia o sin asignar). Escribe respuesta, auto-reclama, cierra y notifica |
| 7 | `notificar_consulta_atendida` | `REPLACE` | Ahora incluye el texto de la respuesta (el trigger se conserva) |
| 8 | `notificar_nueva_consulta_admin` | `REPLACE` | Distingue consulta administrativa de veterinaria en el título |
| 9 | `notificar_consulta_asignada` + trigger | `CREATE` | Avisa al veterinario asignado |
| 10 | Índices | `CREATE` | `(tipo, asignado_a)`, `(estado)`, `(usuario_id, created_at DESC)` |

## Plan Dart previsto

| Archivo | Cambio |
|---|---|
| `lib/features/cliente/screens/consultas.dart` | Selector de tipo; selector de mascota (solo si es Veterinaria); envío de `tipo` y `mascota_id`; mostrar la respuesta recibida y a quién fue asignada |
| `lib/features/administrador/screens/gestion_consultas_admin.dart` | Mostrar tipo y asignado; acción **Asignar** (lista de veterinarios vía `listar_perfiles_admin`); acción **Responder** (diálogo → `responder_consulta`) |
| `lib/features/veterinario/screens/consultas_veterinario.dart` | **NUEVO** — bandeja de consultas veterinarias (sin asignar / asignadas a mí / atendidas por mí) + respuesta |
| `lib/features/veterinario/screens/panel_veterinario.dart` | Acceso a la nueva bandeja + badge |
| `lib/features/notificaciones/screens/notificaciones.dart` | Nuevo tipo `consulta_asignada` (icono + color) |

## Pruebas previstas

| # | Escenario | Resultado esperado |
|---|---|---|
| T4-1 | Cliente envía consulta sin elegir tipo | Se crea como `'Administrativa'` (default) · el admin recibe notificación "Nueva consulta" |
| T4-2 | Cliente elige "Veterinaria" y asocia su mascota | Se guarda `tipo='Veterinaria'` y `mascota_id` correcto |
| T4-3 | Cliente intenta asociar la mascota de otro | El INSERT es rechazado por la policy |
| T4-4 | Admin asigna la consulta a un veterinario | `asignado_a` guardado · el vet recibe notificación "Consulta asignada" |
| T4-5 | Vet ve la consulta asignada y responde | `respuesta`, `respondida_por`, `respondida_en` y `estado='Atendida'` |
| T4-6 | Cliente recibe la notificación y lee la respuesta | Texto de la respuesta visible en "Mis consultas" |
| T4-7 | Vet intenta responder una consulta asignada a **otro** | Rechazado: *"No tienes permiso para responder esta consulta"* |
| T4-8 | Dos vets responden a la vez una sin asignar | Solo una gana; la otra recibe *"La consulta ya fue atendida"* |
| T4-9 | Admin clasifica una consulta como Administrativa y la atiende | Flujo administrativo completo sin tocar el vet |
| T4-10 | Consulta administrativa sin asignar | El vet **no** la ve; el admin sí |

---

# ETAPA 5 — Respuestas personalizadas y conversación

**Estado:** ⏳ No iniciada.

### Estado actual verificado
- La tabla `consultas` **no tiene** columna de respuesta, responsable ni marca de tiempo de atención → **no hay duplicación que eliminar**.
- La tabla `consulta_mensajes` **no existe** en la BD.
- El flujo actual del cliente (`consultas.dart`) solo envía `usuario_id`, `nombre`, `telefono`, `mensaje`.

### Elementos a decidir en el diagnóstico de la Etapa 5
- Tabla `consulta_mensajes(id, consulta_id, emisor_id, texto, created_at)` como hilo de conversación, **o** ampliar `consultas` con `respuesta` + `respondida_por` + `respondida_en` (sin tabla nueva).
- Comparación de ambas opciones: protección de mensajes (RLS por participantes), identificación de participantes, estrategia de notificación.
- RPC `responder_consulta(...)` que escriba la respuesta, actualice el estado y notifique al cliente.
- La tabla `consulta_mensajes` se publicaría en `supabase_realtime` para el chat en vivo (requiere `ALTER PUBLICATION`).

---

# ETAPA 6 — Seguridad, rendimiento y revisión general

**Estado:** ⏳ No iniciada.

### Lista de verificación prevista

| # | Ítem | Hallazgo preliminar |
|---|---|---|
| S1 | `ALTER DEFAULT PRIVILEGES` del esquema `public` | Sin verificar — riesgo de que las tablas nuevas nazcan con `UPDATE` completo (riesgo R6) |
| S2 | Trigger `crear_perfil_usuario()` sobre `auth.users` | No aparece en la auditoría (se filtró `event_object_schema='public'`) |
| S3 | Revisar la policy de UPDATE de `consultas` | Hoy es inerte por falta de `GRANT`; si se concediera, un cliente podría auto-marcar su consulta como `Atendida` (riesgo R4) |
| S4 | `EXECUTE` concedido a `PUBLIC` en 2 funciones trigger | `notificar_consulta_atendida` y `notificar_nueva_consulta_admin` |
| S5 | Índices faltantes | `reservas(usuario_id, fecha)`, `consultas(usuario_id, created_at)`, `historial_medico(mascota_id, fecha)`, `mascotas(usuario_id)` |
| S6 | CHECK de estados/tipos | `reservas.estado`, `historial_medico.tipo`, `mascotas.especie`, `mascotas.sexo` — **solo tras comprobar los valores existentes con una consulta previa** |
| S7 | Trigger `notificar_consulta_atendida` sin guarda `usuario_id IS NULL` | Puede abortar la actualización si existe una consulta sin dueño |
| S8 | Modelos Dart tipados | `cita.dart` y `mascota.dart` vacíos; `database_helper.dart` sin implementar; `lib/core/**` y `lib/widgets/` sin archivos |
| S9 | Esquema sin versionar | Crear `supabase/migrations/` |
| S10 | Pruebas de contrato de las 16 RPCs | No existen |

---

## Registro de ejecuciones SQL

| Fecha | Bloque | Ejecutado por | Resultado |
|---|---|---|---|
| 2026-11-16 | SQL-1 (GRANT UPDATE columna) | Usuario | ✅ Ejecutado |
| 2026-11-16 | SQL-2 (policy cancelación cliente) | Usuario | ✅ Ejecutado |
| 2026-11-16 | SQL-3 (policy veterinario) | Usuario | ✅ Ejecutado |
| 2026-11-16 | SQL-4 V1–V3 (verificación de permisos y policies) | Usuario | ✅ Ejecutado y **verificado**: 2 grants de columna + 2 policies correctas |
| 2026-11-16 | Etapa 2 · A1 (policy INSERT con `AT TIME ZONE 'America/La_Paz'`) | Usuario | ✅ **Ejecutado y verificado** (T1 `TimeZone=UTC`, T2 policy con `AT TIME ZONE`, T4 `actual=false` / `corregida=true`) |
| 2026-11-16 | Etapa 2 · A2 (índices `idx_reservas_usuario_fecha`, `idx_reservas_fecha_hora`) | Usuario | ✅ **Ejecutado y verificado** (T3: 3 índices) |
| 2026-11-16 | Etapa 3 · RPC `public.atender_cita(...)` | Usuario | ✅ **Ejecutado y verificado** (V3-1 firma + retorno + `security_definer=true`; V3-2 `authenticated` → `EXECUTE`) |

---

*Registro actualizado el 2026-11-16 tras la ETAPA 1.*
