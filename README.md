# PetCare Santa Cruz

**Aplicación móvil para la gestión y el cuidado de mascotas.**

## Descripción del proyecto

PetCare Santa Cruz es una aplicación móvil desarrollada con Flutter y Dart, cuyo propósito es facilitar a los propietarios de mascotas el acceso a diferentes servicios y herramientas para organizar el cuidado de sus animales.

La aplicación reúne funcionalidades como el registro de mascotas, consulta de servicios veterinarios, reserva de citas, envío de consultas y control de vacunas, dentro de una interfaz sencilla e intuitiva.

El proyecto integra **Supabase** como servicio backend y PostgreSQL como sistema de gestión de base de datos, permitiendo almacenar y consultar información desde la aplicación.

## Objetivo

Desarrollar una aplicación móvil que permita centralizar la información y facilitar la organización de las actividades relacionadas con el cuidado de las mascotas, mediante una interfaz amigable y una conexión con una base de datos en la nube.

## Funcionalidades principales

Actualmente, el proyecto cuenta con los siguientes módulos:

1. **Inicio:** pantalla principal con acceso a las diferentes secciones.
2. **Registro de mascotas:** permite registrar información de las mascotas.
3. **Servicios:** muestra los servicios disponibles para el cuidado animal, consultados desde Supabase.
4. **Reserva de citas:** permite registrar solicitudes de citas y seleccionar servicios.
5. **Control de vacunas:** permite organizar la información de vacunas y sus fechas correspondientes.
6. **Historial:** sección destinada a la información relacionada con el seguimiento de las mascotas.
7. **Tienda:** módulo de acceso a productos para mascotas.
8. **Contacto:** información y opciones de contacto.
9. **Consultas:** permite enviar consultas mediante un formulario conectado a Supabase.

## Tecnologías utilizadas

- **Flutter:** framework para el desarrollo de aplicaciones móviles y web.
- **Dart:** lenguaje de programación.
- **Supabase:** servicio backend para la conexión y almacenamiento de información.
- **PostgreSQL:** sistema de gestión de base de datos.
- **Android Studio:** herramientas de desarrollo y emulación.
- **Visual Studio Code:** editor de código.
- **Git y GitHub:** control de versiones y alojamiento del código fuente.
- **Canva:** elaboración de presentaciones académicas.
- **FlutterFlow:** herramienta utilizada en el desarrollo del caso práctico correspondiente.

## Base de datos y conexión

La aplicación utiliza Supabase para gestionar la información almacenada en la nube.

Entre las tablas implementadas se encuentran:

- `servicios`: catálogo de servicios disponibles.
- `mascotas`: información de las mascotas registradas.
- `consultas`: información de las consultas enviadas.
- `reservas`: información de las reservas de citas.

Se configuraron políticas de seguridad mediante **Row Level Security (RLS)** para controlar las operaciones permitidas desde la aplicación.

Las consultas y reservas permiten registrar información desde el cliente, sin habilitar la lectura pública de esos registros.

## Validaciones y seguridad

Se implementaron validaciones para garantizar que los datos ingresados cumplan con los requisitos establecidos:

- Verificación de campos obligatorios.
- Validación de números telefónicos bolivianos de 8 dígitos que comienzan con 6 o 7.
- Validación de mensajes con un mínimo de 10 caracteres.
- Restricción de fechas y horas pasadas en las reservas.
- Validación de cantidad de personas entre 1 y 50.
- Control del envío de formularios para evitar solicitudes repetidas.

También se configuraron políticas RLS en Supabase para controlar los permisos de acceso y escritura.

## Plataforma de desarrollo

- Sistema operativo de desarrollo: Windows 11.
- Plataforma móvil: Android.
- Plataforma web: Google Chrome.
- Framework: Flutter.
- Backend: Supabase.
- Base de datos: PostgreSQL.

## Requisitos

Para ejecutar el proyecto se necesita:

- Flutter SDK.
- Dart SDK (incluido con Flutter).
- Android Studio o Visual Studio Code.
- Android SDK para ejecutar en dispositivos Android.
- Un emulador Android o dispositivo compatible.
- Navegador Google Chrome para ejecutar la versión web.
- Proyecto de Supabase configurado.

## Instalación y ejecución

1. Clonar el repositorio:

   ```bash
   git clone URL_DEL_REPOSITORIO
   ```

2. Ingresar a la carpeta del proyecto:

   ```bash
   cd PetCare
   ```

3. Descargar las dependencias:

   ```bash
   flutter pub get
   ```

4. Configurar las credenciales públicas de Supabase en `lib/config.dart`, utilizando la URL del proyecto y la clave pública correspondiente.

5. Ejecutar en Android:

   ```bash
   flutter run
   ```

6. Ejecutar en Google Chrome:

   ```bash
   flutter run -d chrome
   ```

7. Generar APK de producción:

   ```bash
   flutter build apk --release
   ```

8. Generar versión web:

   ```bash
   flutter build web --release
   ```

**Importante:** No publicar claves secretas ni claves `service_role` en el repositorio. La configuración incluida en la aplicación debe utilizar únicamente una clave pública de Supabase.

## Entregables académicos

Como parte del desarrollo de la actividad también se contemplan los siguientes materiales:

- Presentaciones y diapositivas de exposición.
- Edición y preparación de videos.
- Informe técnico y documentación del proyecto.
- Capturas de pantalla como evidencia del funcionamiento.
- Caso práctico de FlutterFlow.
- Caso práctico de Ruta Chiquitana.
- Documentación de pruebas y resultados.

Los archivos y evidencias correspondientes se organizarán dentro del repositorio según su disponibilidad.

## Estado del proyecto

**En desarrollo.**

Se cuenta con los módulos principales de PetCare, navegación entre pantallas, conexión con Supabase, registro de información, validaciones de formularios y generación del APK para Android.

Entre los próximos pasos se contempla:

- Verificar y completar la conexión con Supabase en Flutter Web.
- Realizar pruebas de funcionamiento en Android y Web.
- Documentar las pruebas de conexión y funcionamiento sin Internet.
- Completar las evidencias y documentación técnica.
- Organizar los materiales académicos y audiovisuales.
- Mejorar continuamente la experiencia de usuario.

## Desarrollo

Proyecto académico de desarrollo de aplicaciones móviles.

**Nombre del proyecto:** PetCare Santa Cruz.

**Actividad:** Actividad 2 – Catálogo y Conexión Supabase.

---

*PetCare Santa Cruz – Tecnología al servicio del cuidado de las mascotas.*
