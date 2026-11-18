# PetCare Santa Cruz

**Aplicación móvil para la gestión integral del cuidado de mascotas.**

## 1. Descripción del proyecto

PetCare Santa Cruz es una aplicación móvil desarrollada con Flutter y Dart, orientada a facilitar la gestión del cuidado de mascotas y conectar a propietarios con servicios veterinarios.

La plataforma permite registrar mascotas, consultar servicios, solicitar citas, acceder a información médica, consultar productos y realizar pedidos. También incorpora herramientas de contacto, ubicación de veterinarias y consulta del clima.

El sistema utiliza Supabase como backend para la autenticación, almacenamiento y gestión de datos.

## 2. Objetivo general

Desarrollar una aplicación móvil que facilite la organización y administración del cuidado de las mascotas mediante una plataforma intuitiva, centralizada y accesible para clientes, veterinarios y administradores.

## 3. Tipos de usuarios

### Cliente
- Registrarse e iniciar sesión.
- Registrar y consultar sus mascotas.
- Consultar servicios veterinarios.
- Solicitar reservas y enviar consultas.
- Consultar vacunas e historiales médicos.
- Consultar productos disponibles.
- Agregar productos al carrito y realizar pedidos.
- Consultar veterinarias mediante un mapa.
- Consultar información meteorológica.
- Contactar mediante WhatsApp y llamadas.
- Recibir notificaciones.

### Veterinario
- Consultar información de mascotas.
- Revisar historiales médicos.
- Registrar información médica.
- Gestionar citas veterinarias.
- Recibir notificaciones relacionadas con las reservas.

### Administrador
- Gestionar usuarios y roles.
- Administrar mascotas.
- Gestionar servicios veterinarios.
- Administrar reservas.
- Gestionar productos y pedidos.
- Consultar información administrativa.
- Gestionar notificaciones.

## 4. Funcionalidades principales

| Módulo | Descripción |
|---|---|
| Autenticación | Registro, inicio de sesión y recuperación de contraseña. |
| Inicio | Acceso a las funcionalidades según el tipo de usuario. |
| Mascotas | Registro y consulta de información de mascotas. |
| Servicios | Consulta de servicios veterinarios. |
| Reservas | Solicitud y gestión de citas. |
| Vacunas | Consulta del control de vacunas. |
| Historial médico | Consulta y registro de información médica. |
| Tienda | Catálogo de productos para mascotas. |
| Carrito y pedidos | Selección de productos, cálculo de totales y creación de pedidos. |
| Consultas | Envío y gestión de consultas. |
| Veterinarias | Visualización de establecimientos mediante OpenStreetMap. |
| Clima | Consulta de condiciones meteorológicas mediante Open-Meteo. |
| Contacto | Acceso a WhatsApp, llamadas y navegación hacia ubicaciones. |
| Notificaciones | Avisos relacionados con las actividades del sistema. |
| Administración | Gestión de usuarios, servicios, reservas y otras operaciones administrativas. |

## 5. Tecnologías utilizadas

- **Flutter:** framework para el desarrollo de la aplicación móvil.
- **Dart:** lenguaje de programación.
- **Supabase:** backend, autenticación y servicios de base de datos.
- **PostgreSQL:** sistema de gestión de base de datos utilizado por Supabase.
- **Open-Meteo:** servicio para consultar información meteorológica.
- **OpenStreetMap:** servicio de mapas y visualización de ubicaciones.
- **flutter_map:** paquete utilizado para integrar mapas en Flutter.
- **url_launcher:** integración con aplicaciones externas para contacto y navegación.
- **Visual Studio Code:** entorno de desarrollo.
- **Android SDK:** herramientas para compilar y ejecutar la aplicación Android.

## 6. Arquitectura del proyecto

El código fuente utiliza una organización modular basada en funcionalidades (Feature-First), separando los módulos de administración, autenticación, clientes, veterinarios y servicios compartidos.

Estructura general:

```text
lib/
├── config/
├── core/
├── database/
├── features/
│   ├── administrador/
│   ├── auth/
│   ├── cliente/
│   ├── notificaciones/
│   └── veterinario/
├── models/
├── services/
├── utils/
├── widgets/
└── main.dart
```

Esta organización facilita el mantenimiento, la ampliación y la separación de responsabilidades de cada módulo.

## 7. Requisitos para ejecutar el proyecto

- Flutter SDK compatible con las dependencias del proyecto.
- Dart SDK, incluido con Flutter.
- Android SDK.
- Visual Studio Code o Android Studio.
- Emulador Android o dispositivo físico compatible.
- Acceso a internet para los servicios remotos.
- Proyecto de Supabase configurado y sus credenciales correspondientes.

## 8. Instalación y ejecución

### Obtener el código fuente

Clonar el repositorio:

```bash
git clone https://github.com/AM1-LosMosqueperris/Mosqueperris.git
```

Ingresar al directorio del proyecto:

```bash
cd Mosqueperris
```

### Instalar dependencias

```bash
flutter pub get
```

### Ejecutar la aplicación

```bash
flutter run
```

### Analizar el proyecto

```bash
flutter analyze
```

### Ejecutar las pruebas

```bash
flutter test
```

### Generar el APK de producción

```bash
flutter build apk --release
```

El archivo APK se genera en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 9. Configuración de Supabase

La aplicación utiliza Supabase para conectarse al backend, gestionar la autenticación y consultar o almacenar información.

La configuración se encuentra en:

```text
lib/config/config.dart
```

Para ejecutar el proyecto en otro equipo se deben configurar la URL del proyecto y la clave pública correspondiente.

Las credenciales privadas y claves administrativas no deben incluirse en el repositorio ni compartirse públicamente.

## 10. Servicios externos

### Open-Meteo

Se utiliza para obtener información meteorológica, como temperatura, sensación térmica, humedad, viento y precipitación.

### OpenStreetMap

Se utiliza para visualizar ubicaciones de veterinarias mediante `flutter_map`. La integración incluye la atribución correspondiente a OpenStreetMap y no requiere una clave de Google Maps API.

### Aplicaciones externas

La aplicación permite iniciar acciones de contacto y navegación mediante WhatsApp, el marcador telefónico y Google Maps.

## 11. Pruebas y verificación

En la verificación del proyecto se obtuvieron los siguientes resultados:

- `flutter analyze`: sin problemas detectados.
- `flutter test`: todas las pruebas automatizadas aprobadas.

Estos resultados corresponden a las verificaciones realizadas durante el proceso de preparación de la versión de entrega.

## 12. Consideraciones finales

PetCare Santa Cruz integra herramientas para facilitar el cuidado de mascotas y la gestión de servicios veterinarios mediante una aplicación móvil.

La combinación de Flutter, Supabase, Open-Meteo y OpenStreetMap permite ofrecer funcionalidades de administración, comunicación, consulta de información y ubicación en una misma plataforma.