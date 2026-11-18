# 02. Requisitos funcionales
## Proyecto: PetCare Santa Cruz

### 1. Introducción

Los requisitos funcionales describen las operaciones y servicios que debe proporcionar la aplicación PetCare Santa Cruz para satisfacer las necesidades de sus usuarios.

El sistema contempla tres perfiles principales: cliente, veterinario y administrador. Cada perfil dispone de funcionalidades de acuerdo con sus responsabilidades y permisos.

Además, la aplicación incorpora funcionalidades complementarias para facilitar la ubicación de establecimientos veterinarios, la comunicación con los negocios y la consulta de información climática.

### 2. Requisitos de autenticación

| Código | Requisito funcional |
|---|---|
| RF-001 | El sistema debe permitir que un usuario se registre en la aplicación. |
| RF-002 | El sistema debe permitir iniciar sesión mediante correo electrónico y contraseña. |
| RF-003 | El sistema debe permitir cerrar la sesión del usuario. |
| RF-004 | El sistema debe permitir solicitar la recuperación de contraseña. |
| RF-005 | El sistema debe identificar el rol del usuario autenticado y mostrar las opciones correspondientes. |
| RF-037 | El sistema debe permitir confirmar la dirección de correo electrónico durante el proceso de registro, cuando la confirmación esté habilitada. |

### 3. Requisitos del cliente

| Código | Requisito funcional |
|---|---|
| RF-006 | El sistema debe permitir registrar mascotas con sus datos correspondientes. |
| RF-007 | El sistema debe permitir consultar la información de las mascotas registradas por el cliente. |
| RF-008 | El sistema debe permitir consultar los servicios veterinarios disponibles. |
| RF-009 | El sistema debe permitir solicitar reservas de citas veterinarias. |
| RF-010 | El sistema debe permitir consultar las reservas realizadas por el cliente. |
| RF-011 | El sistema debe permitir consultar el estado de las reservas. |
| RF-012 | El sistema debe permitir consultar la información relacionada con las vacunas de las mascotas. |
| RF-013 | El sistema debe permitir consultar el historial médico de las mascotas. |
| RF-014 | El sistema debe permitir consultar los productos disponibles en la tienda. |
| RF-015 | El sistema debe proporcionar información de contacto. |
| RF-016 | El sistema debe permitir acceder al módulo de consultas. |
| RF-017 | El sistema debe mostrar notificaciones relacionadas con las actividades de la cuenta del cliente. |
| RF-038 | El sistema debe permitir al cliente cancelar sus propias reservas mediante la actualización de su estado, de acuerdo con los permisos establecidos. |
| RF-050 | El sistema debe permitir agregar productos disponibles al carrito de compras. |
| RF-051 | El sistema debe permitir consultar los productos agregados al carrito. |
| RF-052 | El sistema debe permitir modificar las cantidades de los productos del carrito, según las opciones implementadas. |
| RF-053 | El sistema debe permitir retirar productos del carrito. |
| RF-054 | El sistema debe permitir confirmar la compra y registrar un pedido. |
| RF-055 | El sistema debe permitir consultar los pedidos realizados por el cliente y sus estados. |
| RF-056 | El sistema debe permitir visualizar establecimientos veterinarios disponibles en un mapa. |
| RF-057 | El sistema debe permitir consultar la información disponible de los establecimientos veterinarios mostrados en el mapa. |
| RF-058 | El sistema debe permitir abrir la ubicación de un establecimiento mediante una aplicación externa de mapas. |
| RF-059 | El sistema debe permitir iniciar una comunicación con establecimientos mediante WhatsApp, cuando exista un número de contacto disponible. |
| RF-060 | El sistema debe permitir realizar llamadas telefónicas a establecimientos que dispongan de un número registrado. |
| RF-061 | El sistema debe permitir consultar información climática mediante un servicio externo. |
| RF-062 | El sistema debe mostrar información climática disponible, como temperatura, sensación térmica, humedad, viento y precipitación. |

### 4. Requisitos del veterinario

| Código | Requisito funcional |
|---|---|
| RF-018 | El sistema debe permitir al veterinario consultar las mascotas registradas. |
| RF-019 | El sistema debe permitir consultar los detalles de cada mascota. |
| RF-020 | El sistema debe permitir consultar la información del historial médico. |
| RF-021 | El sistema debe permitir registrar nuevos datos en el historial médico de una mascota. |
| RF-022 | El sistema debe permitir consultar las reservas y citas veterinarias. |
| RF-023 | El sistema debe permitir actualizar el estado de una reserva según los permisos establecidos. |
| RF-024 | El sistema debe mostrar notificaciones relacionadas con nuevas reservas. |

### 5. Requisitos del administrador

