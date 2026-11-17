# 07. Manual de instalación
## Proyecto: PetCare Santa Cruz

### 1. Introducción

Este manual describe los pasos necesarios para instalar, configurar y ejecutar PetCare Santa Cruz en un equipo de desarrollo.

La aplicación está desarrollada con Flutter y utiliza Supabase como backend para la autenticación, almacenamiento y gestión de datos.

### 2. Requisitos previos

Para instalar y ejecutar el proyecto se necesita:

- Windows 10 o superior, o un sistema operativo compatible con Flutter.
- Flutter SDK.
- Dart SDK, incluido con Flutter.
- Android Studio o Visual Studio Code.
- Android SDK y herramientas de compilación.
- Git, si se desea utilizar el repositorio.
- Conexión a internet.
- Un dispositivo Android o emulador compatible.

### 3. Obtener el proyecto

La forma recomendada de obtener la versión actualizada de PetCare es mediante el archivo ZIP proporcionado.

#### Opción A. Mediante ZIP (recomendada)

1. Recibir el archivo `PetCare.zip`.
2. Extraer su contenido en una ubicación de preferencia.
3. Ubicar la carpeta principal del proyecto.
4. Abrir la carpeta desde Visual Studio Code, Android Studio o una terminal.

El archivo ZIP incluye el código fuente y la documentación del proyecto.

#### Opción B. Mediante Git

El repositorio remoto puede utilizarse como referencia, pero su contenido puede no corresponder a la última versión del proyecto.

Si se utiliza esta opción, clonar el repositorio:

```bash
git clone https://github.com/AM1-LosMosqueperris/Mosqueperris.git
```

Ingresar al directorio:

```bash
cd Mosqueperris
```

Cambiar a la rama correspondiente:

```bash
git checkout feature/autenticacion
```

**Importante:** comprobar que el código obtenido corresponda a la versión que se desea instalar.

### 4. Verificar Flutter

Abrir PowerShell o una terminal y ejecutar:

```bash
flutter doctor
```

Este comando permite verificar la instalación de Flutter y detectar dependencias o herramientas faltantes.

### 5. Instalar dependencias

Desde la carpeta principal del proyecto ejecutar:

```bash
flutter pub get
```

Este comando descarga las dependencias definidas en `pubspec.yaml` y utiliza las versiones registradas en `pubspec.lock`.

Las carpetas y archivos temporales de compilación, como `.dart_tool` y `build`, pueden generarse nuevamente durante este proceso y al compilar la aplicación.

### 6. Configurar Supabase

PetCare necesita conectarse al proyecto Supabase correspondiente.

La configuración se encuentra en:

```text
lib/config/config.dart
```

Verificar que estén configurados:

- URL del proyecto Supabase.
- Clave pública de acceso correspondiente.
- Parámetros de conexión necesarios.

La aplicación utiliza Supabase Auth para la autenticación y PostgreSQL para gestionar la información.

**Consideraciones de seguridad:**

- No incluir claves secretas del backend en el código distribuido.
- No utilizar la clave `service_role` dentro de la aplicación móvil.
- Mantener las políticas de seguridad RLS configuradas en Supabase.

La base de datos, las tablas, las funciones y las políticas de seguridad deben existir previamente en el proyecto Supabase utilizado.

### 7. Configurar la autenticación

PetCare utiliza autenticación mediante Supabase.

El proyecto contempla los siguientes enlaces de redireccionamiento:

- `petcare://confirm-email`: confirmación de correo electrónico.
- `petcare://reset-password`: recuperación de contraseña.

Para que estos procesos funcionen correctamente, se debe verificar que:

- La confirmación de correo electrónico esté configurada en Supabase.
- Las URL de redireccionamiento estén permitidas en la configuración de autenticación.
- Los enlaces profundos estén configurados en el proyecto Android.

### 8. Preparar un dispositivo Android

Se puede utilizar:

- Un emulador Android configurado desde Android Studio.
- Un teléfono Android con la depuración USB habilitada.

Para verificar los dispositivos disponibles:

```bash
flutter devices
```

### 9. Ejecutar la aplicación

Desde la carpeta principal del proyecto ejecutar:

```bash
flutter run
```

Flutter compilará y ejecutará PetCare en el dispositivo seleccionado.

### 10. Verificar el proyecto

Ejecutar el análisis estático:

```bash
flutter analyze
```

Ejecutar las pruebas automatizadas:

```bash
flutter test
```

Estos comandos permiten comprobar el estado del código y ejecutar las pruebas disponibles en el proyecto.

### 11. Generar el APK

Para crear una versión de producción:

```bash
flutter build apk --release
```

El archivo generado se encuentra en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Este archivo puede transferirse a un dispositivo Android compatible para instalar la aplicación.

### 12. Solución de problemas frecuentes

**Problema: Flutter no es reconocido como comando.**

Verificar que Flutter SDK esté instalado y agregado a la variable de entorno PATH.

**Problema: No se descargan las dependencias.**

Ejecutar:

```bash
flutter pub get
```

Verificar la conexión a internet.

**Problema: No se conecta con Supabase.**

Revisar la URL y la clave pública configuradas, la conexión a internet y el estado del proyecto Supabase.

**Problema: No se detecta el dispositivo Android.**

Ejecutar:

```bash
flutter devices
```

Verificar los controladores, la depuración USB o la configuración del emulador.

**Problema: No funcionan los enlaces de confirmación o recuperación de contraseña.**

Verificar las URL permitidas en Supabase y la configuración de enlaces profundos del proyecto Android.

### 13. Consideraciones finales

Para trasladar PetCare a otro equipo es necesario disponer del código fuente completo, los archivos `pubspec.yaml` y `pubspec.lock`, la configuración de Supabase y las herramientas de desarrollo compatibles.

La base de datos y los servicios de Supabase permanecen alojados en el proyecto backend correspondiente; copiar el código fuente no crea una nueva base de datos.

Para ejecutar la aplicación en otro entorno se debe contar con acceso al proyecto Supabase configurado y con los permisos correspondientes.