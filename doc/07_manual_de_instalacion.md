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

La forma recomendada de obtener la versión actualizada de PetCare Santa Cruz es mediante el archivo ZIP de entrega.

#### Opción A. Mediante ZIP (recomendada)

1. Recibir el archivo `PetCare_Entrega.zip`.
2. Extraer su contenido en una ubicación de preferencia.
3. Ubicar la carpeta principal `PetCare`.
4. Abrir la carpeta desde Visual Studio Code, Android Studio o una terminal.

El archivo ZIP incluye el código fuente y la documentación del proyecto. No es necesario descargar nuevamente las dependencias ni incluir carpetas temporales de compilación, ya que pueden generarse durante la instalación.

#### Opción B. Mediante Git

También se puede obtener el proyecto desde el repositorio remoto:

```bash
git clone https://github.com/AM1-LosMosqueperris/Mosqueperris.git
```

Ingresar al directorio:

```bash
cd Mosqueperris
```

Antes de continuar, comprobar que el contenido descargado corresponda a la versión actualizada de PetCare Santa Cruz.

**Importante:** la versión incluida en el archivo ZIP de entrega es la referencia recomendada para seguir este manual.

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

PetCare necesita conectarse al proyecto Supabase correspondiente para utilizar la autenticación, la base de datos y los servicios del backend.

La configuración de conexión se encuentra en:

```text
lib/config/config.dart
```

Verificar que estén configurados:

- URL del proyecto Supabase.
- Clave pública de acceso correspondiente.
- Parámetros de conexión necesarios.

La aplicación utiliza:

- **Supabase Auth:** autenticación de usuarios.
- **PostgreSQL:** almacenamiento y gestión de datos.
- **Row Level Security (RLS):** control de acceso a los registros.
- **Supabase Realtime:** recepción de cambios en tiempo real cuando existen suscripciones configuradas.

Antes de ejecutar la aplicación, comprobar que el proyecto Supabase tenga disponibles las tablas, relaciones, funciones, triggers y políticas RLS necesarias para los módulos de PetCare.

También se deben verificar los permisos correspondientes a los roles de cliente, veterinario y administrador.

**Consideraciones de seguridad:**

- No incluir claves secretas del backend en el código distribuido.
- No utilizar la clave `service_role` dentro de la aplicación móvil.
- Mantener las políticas RLS configuradas en Supabase.
- Utilizar las credenciales correspondientes al entorno de ejecución.

La base de datos y los servicios de Supabase permanecen alojados en el proyecto backend y no se crean automáticamente al ejecutar `flutter pub get`.

### 7. Configuración de autenticación

PetCare utiliza Supabase Auth para gestionar el registro, inicio de sesión y recuperación de acceso de los usuarios.

Para que la autenticación funcione correctamente, se debe verificar la configuración del proveedor de autenticación en el panel de Supabase.

#### 7.1. Confirmación de correo electrónico

Si está habilitada la confirmación de correo electrónico, configurar correctamente las URL de redirección permitidas para el proceso de registro.

#### 7.2. Recuperación de contraseña

Verificar que el proceso de recuperación de contraseña tenga configurada la URL de redirección correspondiente.

#### 7.3. Roles de usuario

La aplicación contempla los siguientes roles:

- Cliente.
- Veterinario.
- Administrador.

Los permisos y accesos deben coincidir con las políticas de seguridad configuradas en Supabase.

**Importante:** las URL de redirección deben coincidir con la configuración real de la aplicación Android y del proyecto Supabase. No modificar los esquemas de redirección sin comprobar previamente su configuración.

### 8. Preparar un dispositivo Android

Se puede utilizar:

- Un emulador Android configurado desde Android Studio.
- Un teléfono Android con la depuración USB habilitada.

Para verificar los dispositivos disponibles:

```bash
flutter devices
```

### 9. Ejecutar la aplicación

Una vez instaladas las dependencias y configurada la conexión con Supabase, se puede ejecutar PetCare Santa Cruz.

#### 9.1. Comprobar dispositivos disponibles

Ejecutar:

```bash
flutter devices
```

Este comando muestra los dispositivos físicos o emuladores disponibles.

#### 9.2. Ejecutar la aplicación

Desde la carpeta principal del proyecto, ejecutar:

```bash
flutter run
```

Flutter compilará e iniciará la aplicación en el dispositivo seleccionado.

#### 9.3. Comprobar los módulos principales

Después de iniciar la aplicación, verificar el funcionamiento de los módulos disponibles según el rol del usuario:

