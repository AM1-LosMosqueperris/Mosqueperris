# 06. Base de datos
## Proyecto: PetCare Santa Cruz

### 1. Introducción

PetCare Santa Cruz utiliza Supabase como plataforma backend y PostgreSQL como sistema de gestión de bases de datos.

La base de datos almacena la información necesaria para administrar usuarios, mascotas, servicios veterinarios, reservas, historiales médicos, productos, consultas y notificaciones.

Su estructura permite organizar la información del sistema y controlar el acceso de acuerdo con los roles de cliente, veterinario y administrador.

### 2. Gestor de base de datos

- **Plataforma:** Supabase.
- **Motor:** PostgreSQL.
- **Autenticación:** Supabase Auth.
- **Seguridad:** Row Level Security (RLS).
- **Actualizaciones en tiempo real:** Supabase Realtime.
- **Automatización:** funciones, procedimientos y triggers de PostgreSQL.

### 3. Tablas principales

#### 3.1. perfiles

Almacena la información de los usuarios registrados y su rol dentro del sistema.

Campos principales:

- `id`: identificador UUID del usuario relacionado con Auth.
- `nombre`: nombre del usuario.
- `rol`: rol asignado (cliente, veterinario o administrador).
- `created_at`: fecha de creación del perfil.

Durante el registro, el backend dispone de un mecanismo automatizado para crear el perfil del usuario.

#### 3.2. mascotas

Almacena la información de las mascotas registradas.

Campos principales:

- `id`: identificador de la mascota.
- `usuario_id`: identificador del usuario propietario.
- `nombre`: nombre de la mascota.
- `especie`: especie.
- `raza`: raza.
- `fecha_nacimiento`: fecha de nacimiento.
- `sexo`: sexo.
- `peso`: peso registrado.
- `observaciones`: información adicional.
- `created_at`: fecha de creación.
- `propietario`: información del propietario.

Los registros se encuentran asociados a sus propietarios mediante el identificador del usuario.

#### 3.3. reservas

Almacena las solicitudes y reservas de servicios veterinarios.

Campos principales:

- `id`: identificador de la reserva.
- `nombre`: nombre asociado a la reserva.
- `telefono`: teléfono de contacto.
- `fecha`: fecha solicitada.
- `hora`: hora solicitada.
- `personas`: cantidad registrada en este campo.
- `created_at`: fecha de creación.
- `usuario_id`: usuario que realiza la reserva.
- `mascota`: información de la mascota.
- `servicio`: servicio solicitado.
- `comentario`: observaciones de la solicitud.
- `estado`: estado de la reserva.
- `mascota_id`: identificador de la mascota relacionada.

Los estados utilizados en la gestión incluyen pendiente, confirmada, atendida y cancelada.

#### 3.4. historial_medico

Almacena los registros médicos de las mascotas.

Campos principales:

- `id`: identificador del registro.
- `usuario_id`: propietario asociado.
- `mascota_id`: mascota relacionada.
- `fecha`: fecha del registro.
- `tipo`: tipo de registro médico.
- `descripcion`: descripción.
- `veterinario`: nombre del veterinario.
- `created_at`: fecha de creación.
- `diagnostico`: diagnóstico.
- `tratamiento`: tratamiento indicado.
- `vacuna`: información de vacuna.
- `observaciones`: información adicional.
- `veterinario_id`: identificador del veterinario responsable.

Los veterinarios pueden incorporar nuevos registros médicos mediante las operaciones autorizadas por el backend.

#### 3.5. servicios

Almacena los servicios veterinarios disponibles.

Campos principales:

- `id`: identificador del servicio.
- `nombre`: nombre del servicio.
- `descripcion`: descripción.
- `precio`: precio.
- `duracion_minutos`: duración del servicio.
- `activo`: disponibilidad del servicio.
- `created_at`: fecha de creación.

El administrador puede crear, editar y cambiar la disponibilidad de los servicios mediante funciones administrativas protegidas.

#### 3.6. notificaciones

Almacena las notificaciones dirigidas a los usuarios.

Campos principales:

- `id`: identificador de la notificación.
- `usuario_id`: usuario destinatario.
- `titulo`: título.
- `mensaje`: contenido.
- `tipo`: tipo de notificación.
- `leida`: indica si fue leída.
- `created_at`: fecha de creación.

Los usuarios pueden consultar sus propias notificaciones y actualizar su estado de lectura.

