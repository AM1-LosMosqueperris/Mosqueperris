# PetCare Santa Cruz

**Aplicación móvil para la gestión integral del cuidado de mascotas.**

## 1. Descripción del proyecto

PetCare Santa Cruz es una aplicación móvil desarrollada con Flutter y Dart que permite centralizar la gestión de mascotas y facilitar el acceso a servicios veterinarios.

La aplicación integra herramientas para propietarios de mascotas, veterinarios y administradores, permitiendo gestionar información, reservas, historiales médicos, vacunas, servicios y notificaciones.

El sistema utiliza Supabase como servicio de backend para la autenticación y gestión de información.

## 2. Objetivo general

Desarrollar una aplicación móvil que facilite la organización y administración del cuidado de las mascotas, conectando a propietarios, veterinarios y administradores mediante una plataforma intuitiva y centralizada.

## 3. Tipos de usuarios

### Cliente
- Registrarse e iniciar sesión.
- Registrar y consultar sus mascotas.
- Consultar servicios veterinarios.
- Solicitar reservas de citas.
- Consultar el control de vacunas.
- Revisar el historial médico de sus mascotas.
- Consultar productos de la tienda.
- Realizar consultas y acceder a información de contacto.
- Recibir notificaciones.

### Veterinario
- Consultar información de mascotas.
- Revisar historiales médicos.
- Registrar información médica.
- Gestionar citas veterinarias.
- Recibir notificaciones sobre nuevas reservas.

### Administrador
- Gestionar usuarios y roles.
- Administrar mascotas.
- Gestionar servicios veterinarios.
- Administrar reservas.
- Consultar reportes y estadísticas.
- Gestionar notificaciones administrativas.

## 4. Funcionalidades principales

| Módulo | Descripción |
|---|---|
| Autenticación | Registro, inicio de sesión y recuperación de contraseña. |
| Inicio | Acceso a las funcionalidades de la aplicación. |
| Mascotas | Registro y gestión de mascotas. |
| Servicios | Consulta de servicios veterinarios. |
| Reservas | Solicitud y gestión de citas. |
| Vacunas | Control de vacunas y fechas correspondientes. |
| Historial médico | Consulta y registro de información médica. |
| Tienda | Consulta de productos para mascotas. |
| Consultas y contacto | Acceso a información y canales de consulta. |
| Administración | Gestión de usuarios, servicios, reservas y reportes. |
| Veterinaria | Gestión de citas e información médica. |
| Notificaciones | Avisos relacionados con las actividades del sistema. |

## 5. Tecnologías utilizadas

- **Flutter:** framework para el desarrollo de la aplicación.
- **Dart:** lenguaje de programación.
- **Supabase:** backend, autenticación y base de datos.
- **PostgreSQL:** sistema de gestión de base de datos utilizado por Supabase.
- **Visual Studio Code:** entorno de desarrollo.
- **Android Studio:** herramientas del SDK y emulación Android.
- **Git:** control de versiones.
- **GitHub:** alojamiento del repositorio.

## 6. Arquitectura del proyecto

El código fuente está organizado mediante una estructura modular basada en funcionalidades (Feature-First).

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
- Dart SDK (incluido con Flutter).
- Android SDK.
- Visual Studio Code o Android Studio.
- Emulador Android o dispositivo físico compatible.
- Acceso a internet.
- Proyecto de Supabase configurado y credenciales correspondientes.

## 8. Instalación y ejecución

### Obtener el código fuente

Clonar el repositorio:

```bash
git clone https://github.com/AM1-LosMosqueperris/Mosqueperris.git
```

Ingresar al proyecto:

```bash
cd Mosqueperris
```

Cambiar a la rama de desarrollo:

```bash
git checkout feature/autenticacion
```

### Instalar dependencias

```bash
flutter pub get
```

### Ejecutar la aplicación

```bash
flutter run
```

## 9. Configuración de Supabase

La aplicación utiliza Supabase para conectarse al backend.

La configuración se encuentra en:

```text
lib/config/config.dart
```

Para ejecutar el proyecto en otro equipo se deben configurar la URL del proyecto y la clave pública correspondiente