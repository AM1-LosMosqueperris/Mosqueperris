# 03. Requisitos no funcionales
## Proyecto: PetCare Santa Cruz

### 1. Introducción

Los requisitos no funcionales establecen las características de calidad, seguridad y funcionamiento que debe cumplir la aplicación PetCare Santa Cruz.

### 2. Seguridad

| Código | Requisito |
|---|---|
| RNF-001 | El sistema debe utilizar autenticación para controlar el acceso de los usuarios. |
| RNF-002 | El sistema debe diferenciar los permisos según los roles de cliente, veterinario y administrador. |
| RNF-003 | La información de los usuarios debe protegerse mediante las políticas de seguridad configuradas en Supabase. |
| RNF-004 | Las operaciones sobre la base de datos deben respetar las políticas de Row Level Security (RLS). |
| RNF-005 | Las credenciales y claves privadas del backend no deben exponerse públicamente. |
| RNF-006 | La comunicación con Supabase debe realizarse mediante conexiones seguras HTTPS. |

### 3. Rendimiento

| Código | Requisito |
|---|---|
| RNF-007 | La aplicación debe responder adecuadamente a las interacciones del usuario. |
| RNF-008 | Las consultas a la base de datos deben realizarse de manera eficiente. |
| RNF-009 | La navegación entre módulos debe ofrecer una experiencia fluida. |
| RNF-010 | La aplicación debe evitar operaciones innecesarias que afecten su rendimiento. |

### 4. Disponibilidad y conectividad

| Código | Requisito |
|---|---|
| RNF-011 | La aplicación debe conectarse a los servicios de Supabase para acceder a la información remota. |
| RNF-012 | El sistema debe informar al usuario cuando se produzcan errores de conexión o de comunicación con el backend. |
| RNF-013 | La disponibilidad de los servicios remotos dependerá del funcionamiento de Supabase y de la conexión a internet. |

### 5. Compatibilidad

| Código | Requisito |
|---|---|
| RNF-014 | La aplicación debe ser compatible con dispositivos Android que cumplan los requisitos de la versión compilada. |
| RNF-015 | El proyecto debe poder desarrollarse y compilarse mediante Flutter SDK. |
| RNF-016 | La interfaz debe adaptarse a diferentes tamaños de pantalla compatibles. |

### 6. Usabilidad

| Código | Requisito |
|---|---|
| RNF-017 | La interfaz debe presentar una navegación clara e intuitiva. |
| RNF-018 | Las opciones disponibles deben organizarse según el perfil del usuario. |
| RNF-019 | Los formularios deben facilitar el ingreso de información. |
| RNF-020 | Los mensajes de confirmación y error deben ser comprensibles para el usuario. |

### 7. Mantenimiento y escalabilidad

| Código | Requisito |
|---|---|
| RNF-021 | El código fuente debe mantenerse organizado mediante módulos y funcionalidades. |
| RNF-022 | La arquitectura debe facilitar la incorporación de nuevas funcionalidades. |
| RNF-023 | Las dependencias deben administrarse mediante los archivos pubspec.yaml y pubspec.lock. |
| RNF-024 | El proyecto debe permitir ejecutar análisis estático y pruebas automatizadas. |

### 8. Tecnologías relacionadas

- Flutter y Dart para el desarrollo de la aplicación.
- Supabase para autenticación y servicios backend.
- PostgreSQL para almacenamiento y gestión de datos.
- HTTPS para la comunicación segura con los servicios remotos.

### 9. Consideraciones finales

Los requisitos no funcionales establecen las condiciones de calidad esperadas para PetCare Santa Cruz. Su cumplimiento debe verificarse mediante pruebas, revisión del código y validación del comportamiento de la aplicación.