#### 3.7. consultas

Almacena las consultas enviadas por los clientes mediante el módulo correspondiente.

Campos principales:

- `id`: identificador de la consulta.
- `nombre`: nombre del usuario.
- `telefono`: teléfono de contacto.
- `mensaje`: contenido de la consulta.
- `created_at`: fecha de creación.
- `usuario_id`: identificador del usuario que envía la consulta.
- `estado`: estado de atención de la consulta.

El campo `estado` tiene como valor predeterminado `Pendiente` y contempla los estados `Pendiente` y `Atendida`.

El administrador puede consultar, buscar y revisar las consultas, además de actualizar su estado mediante una función protegida.

#### 3.8. productos

Almacena la información de los productos disponibles en la tienda de PetCare.

Campos principales:

- `id`: identificador del producto.
- `nombre`: nombre del producto.
- `descripcion`: descripción.
- `categoria`: categoría del producto.
- `precio`: precio.
- `stock`: cantidad disponible.
- `imagen_url`: dirección de la imagen del producto.
- `activo`: indica si el producto está disponible en la tienda.
- `created_at`: fecha de creación.

El administrador puede crear y editar productos, actualizar su stock y activar o desactivar su disponibilidad mediante funciones administrativas protegidas.

Los clientes pueden consultar los productos activos desde el módulo de tienda.

#### 3.9. Otras tablas

El proyecto también utiliza las siguientes tablas:

- `citas`: información relacionada con la gestión de citas.
- `vacunas`: información relacionada con las vacunas de las mascotas.

Los campos y relaciones específicos de estas tablas deben consultarse directamente en el esquema de Supabase antes de realizar modificaciones en su documentación.

### 4. Relaciones principales

Las relaciones principales del sistema son:

- Un usuario puede tener varios registros de mascotas.
- Una mascota pertenece a un usuario propietario.
- Una mascota puede tener varios registros en el historial médico.
- Un veterinario puede registrar información médica de distintas mascotas.
- Un usuario puede realizar varias reservas.
- Una reserva puede estar asociada a una mascota.
- Un usuario puede recibir varias notificaciones.
- Un usuario puede enviar varias consultas.
- Los registros médicos identifican al veterinario responsable cuando corresponde.

Estas relaciones permiten mantener organizada la información y asociar los registros con los usuarios correspondientes.

### 5. Seguridad de la base de datos

PetCare utiliza políticas Row Level Security (RLS) para controlar el acceso a la información.

Entre los controles implementados se encuentran:

- Los clientes pueden consultar y gestionar sus propios registros de mascotas de acuerdo con los permisos habilitados.
- Los veterinarios pueden consultar la información necesaria para sus funciones.
- Los veterinarios pueden registrar información médica cuando cumplen las condiciones establecidas por las políticas de seguridad.
- Los clientes pueden consultar sus propias reservas y solicitar su cancelación mediante la actualización permitida del estado.
- Los veterinarios pueden consultar las reservas y actualizar su estado según sus permisos.
- Los administradores utilizan funciones protegidas para las operaciones administrativas.
- Los clientes pueden enviar consultas y consultar sus propios registros.
- Los administradores pueden consultar y cambiar el estado de las consultas mediante funciones autorizadas.
- Los usuarios pueden consultar sus propias notificaciones y actualizar su estado de lectura.
- Los clientes pueden consultar los productos activos y los servicios disponibles.
- Las operaciones administrativas sobre servicios y productos se realizan mediante funciones protegidas del backend.

Las operaciones sensibles no dependen únicamente de las restricciones visuales de la aplicación, ya que también se controlan mediante permisos de PostgreSQL y políticas RLS.

### 6. Funciones y automatizaciones

El backend incorpora funciones y mecanismos de automatización para determinadas operaciones.

Entre ellos se encuentran:

#### 6.1. Funciones relacionadas con usuarios

- `es_administrador`: permite verificar si el usuario autenticado tiene rol de administrador.
- `listar_perfiles_admin`: permite consultar los perfiles para la gestión administrativa.
- `cambiar_rol_usuario`: permite modificar el rol de un usuario mediante una operación protegida.

#### 6.2. Funciones relacionadas con mascotas y reservas