- Inicio y navegación.
- Registro e inicio de sesión.
- Gestión de mascotas.
- Consulta de servicios y citas.
- Vacunas e historial médico.
- Tienda, carrito y pedidos.
- Gestión de consultas y notificaciones.
- Mapa de veterinarias y contacto.
- Consulta del clima.
- Panel de administración y funciones veterinarias.

Algunas funciones dependen de la conexión a internet y de la disponibilidad de Supabase o de los servicios externos.

### 10. Verificar el proyecto

Antes de generar la versión final de la aplicación, se recomienda ejecutar las siguientes comprobaciones desde la carpeta principal del proyecto.

#### 10.1. Analizar el código

```bash
flutter analyze
```

Este comando revisa el código Dart e identifica posibles errores y advertencias.

#### 10.2. Ejecutar las pruebas

```bash
flutter test
```

Este comando ejecuta las pruebas automatizadas disponibles en el proyecto.

#### 10.3. Comprobaciones realizadas

Durante la preparación de la entrega se ejecutaron las siguientes verificaciones:

| Comprobación | Resultado |
|---|---|
| `flutter pub get` | Ejecutado correctamente |
| `flutter analyze` | Sin problemas detectados |
| `flutter test` | Todas las pruebas aprobadas |

Se recomienda repetir estas comprobaciones después de realizar modificaciones en el código fuente.

### 11. Generar APK

Para generar el instalador de PetCare Santa Cruz para dispositivos Android, ejecutar desde la carpeta principal del proyecto:

```bash
flutter build apk --release
```

Flutter realizará la compilación en modo release.

#### 11.1. Ubicación del archivo generado

Si la compilación finaliza correctamente, el APK estará disponible en:

```text
build/app/outputs/flutter-apk/app-release.apk
```

#### 11.2. Instalar en un dispositivo Android

1. Copiar el archivo `app-release.apk` al dispositivo Android.
2. Abrir el archivo desde el dispositivo.
3. Autorizar la instalación desde esa fuente si Android lo solicita.
4. Completar la instalación.
5. Abrir PetCare Santa Cruz y comprobar su funcionamiento.

#### 11.3. Consideraciones

- La generación del APK requiere que Flutter y el entorno Android estén correctamente configurados.
- El APK en modo release corresponde a la versión compilada para distribución.
- Las funciones que utilizan Supabase y servicios externos necesitan conexión a internet.
- El archivo APK es independiente del código fuente y de la documentación del proyecto.

### 12. Solución de problemas

A continuación, se presentan algunos problemas comunes durante la instalación y ejecución de PetCare Santa Cruz.

| Problema | Posible solución |
|---|---|
| Flutter no reconoce el dispositivo | Ejecutar `flutter devices` y comprobar la conexión del dispositivo o emulador. |
| Error al descargar dependencias | Verificar la conexión a internet y ejecutar `flutter pub get` nuevamente. |
| Error de conexión con Supabase | Comprobar la URL y la clave pública configuradas en `lib/config/config.dart`. |
| Error de inicio de sesión | Revisar las credenciales, la configuración de Supabase Auth y las URL de redirección. |
| No aparecen los datos | Comprobar la conexión a Supabase, las tablas, las políticas RLS y los permisos del usuario. |
| El mapa no muestra ubicaciones | Verificar la conexión a internet, las coordenadas registradas en la tabla `negocios` y la disponibilidad de OpenStreetMap. |
| No se muestra el clima | Comprobar la conexión a internet y la disponibilidad del servicio Open-Meteo. |
| No se puede abrir WhatsApp o realizar llamadas | Verificar que el dispositivo tenga instalada una aplicación compatible y que los datos de contacto sean válidos. |
| Error al generar el APK | Ejecutar `flutter doctor` y revisar los requisitos del entorno Android. |

#### Comandos útiles

Actualizar dependencias:

```bash
flutter pub get
```

Limpiar archivos temporales:

```bash
flutter clean
```

Volver a descargar dependencias:

```bash
flutter pub get
```

Analizar el proyecto:

```bash
flutter analyze
```

Ejecutar pruebas:

```bash
flutter test
```

Generar APK:

```bash
flutter build apk --release
```

Si el problema continúa, revisar el mensaje de error completo que muestra la terminal para identificar su causa.

### 13. Consideraciones finales

Para trasladar PetCare a otro equipo es necesario disponer del código fuente completo, los archivos `pubspec.yaml` y `pubspec.lock`, la configuración de Supabase y las herramientas de desarrollo compatibles.

La base de datos y los servicios de Supabase permanecen alojados en el proyecto backend correspondiente; copiar el código fuente no crea una nueva base de datos.

Para ejecutar la aplicación en otro entorno se debe contar con acceso al proyecto Supabase configurado y con los permisos correspondientes.