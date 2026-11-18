# 01. Descripción general del proyecto
## PetCare Santa Cruz

### 1. Nombre del proyecto

PetCare Santa Cruz.

### 2. Descripción

PetCare Santa Cruz es una aplicación móvil orientada a facilitar la gestión y el cuidado de mascotas mediante una plataforma digital que conecta a propietarios, veterinarios y administradores.

El sistema centraliza información y funcionalidades relacionadas con el registro de mascotas, servicios veterinarios, reservas, vacunas, historiales médicos, productos de tienda, pedidos, consultas y notificaciones.

También incorpora herramientas de administración para gestionar usuarios, roles, servicios, productos, reservas y consultas, además de consultar y buscar mascotas registradas.

La aplicación cuenta con funcionalidades complementarias, como la ubicación de negocios veterinarios mediante un mapa basado en OpenStreetMap, consulta de condiciones climáticas mediante Open-Meteo y opciones de contacto mediante WhatsApp y llamadas telefónicas. Asimismo, permite abrir rutas hacia establecimientos mediante aplicaciones de mapas externas.

### 3. Problemática

La gestión del cuidado de las mascotas puede requerir el uso de diferentes medios para organizar información, solicitar servicios veterinarios, consultar antecedentes médicos y comunicarse con establecimientos especializados.

Esta dispersión de información puede dificultar el seguimiento de las necesidades de las mascotas y la organización de los servicios.

PetCare Santa Cruz busca centralizar estas actividades en una aplicación móvil, facilitando el acceso a la información, la organización de los servicios veterinarios y la comunicación entre los distintos perfiles del sistema.

### 4. Objetivo general

Desarrollar una aplicación móvil que permita gestionar información de mascotas y organizar servicios veterinarios mediante herramientas digitales accesibles y centralizadas, con control de acceso según el rol de cada usuario.

### 5. Objetivos específicos

- Facilitar el registro y la gestión de la información de mascotas por parte de sus propietarios.
- Permitir la consulta de servicios veterinarios.
- Gestionar solicitudes y estados de reservas.
- Centralizar la información del historial médico.
- Facilitar el seguimiento de vacunas.
- Incorporar una tienda para consultar productos disponibles.
- Permitir la gestión del carrito de compras y la realización de pedidos.
- Facilitar el envío y seguimiento de consultas.
- Proporcionar herramientas de administración de usuarios, roles, servicios y productos.
- Permitir que los veterinarios consulten información de mascotas y registren datos médicos según sus permisos.
- Implementar notificaciones para informar sobre eventos importantes.
- Incorporar actualizaciones en tiempo real en los módulos correspondientes.
- Facilitar la ubicación de establecimientos veterinarios mediante un mapa.
- Proporcionar información climática mediante un servicio externo.
- Facilitar la comunicación con establecimientos mediante WhatsApp y llamadas telefónicas.

### 6. Usuarios del sistema

**Cliente:** propietario que registra y administra sus mascotas, consulta servicios y productos, realiza reservas, gestiona pedidos, revisa historiales médicos y utiliza las opciones de contacto, ubicación y notificaciones.

**Veterinario:** profesional que consulta información de las mascotas, registra datos médicos y gestiona las citas de acuerdo con los permisos establecidos en el sistema.

**Administrador:** responsable de gestionar usuarios, roles, servicios, productos, reservas y consultas. También puede consultar, buscar y visualizar los detalles de las mascotas registradas, así como acceder a las herramientas de administración y reportes disponibles.

### 7. Alcance

El proyecto contempla una aplicación móvil desarrollada con Flutter y Dart, conectada a Supabase para la autenticación y gestión de datos.

Incluye los siguientes módulos y funcionalidades:

- Autenticación y gestión de perfiles.
- Registro y gestión de mascotas por parte de sus propietarios.
- Consulta y búsqueda de mascotas desde el panel administrativo.
- Consulta de servicios veterinarios.
- Reservas y gestión de citas.
- Control de vacunas e historial médico.
- Tienda y consulta de productos.
- Carrito de compras y gestión de pedidos.
- Envío y gestión de consultas.
- Panel de administración y herramientas de gestión.
- Panel veterinario.
- Sistema de notificaciones.
- Actualización de información en tiempo real en los módulos implementados.
- Mapa para visualizar establecimientos veterinarios.
- Consulta de información climática.
- Opciones de contacto mediante WhatsApp y llamadas telefónicas.
- Apertura de ubicaciones y rutas mediante aplicaciones de mapas externas.

El acceso a las funcionalidades se controla según los roles de cliente, veterinario y administrador.

### 8. Tecnologías

Las principales tecnologías y herramientas utilizadas en el proyecto son:

- **Flutter:** framework para el desarrollo de la aplicación móvil.
- **Dart:** lenguaje de programación utilizado por Flutter.
- **Supabase:** plataforma de backend para la gestión de datos y servicios.
- **PostgreSQL:** sistema gestor de bases de datos.
- **Supabase Auth:** servicio de autenticación de usuarios.
- **Supabase Realtime:** mecanismo de actualización de información en tiempo real.
- **flutter_map:** biblioteca utilizada para mostrar mapas.
- **OpenStreetMap:** fuente de datos cartográficos.
- **Open-Meteo:** servicio externo para consultar información climática.
- **url_launcher:** biblioteca para abrir enlaces, llamadas y aplicaciones externas.
- **Git y GitHub:** herramientas para el control de versiones y alojamiento del código fuente.
- **Visual Studio Code y Android Studio:** herramientas utilizadas durante el desarrollo.

### 9. Beneficiarios

- Propietarios de mascotas.
- Profesionales veterinarios.
- Personal administrativo de establecimientos veterinarios.

### 10. Resultado esperado

Contar con una aplicación móvil que centralice las principales actividades relacionadas con el cuidado de mascotas, facilite la gestión de información y permita la interacción entre los diferentes usuarios mediante funcionalidades específicas para cada rol.

Se espera que la aplicación facilite la administración de mascotas, la organización de servicios veterinarios, el seguimiento de información médica, la consulta de productos y pedidos, y la comunicación con establecimientos veterinarios.

### 11. Conclusión

PetCare Santa Cruz representa una solución tecnológica orientada a mejorar la organización del cuidado animal mediante una plataforma digital modular y accesible.

La integración de Flutter y Supabase permite desarrollar y administrar los diferentes módulos de la aplicación, mientras que los servicios complementarios de mapas y consulta climática amplían las herramientas disponibles para los usuarios.

El sistema incorpora control de acceso según los roles, gestión centralizada de información y mecanismos de actualización en tiempo real en las funcionalidades correspondientes.