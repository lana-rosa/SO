# Auditoría Fase 0 — LAROVA OS (Sistema Operativo Lana Rosa)

Fecha: 24-nov-2026 · Alcance: SOLO LECTURA. No se cambió código, base, RLS, configuración ni servicios. No hay secretos ni datos personales en este informe.
Base consultada: Supabase `ngjoognzvehwjtpqwrqe`, schema `sistema_operativo` (consultas de catálogo, conteos y avisos de seguridad).

> **Aprobación (24-nov-2026):** Jennifer escribió en este chat: «Apruebo iniciar la Fase 1 y publicar la Fase 0 en main». Alcance: Fase 1 en el orden 1) inmutabilidad documental, 2) permisos por proceso con el ERP, 3) PDF con QR y Excel, 4) buscador convencional. Cada migración: prueba en rollback, asesor de seguridad, plan de reversión y «¿Lo aplico? Sí o no» a Jennifer antes de aplicarla. Pendiente: escrito de Sara (se citará como correo/acta cuando llegue).

## 1. Resumen ejecutivo

1. **La realidad no es Next.js/Vercel/Tailwind.** El SO es un `index.html` estático (≈285 KB, JavaScript en el mismo archivo) publicado en GitHub Pages, con Supabase (login + datos) y 5 endpoints `/api/pos/so/*` del Worker del ERP. Recomendación: **evolucionar sin cambiar de tecnología**.
2. **La base está bien armada y asegurada por rol** (54 tablas, RLS activo en todas, política por rol aplicada el 14-nov, `anon` sin acceso). Es un buen cimiento.
3. **Casi todo está vacío.** Hay 21 procesos y 18 documentos (todos en `borrador`). Cero tareas, indicadores, riesgos, no conformidades, evidencias y versiones. Hay estructura, pero no operación todavía.
4. **El control documental NO es inmutable hoy.** Sin triggers en ninguna tabla, sin hash, sin archivo guardado (`url_archivo` vacío), historial de versiones vacío y editable/borrable por administradoras. Es la brecha más grande y la más importante para ISO y Fondo Emprender.
5. **No existe motor de alertas, buscador global, copiloto, PDF con QR ni tarea diaria del SO.** Los 6 cron jobs que hay son del ERP/tienda, ninguno del SO.
6. **El ERP YA administra usuarios, roles y permisos** (`usuarios_roles`, `roles_personalizados`, `permisos_modulos_usuario`, `fn_rol_actual()`). El SO ya depende de eso. **Fase 1 no debe crear un administrador de usuarios paralelo**; solo falta que el ERP exponga permisos *por proceso* y rol de «externo con vencimiento» (hoy no existen; pendiente de confirmar con ERP Chat 9).
7. **Puntos de atención de seguridad (sin cambiar nada):** protección de contraseñas filtradas desactivada en Auth; funciones `security definer` ejecutables por `anon`/`authenticated` (aviso de Supabase; hay que ver si son las del SO); `gestion_accesos` del SO duplica en texto libre lo que ya hace el ERP; no hay staging separado.

## 2. Arquitectura actual

| Capa | Realidad |
|---|---|
| Front | `index.html` único + `sw.js` (network-first, caché `lr-os-v1`) + `manifest.json` (PWA). GitHub Pages `lana-rosa.github.io/SO/`. Librería supabase-js desde CDN jsdelivr (versión sin fijar `@2`). |
| Auth | `signInWithPassword` de Supabase; sesión guardada por supabase-js en el navegador. Llave `sb_publishable_…` en el front: **es pública por diseño, no es secreto**; lo que protege es RLS. No hay `service_role` en el front. |
| Datos | Supabase del ERP, schema `sistema_operativo`, lectura/escritura directa desde el navegador con RLS. |
| Integración ERP | Worker del ERP con Bearer del usuario: `resumen-financiero`, `alertas-activas`, `fondo-emprender`, `inventario-critico`, `resumen-crm`, `tareas/sincronizar-calendario`. |
| Caché | Tabla `cache_resumen_negocio` (1 fila). **Quién la refresca no se ve en `cron.job`** → pendiente de verificación. |
| Edge Functions del proyecto | 19 (tienda, pagos, CRM, `google-calendar`, `google-drive`, `asistente-financiero`, etc.). Ninguna es del SO salvo posible reuso de `google-calendar`/`google-drive`. |
| Documentación | **No existe `CLAUDE.md`** en el repo (se pidió leerlo). Solo `docs/RESUMEN-ORQUESTADOR.md`. |

