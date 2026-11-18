# 03. Requisitos no funcionales
## Proyecto: PetCare Santa Cruz

### 1. Introducción

Los requisitos no funcionales establecen las características de calidad, seguridad, rendimiento y funcionamiento que debe cumplir la aplicación PetCare Santa Cruz.

Estos requisitos permiten definir las condiciones necesarias para ofrecer una aplicación estable, segura, accesible y fácil de mantener.

### 2. Seguridad

| Código | Requisito |
|---|---|
| RNF-001 | El sistema debe utilizar autenticación para controlar el acceso de los usuarios. |
| RNF-002 | El sistema debe diferenciar los permisos según los roles de cliente, veterinario y administrador. |
| RNF-003 | La información de los usuarios debe protegerse mediante las políticas de seguridad configuradas en Supabase. |
| RNF-004 | Las operaciones sobre la base de datos deben respetar las políticas de Row Level Security (RLS). |
| RNF-005 | Las credenciales y claves privadas del backend no deben exponerse públicamente. |
| RNF-006 | La comunicación con Supabase debe realizarse mediante conexiones seguras HTTPS. |
| RNF-025 | Las operaciones de acceso y modificación de datos deben respetar los permisos correspondientes al usuario autenticado. |
| RNF-026 | La aplicación no debe permitir que un usuario acceda directamente a información restringida de otros usuarios. |

### 3. Rendimiento

| Código | Requisito |
|---|---|
| RNF-007 | La aplicación debe responder adecuadamente a las interacciones del usuario. |
| RNF-008 | Las consultas a la base de datos deben realizarse de manera eficiente. |
| RNF-009 | La navegación entre módulos debe ofrecer una experiencia fluida. |
| RNF-010 | La aplicación debe evitar operaciones innecesarias que afecten su rendimiento. |
| RNF-027 | La carga de información de mascotas, servicios, productos y reservas debe realizarse de manera organizada para evitar retrasos innecesarios. |
| RNF-028 | Las actualizaciones en tiempo real deben gestionarse de forma que no afecten negativamente la navegación y el rendimiento de la aplicación. |

### 4. Disponibilidad y conectividad

| Código | Requisito |
|---|---|
| RNF-011 | La aplicación debe conectarse a los servicios de Supabase para acceder a la información remota. |
| RNF-012 | El sistema debe informar al usuario cuando se produzcan errores de conexión o de comunicación con el backend. |
| RNF-013 | La disponibilidad de los servicios remotos dependerá del funcionamiento de Supabase y de la conexión a Internet. |
| RNF-029 | La aplicación debe manejar adecuadamente los errores de conexión con servicios externos. |
| RNF-030 | Cuando no exista conexión a Internet, la aplicación debe mostrar mensajes informativos en las funcionalidades que requieran servicios remotos. |
| RNF-031 | Los servicios externos de mapas, clima y contacto deben utilizarse según su disponibilidad y las condiciones de conectividad del dispositivo. |

### 5. Compatibilidad

| Código | Requisito |
|---|---|
| RNF-014 | La aplicación debe ser compatible con dispositivos Android que cumplan los requisitos de la versión compilada. |
| RNF-015 | El proyecto debe poder desarrollarse y compilarse mediante Flutter SDK. |
| RNF-016 | La interfaz debe adaptarse a diferentes tamaños de pantalla compatibles. |
| RNF-032 | La aplicación debe permitir utilizar aplicaciones externas compatibles para abrir enlaces, realizar llamadas y consultar ubicaciones. |
| RNF-033 | Las funcionalidades de mapas deben visualizarse mediante tecnologías compatibles con Flutter, como flutter_map. |

### 6. Usabilidad

| Código | Requisito |
|---|---|
| RNF-017 | La interfaz debe presentar una navegación clara e intuitiva. |
| RNF-018 | Las opciones disponibles deben organizarse según el perfil del usuario. |
| RNF-019 | Los formularios deben facilitar el ingreso de información. |
| RNF-020 | Los mensajes de confirmación y error deben ser comprensibles para el usuario. |
| RNF-034 | Los elementos visuales y controles de la aplicación deben facilitar la identificación de las funciones disponibles. |
| RNF-035 | La información presentada debe organizarse para facilitar su consulta y comprensión. |

### 7. Mantenimiento y escalabilidad

| Código | Requisito |
|---|---|
| RNF-021 | El código fuente debe mantenerse organizado mediante módulos y funcionalidades. |
| RNF-022 | La arquitectura debe facilitar la incorporación de nuevas funcionalidades. |
| RNF-023 | Las dependencias deben administrarse mediante los archivos pubspec.yaml y pubspec.lock. |
| RNF-024 | El proyecto debe permitir ejecutar análisis estático y pruebas automatizadas. |
| RNF-036 | La documentación técnica debe mantenerse actualizada conforme evolucionen las funcionalidades del proyecto. |
| RNF-037 | Las bibliotecas y servicios externos utilizados deben contar con configuraciones compatibles con el proyecto. |

### 8. Tecnologías relacionadas

- **Flutter y Dart:** desarrollo de la aplicación móvil.
- **Supabase:** autenticación y servicios backend.
- **PostgreSQL:** almacenamiento y gestión de datos.
- **Supabase Realtime:** recepción de actualizaciones de información en tiempo real.
- **HTTPS:** comunicación segura con los servicios remotos.
- **flutter_map:** visualización de mapas en la aplicación.
- **OpenStreetMap:** información cartográfica.
- **Open-Meteo:** consulta de información climática.
- **url_launcher:** apertura de enlaces, llamadas y aplicaciones externas.
- **Git y GitHub:** control de versiones y gestión del código fuente.

### 9. Consideraciones finales

Los requisitos no funcionales establecen las condiciones de calidad esperadas para PetCare Santa Cruz. Su cumplimiento debe verificarse mediante pruebas, revisión del código y validación del comportamiento de la aplicación.

La seguridad, el rendimiento, la compatibilidad y la facilidad de uso son aspectos importantes para garantizar el funcionamiento adecuado de los módulos y servicios integrados.

La disponibilidad de algunas funcionalidades depende de servicios externos y de la conexión a Internet del dispositivo.