- `listar_mascotas_admin`: permite consultar las mascotas desde el módulo administrativo.
- `listar_reservas_admin`: permite obtener las reservas para su gestión administrativa.
- `cambiar_estado_reserva_admin`: permite actualizar el estado de una reserva mediante permisos administrativos.

#### 6.3. Funciones relacionadas con servicios

- `listar_servicios_admin`: permite consultar los servicios para su administración.
- `guardar_servicio_admin`: permite crear o guardar cambios en los servicios.
- `cambiar_estado_servicio_admin`: permite modificar la disponibilidad de los servicios.

#### 6.4. Funciones relacionadas con consultas

- `cambiar_estado_consulta`: permite actualizar el estado de una consulta mediante una operación administrativa protegida.

#### 6.5. Funciones relacionadas con productos

- `listar_productos_admin`: permite consultar los productos desde el módulo administrativo.
- `crear_producto_admin`: permite registrar nuevos productos.
- `editar_producto_admin`: permite modificar la información de productos existentes.
- `actualizar_stock_producto_admin`: permite actualizar el stock de un producto.
- `cambiar_estado_producto_admin`: permite activar o desactivar productos.

#### 6.6. Funciones relacionadas con estadísticas

- `obtener_estadisticas_admin`: permite obtener indicadores administrativos.
- `obtener_reportes_admin`: permite obtener información estadística para el módulo de reportes.

#### 6.7. Triggers y automatizaciones

El backend dispone de triggers que ejecutan acciones ante determinados eventos:

- Creación de un perfil después del registro de un usuario.
- Generación de notificaciones para el administrador cuando se registra un nuevo usuario.
- Generación de notificaciones administrativas ante nuevas reservas.
- Generación de notificaciones para el veterinario ante nuevas reservas.
- Generación de notificaciones para el cliente cuando se actualiza una reserva.
- Generación de notificaciones para el cliente cuando se incorpora un nuevo registro al historial médico.

Las funciones utilizadas por estos mecanismos tienen permisos de ejecución restringidos, de acuerdo con su finalidad.

### 7. Actualizaciones en tiempo real

Supabase Realtime permite que la aplicación reciba cambios en las tablas que se encuentran habilitadas en la publicación correspondiente y que tienen suscripciones configuradas en las pantallas.

Entre las tablas utilizadas por los módulos con actualizaciones en tiempo real se encuentran:

- `mascotas`
- `reservas`
- `historial_medico`
- `notificaciones`
- `productos`
- `consultas`
- `perfiles`

Este mecanismo permite reflejar cambios en los módulos correspondientes sin depender exclusivamente de una actualización manual de la pantalla.

### 8. Flujo de acceso a los datos

1. El usuario inicia sesión en la aplicación.
2. Supabase Auth autentica al usuario.
3. La aplicación realiza una solicitud al backend.
4. PostgreSQL identifica el contexto del usuario y evalúa los permisos y políticas RLS correspondientes.
5. Si se trata de una operación administrativa, se ejecuta la función protegida correspondiente y se verifican los permisos.
6. Se procesa la consulta o modificación autorizada.
7. La aplicación recibe el resultado y actualiza la interfaz.
8. Cuando existen suscripciones configuradas, Supabase Realtime comunica los cambios correspondientes.

### 9. Consideraciones de mantenimiento

Para mantener la integridad y seguridad de la base de datos se deben considerar los siguientes aspectos:

- Mantener actualizadas las políticas RLS cuando se incorporen nuevas tablas o funcionalidades.
- Verificar los permisos de ejecución de las funciones administrativas.
- Mantener restringidas las operaciones sensibles.
- Revisar las relaciones entre usuarios, mascotas, reservas e historiales médicos.
- Comprobar que los triggers continúen funcionando correctamente después de modificar las tablas.
- Actualizar la publicación de Realtime cuando se incorporen nuevas tablas que necesiten transmitir cambios.
- Mantener sincronizada la documentación con el esquema real de PostgreSQL.

### 10. Consideraciones finales

La base de datos de PetCare Santa Cruz centraliza la información del sistema y permite mantener los datos organizados y protegidos.

La utilización de PostgreSQL, Supabase Auth, RLS, funciones protegidas, triggers y Realtime proporciona los mecanismos necesarios para administrar la información y controlar las operaciones de acuerdo con los permisos de cada perfil.

Este documento debe mantenerse actualizado cuando se modifique el esquema de PostgreSQL, se incorporen tablas o se cambien las políticas de seguridad.