Servicios que viven fuera del repo y **no se pudieron revisar**: consolas de Supabase/Cloudflare/GitHub Pages.

## 3. Base de datos (schema `sistema_operativo`)

- **54 tablas, todas con RLS activo**, 0 triggers, 62 llaves foráneas en total (casi todas hacia `procesos`).
- **Políticas:** `so_admin_todo` (ALL, 54 tablas) · `so_taller_lectura` (SELECT, 16) · `so_taller_crear` (INSERT, 3) · `so_taller_editar` (UPDATE, 3). Rol `anon` sin permisos; `authenticated` con CRUD filtrado por RLS; `service_role` salta RLS.
- **Funciones (4, todas `security definer`):** `fn_es_admin_so`, `fn_es_taller_so`, `fn_proceso_visible_taller`, `fn_proceso_editable_taller`. Dependen de `public.fn_rol_actual()` del ERP.
- **Familias de tablas:** estrategia (procesos, líneas, canvas, FODA, identidad, partes interesadas, revisiones), operación (pasos_flujo, tareas, proyectos), calidad (no_conformidades, acciones_correctivas, auditorías internas/5S, oportunidades_mejora), riesgos e indicadores (+revisiones), documentos (documentos, historial_versiones_documento, evidencias), SG-SST (peligros, accidentes, EPP, capacitaciones, evaluaciones médicas, sociodemográfica, autoevaluación), tecnología/ambiente/proveedores, financiación y alianzas, Academy, caché.
- **Procesos:** los 21 con sus códigos oficiales intactos (PA-01..08, PE-01..04, PEM-01..04, PM-01..05).
- **`documentos`:** columnas código, nombre, versión (texto), responsable y aprobador (texto libre), estado, fechas, `url_archivo`. Check de estado permite solo `borrador, vigente, en_revision, obsoleto` (**faltan APROBADO y ANULADO**).
- **Extensiones disponibles:** pgcrypto (hash), pg_cron, pg_net, supabase_vault. **No hay** `pg_trgm`, `unaccent` ni `pgvector` (necesarias para buscador).
- **Buckets de Storage:** ninguno es del SO (`documentos-empresa`, `documentos-empleados` privados son del ERP). Hay 2 buckets públicos de fotos (tienda).

## 4. Autenticación y permisos

- Login por correo y contraseña de Supabase Auth, compartido con las clientas de la tienda (por eso RLS es crítico).
- **Duración de sesión e invalidación:** configuración en la consola de Supabase (JWT expiry, tiempo máximo de sesión, sesión única, MFA) → **pendiente de verificación humana**. El front no fuerza cierre por inactividad.
- **Rol por RLS:** administrador (incluye «Gerencia SO») todo; taller solo lectura PM-02/PA-07 y edición limitada; los demás nada.
- **¿El ERP administra usuarios/roles/permisos?** **Sí:** `usuarios_roles` (rol, activo, jefe de departamento), `roles_personalizados` (rol base), `permisos_modulos_usuario` (módulo→otorgado), `roles_adicionales_usuario`, `auditoria_autorizaciones`, `empleados`. **Condiciona Fase 1:** usar esos mismos mecanismos y pedir al ERP (a) clave de módulo «SO» con niveles, (b) permiso por proceso, (c) usuarios externos con fecha de vencimiento y MFA. Qué tan avanzado está «Gestión Colaboradores» → consultar ERP Chat 9.
- MFA: no hay evidencia de que esté activo. **Pendiente de verificación humana.**

## 5. Inventario de funcionalidades

