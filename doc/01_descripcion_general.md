# 01. Descripción general del proyecto
## PetCare Santa Cruz

### 1. Nombre del proyecto

PetCare Santa Cruz.

### 2. Descripción

PetCare Santa Cruz es una aplicación móvil orientada a facilitar la gestión y el cuidado de mascotas mediante una plataforma que conecta a propietarios, veterinarios y administradores.

El sistema centraliza información sobre mascotas, servicios veterinarios, reservas, vacunas, historiales médicos, productos de tienda, consultas y notificaciones.

Además, incorpora herramientas de administración para gestionar usuarios, roles, servicios, productos, reservas y consultas, así como consultar y buscar mascotas registradas. También dispone de mecanismos de actualización en tiempo real para mantener la información sincronizada.

### 3. Problemática

La gestión del cuidado de las mascotas puede requerir el uso de diferentes medios para organizar información, solicitar servicios y consultar antecedentes médicos.

PetCare busca centralizar estas actividades en una aplicación móvil, facilitando el acceso a la información, la organización de los servicios veterinarios y la comunicación entre los distintos perfiles del sistema.

### 4. Objetivo general

Desarrollar una aplicación móvil que permita gestionar información de mascotas y organizar servicios veterinarios mediante herramientas digitales accesibles, centralizadas y con control de acceso según el rol de cada usuario.

### 5. Objetivos específicos

- Facilitar el registro y la gestión de la información de mascotas por parte de sus propietarios.
- Permitir la consulta de servicios veterinarios.
- Gestionar solicitudes y estados de reservas.
- Centralizar la información del historial médico.
- Facilitar el seguimiento de vacunas.
- Incorporar una tienda para consultar productos disponibles.
- Permitir el envío y seguimiento de consultas.
- Proporcionar herramientas de administración de usuarios, roles, servicios y productos.
- Permitir que los veterinarios consulten información de mascotas y registren datos médicos.
- Implementar notificaciones para informar sobre eventos importantes.
- Incorporar actualizaciones en tiempo real para mantener sincronizada la información de los módulos correspondientes.

### 6. Usuarios del sistema

**Cliente:** propietario que registra sus mascotas, consulta servicios y productos, realiza reservas, revisa historiales médicos y utiliza las opciones de contacto y notificaciones.

**Veterinario:** profesional que consulta información de las mascotas, registra datos médicos y gestiona las citas según sus permisos.

**Administrador:** responsable de gestionar usuarios, roles, servicios, productos, reservas y consultas. También puede consultar, buscar y visualizar los detalles de las mascotas registradas, así como consultar estadísticas y reportes del sistema.

### 7. Alcance

El proyecto contempla una aplicación móvil desarrollada con Flutter, conectada a Supabase para la autenticación y gestión de datos.

Incluye los siguientes módulos:

- Autenticación y gestión de perfiles.
- Registro y gestión de mascotas por parte de sus propietarios.
- Consulta y búsqueda de mascotas desde el panel administrativo.
- Consulta de servicios veterinarios.
- Reservas y gestión de citas.
- Control de vacunas e historial médico.
- Tienda y consulta de productos.
- Envío y gestión de consultas.
- Panel de administración y reportes.
- Panel veterinario.
- Sistema de notificaciones.
- Actualización de información en tiempo real en los módulos implementados.

El acceso a las funcionalidades se controla según los roles de cliente, veterinario y administrador.

### 8. Tecnologías

- Flutter.
- Dart.
- Supabase.
- PostgreSQL.
- Supabase Auth.
- Supabase Realtime.
- Git y GitHub.

### 9. Beneficiarios

- Propietarios de mascotas.
- Profesionales veterinarios.
- Personal administrativo de servicios veterinarios.

### 10. Resultado esperado

Contar con una aplicación móvil que centralice las principales actividades relacionadas con el cuidado de mascotas, facilite la gestión de información y permita la interacción entre los diferentes usuarios mediante funcionalidades específicas para cada rol.

### 11. Conclusión

PetCare Santa Cruz representa una solución tecnológica orientada a mejorar la organización del cuidado animal mediante una plataforma digital modular, accesible y con control de acceso según los roles de usuario. La integración de Flutter y Supabase permite gestionar la información, administrar los diferentes módulos y mantener actualizados los datos mediante mecanismos de comunicación en tiempo real.