| Código | Requisito funcional |
|---|---|
| RF-025 | El sistema debe permitir consultar los usuarios registrados. |
| RF-026 | El sistema debe permitir gestionar los roles de los usuarios. |
| RF-027 | El sistema debe permitir al administrador consultar y buscar las mascotas registradas, así como visualizar sus datos y la información de sus propietarios. |
| RF-028 | El sistema debe permitir gestionar los servicios veterinarios, incluyendo su creación, edición y cambio de disponibilidad. |
| RF-029 | El sistema debe permitir consultar y gestionar las reservas. |
| RF-030 | El sistema debe proporcionar reportes y estadísticas administrativas. |
| RF-031 | El sistema debe mostrar notificaciones relacionadas con nuevas reservas y registros de clientes. |
| RF-039 | El sistema debe permitir consultar, buscar y revisar los detalles de las consultas enviadas por los clientes. |
| RF-040 | El sistema debe permitir actualizar el estado de las consultas entre pendiente y atendida. |
| RF-041 | El sistema debe permitir gestionar los productos de la tienda mediante su creación y edición. |
| RF-042 | El sistema debe permitir actualizar el stock de los productos. |
| RF-043 | El sistema debe permitir activar o desactivar productos para controlar su disponibilidad en la tienda. |
| RF-044 | El sistema debe permitir consultar y filtrar las reservas por sus estados y datos disponibles. |
| RF-063 | El sistema debe permitir consultar los pedidos registrados por los clientes, según las opciones disponibles en el panel administrativo. |
| RF-064 | El sistema debe permitir consultar los detalles y estados de los pedidos. |

### 6. Requisitos de notificaciones

| Código | Requisito funcional |
|---|---|
| RF-032 | El sistema debe generar notificaciones cuando se produzcan determinados eventos relevantes. |
| RF-033 | El sistema debe permitir consultar las notificaciones del usuario autenticado. |
| RF-034 | El sistema debe permitir marcar las notificaciones como leídas. |
| RF-035 | El sistema debe notificar al cliente sobre cambios relevantes en sus reservas. |
| RF-036 | El sistema debe notificar al cliente cuando se registre nueva información en el historial médico de su mascota. |
| RF-046 | El sistema debe notificar al administrador sobre determinados eventos, como nuevos registros de usuarios y nuevas reservas. |
| RF-047 | El sistema debe notificar al veterinario sobre nuevas reservas relacionadas con la atención veterinaria. |

### 7. Actualización de información en tiempo real

| Código | Requisito funcional |
|---|---|
| RF-048 | El sistema debe actualizar la información de determinados módulos cuando se reciban cambios mediante Supabase Realtime. |
| RF-049 | El sistema debe reflejar los cambios relevantes en mascotas, reservas, historial médico, productos, consultas, perfiles y notificaciones, según las suscripciones configuradas en cada pantalla. |

### 8. Reglas generales

- Cada usuario debe acceder únicamente a las funcionalidades correspondientes a su rol.
- Los clientes deben consultar únicamente la información de sus propias mascotas y registros.
- Los veterinarios y administradores deben operar de acuerdo con los permisos establecidos.
- Las operaciones sobre información deben respetar las políticas de seguridad de la base de datos.
- Las notificaciones deben estar asociadas al usuario destinatario.
- Los clientes pueden cancelar sus propias reservas, pero no modificar libremente los demás datos de la reserva.
- Los veterinarios pueden registrar información médica, respetando los permisos establecidos.
- Los productos desactivados no deben mostrarse en la tienda disponible para los clientes.
- Las operaciones administrativas deben realizarse mediante los mecanismos protegidos del backend.
- Los productos agregados al carrito deben estar disponibles para su compra.
- Los pedidos deben quedar asociados al usuario que realiza la compra.
- La información de contacto y ubicación debe utilizar los datos registrados de cada establecimiento.
- La información climática depende de la disponibilidad del servicio externo.
- Las funcionalidades que utilizan servicios externos pueden requerir conexión a Internet y la disponibilidad de las aplicaciones correspondientes.

### 9. Consideraciones

Los requisitos descritos corresponden a las funcionalidades identificadas en el proyecto PetCare Santa Cruz. Su implementación está respaldada por la aplicación Flutter y los servicios de backend proporcionados por Supabase.

La aplicación utiliza Supabase Auth para la autenticación, PostgreSQL para el almacenamiento de información y Supabase Realtime para recibir actualizaciones en los módulos configurados.

Para las funcionalidades complementarias se utilizan OpenStreetMap mediante la biblioteca flutter_map y Open-Meteo para consultar información climática. Las opciones de contacto y navegación permiten utilizar aplicaciones externas compatibles con el dispositivo.

Este documento podrá actualizarse conforme se incorporen nuevas funcionalidades al sistema.