| Estado | Funcionalidades |
|---|---|
| **Existen y funcionan** (según código y datos; no se probó la interfaz) | Login/logout; Dashboard con caché y datos del ERP; listado y detalle de los 21 procesos; líneas estratégicas con canvas y FODA; flujo de procesos (pasos, orden, borrado); identidad estratégica, partes interesadas, revisiones; fuentes de financiación; alianzas y seguimientos; posicionamiento de marca; PWA instalable; RLS por rol. |
| **Existen con ajustes** | Documentos (sin archivo, hash ni flujo de estados); tareas + sincronizar calendario (0 tareas, no probado); indicadores y semáforo (campo `semaforo` manual, 0 datos); riesgos (0 datos); botón «Volver» siempre al Dashboard; tarjeta «Ventas del período» sin datos. |
| **Parciales** | SG-SST (tablas listas, documentos DOC-SST en borrador); calidad/NC/auditorías (tablas sin uso); `gestion_accesos` (texto libre). |
| **No desarrolladas** | Codificación automática PA-02-RIT-v03; estados BORRADOR→…→VIGENTE con aprobaciones; versiones inmutables con hash; vigencia diaria America/Bogota; PDF oficial con QR; exportación Excel; buscador global; motor de alertas con semáforo/escalamiento/cierre con evidencia; copiloto gerencial; tablero PEM-01; accesos de externos con vencimiento y MFA; feed ICS. |
| **No conviene (es de otro sistema)** | Usuarios/roles/permisos (ERP); contabilidad, inventario, ventas (ERP); gestión de empleados, competencias y evaluaciones de desempeño (Gestión Colaboradores; hoy el SO tiene `competencias_empleado` y `evaluaciones_desempeno`: **redundancia a resolver**); `gestion_accesos` (ERP). |

## 6. Redundancias detectadas

1. `competencias_empleado`, `evaluaciones_desempeno`, `evaluaciones_medicas_ocupacionales`, `descripcion_sociodemografica` ↔ módulo Gestión Colaboradores/empleados del ERP.
2. `gestion_accesos` ↔ permisos del ERP.
3. `responsable`, `aprobador`, `subido_por`, `persona` guardados como **texto libre** (sin vínculo a usuarios del ERP): impide escalar a suplentes y auditar.
4. Alertas del ERP (`alertas-activas`) ↔ futuro motor del SO: reutilizar, no duplicar.
5. `cursos_academy` y `evaluaciones_academy` ↔ posible Academy propio.

## 7. Seguridad, rendimiento y costos

- ✔ RLS en 54/54 tablas; `anon` sin acceso; sin `service_role` en el front.
- ⚠ Protección de contraseñas filtradas desactivada (aviso Supabase).
- ⚠ Aviso de funciones `security definer` ejecutables por `anon` y `authenticated` y con `search_path` mutable: **pendiente de identificar cuáles** (las 4 del SO sí fijan `search_path`).
- ⚠ Confusión de roles: clientas y personal comparten Auth; un error de política expone todo (ya ocurrió antes del 14-nov).
- ⚠ `fn_rol_actual()` es el único punto de control; si el ERP cambia nombres de rol, el SO se rompe.
- ⚠ GitHub Pages y «Exposed schemas» se apagaron solos antes (ver resumen del orquestador).
- ⚠ CDN sin versión fija y sin SRI; `index.html` monolítico de 285 KB (difícil de mantener y revisar).
- ⚠ Sin staging separado: **no se probaron escrituras**; se recomienda crear una rama/proyecto de pruebas antes de Fase 1.
- Rendimiento: volumen mínimo (filas casi cero); sin índices específicos de búsqueda. Sin riesgo hoy.
- Costos: sin gasto propio visible (Pages, Supabase del ERP). El costo nuevo vendría de IA (proveedor sin decidir) y de correo/WhatsApp para alertas. **Pendiente de verificación humana:** plan de Supabase y límites.

## 8. Inmutabilidad documental (solo definiciones)

| Pregunta | Hallazgo |
|---|---|
| ¿Se pueden alterar archivos? | No hay archivos guardados (`url_archivo` vacío en los 18); cuando existan, no hay bucket del SO ni política de solo-agregar. |
| ¿Hashes? | No existen columnas ni funciones de hash. |
| ¿Versiones? | `version` es texto editable; `historial_versiones_documento` vacío, con política `so_admin_todo` (UPDATE/DELETE permitidos). |
| ¿Historial? | Sin triggers de auditoría; `actualizado_en` sin trigger. |
| ¿Quién puede alterar? | Cualquier administradora (política ALL) y `service_role`. |
**Conclusión:** hoy NO es inmutable. Fase 1 debe agregar versiones solo-inserción, hash SHA-256 (pgcrypto), bitácora y bloqueo de UPDATE/DELETE por trigger.

## 9. Respaldos

No se puede comprobar desde aquí (consola de Supabase: copias diarias/PITR, y si hay copia **externa e independiente**, p. ej. otro proveedor). **Pendiente de verificación humana.** Los datos del SO son recreables solo parcialmente; los documentos en borrador viven únicamente en la base.

## 10. Matriz de brechas

| Objetivo | Hoy | Brecha | Esfuerzo |
|---|---|---|---|
| Codificación PA-02-RIT-v03 | código texto libre | función de código + validación | S |
| Estados BORRADOR→…→ANULADO | 4 estados, faltan 2 | ampliar check, transiciones, aprobador real | M |
| Versionamiento inmutable + hash | no | tabla de versiones solo-inserción, trigger, SHA-256, bucket privado | M |
| Vigencia diaria (Bogotá) | campo fecha | pg_cron + función a obsoleto/alerta | S |
| PDF con QR / Excel | no | generador (Edge Function) y página pública de verificación | M |
| Buscador global | no | `unaccent`+`pg_trgm`+tsvector español, luego vectores | M |
| Motor de alertas + semáforo | semáforo manual | reglas determinísticas, escalamiento, cierre con evidencia | L |
| Copiloto solo lectura | no | vistas de solo lectura + IA con citas | L |
| Tablero PEM-01 | tabla vacía | cálculo desde ERP/SO | M |
| Externos con vencimiento y MFA | no | depende del ERP (Chat 9) | M (ERP) |
| ICS / Google Calendar | función de sincronización existe | feed ICS firmado | S |
| Respaldos independientes | desconocido | definir RPO/RTO | S-M |

## 11. Riesgos

1. **Alto:** documentos modificables (auditoría ISO/Fondo Emprender). 2. **Alto:** respaldos no verificados. 3. **Medio:** dependencia de `fn_rol_actual()` y del Worker del ERP. 4. **Medio:** mudanza de dominio del ERP (13-dic) rompe sesión y rutas. 5. **Medio:** un solo `index.html` crecerá sin control. 6. **Medio:** IA y datos personales (SG-SST) sin política de retención. 7. **Bajo:** CDN sin versión fija.

## 12. Plan por fases (propuesto, no iniciado)

- **Fase 1 (≈2–3 semanas):** staging; ficha de documento con estados, versión inmutable + hash + bitácora; bucket privado; vigencia diaria; permisos por proceso vía ERP; respaldo externo verificado.
- **Fase 2 (≈2–3 semanas):** alertas determinísticas con semáforo y suplentes; tareas con evidencia; tablero PEM-01; ICS.
- **Fase 3 (≈2 semanas):** buscador de texto completo; PDF con QR; Excel.
- **Fase 4 (≈2–3 semanas):** copiloto de solo lectura con fuentes; búsqueda semántica; externos con vencimiento y MFA.
- Partir `index.html` en módulos solo cuando se toque cada sección.

## 13. Decisiones pendientes de la Dirección (no tomadas)

**Decidido (24-nov-2026, informado por el Orquestador general; Jennifer aprobó):** la Dirección = Jennifer (fundadora) y Sara (Gerente General). Como Sara construye y administra, las aprobaciones que afecten su propio trabajo las revisa Jennifer. Esto NO aprueba la Fase 1.

**Propuesta para «Administradores de la organización»** (según roles reales del ERP, sin nombres): hoy hay 2 usuarios activos con rol `administrador` (se proponen estos dos; confirmar que son Jennifer y Sara), 1 cajero activo y 2 contadores (1 activo, 1 inactivo). Cajero y contador quedan fuera. Pendiente de confirmación de la Dirección.

**Siguen sin definir:** responsables de PA-07, PA-08, PEM-02, PEM-03, PEM-04, PM-05 · suplentes · tope de gasto externo · proveedor de IA · retención de datos · RPO/RTO · responsable de migraciones · segundo revisor.

## 14. Verificaciones humanas pendientes

1. Supabase: duración de JWT, sesión máxima, MFA, protección de contraseñas filtradas, plan, copias/PITR, «Exposed schemas».
2. Respaldo externo independiente: ¿existe? ¿cada cuánto? ¿se ha restaurado alguna vez?
3. GitHub Pages: dominio, HTTPS, quién administra el repo.
4. Cloudflare/Worker: despliegue vigente de los endpoints `/api/pos/so/*`.
5. Quién refresca `cache_resumen_negocio`.
6. Cuáles son las funciones `security definer` expuestas del aviso de Supabase.
7. ERP Chat 9: estado de Gestión Colaboradores y permisos por proceso/externos.
8. Contratos y costos con proveedores de IA, correo y WhatsApp.
9. Probar la interfaz real con cada rol (no se hizo; solo lectura).
10. Falta `CLAUDE.md` en el repo SO: confirmar si debe existir.
