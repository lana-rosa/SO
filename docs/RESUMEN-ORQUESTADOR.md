# SO (Lana Rosa OS) — resumen para el orquestador general · 17-nov-2026 (chat del SO archivado; lo retoma el Orquestador General)

**Qué es:** gestión del negocio (21 procesos, 6 líneas, riesgos, indicadores, documentos, SG-SST, calidad). Front `lana-rosa.github.io/SO/` (repo `lana-rosa/SO`, un `index.html`); BD = Supabase del ERP `ngjoognzvehwjtpqwrqe`, schema `sistema_operativo` (54 tablas); usa endpoints `/api/pos/so/*` del Worker del ERP.

**Chats del SO:** solo "Chat 0. Orquestador SO" (este); no hay chats temáticos del SO abiertos.

**Decisiones vigentes**
- Integración fase 1 = enlace "Sistema Operativo" en el menú del ERP; lo hace el Chat 8 del ERP. El SO no toca el repo ERP ni el Worker.
- Ven el SO: administrador y "Gerencia SO" todo; "Taller SO" solo PM-02 y PA-07; cajero, contador y clientas nada. Para el menú se usa el mecanismo de permisos del Chat 9 del ERP.
- 5S y SG-SST viven en el SO; el ERP no los duplica.
- Seguridad RLS por rol APLICADA el 14-nov (`so_seguridad_rls_por_rol`; reversa en `sql/`). Verificado: clienta 0, admin todo, taller limitado, anon denegado.
- Cambios a la BD del SO: primero prueba con rollback y después el sí de Sara.

**Pendientes de la dueña**
- Aprobar el PR lana-rosa/SO#2 (tarjeta "Ventas del período" con datos reales y fecha en "Actualizado"). El PR #1 ya está fusionado.
- Entrar al SO y confirmar que todo carga tras el cambio de seguridad.
- Definir el rol "Tienda SO" (Manuela) cuando el Chat 9 cierre los permisos de Tienda.

**Pendientes técnicos del SO**
- La caché `cache_resumen_negocio` está congelada desde el 19-sep (el cron del Worker no la refresca); ya se avisó al Orquestador General. El Dashboard compensa trayendo los datos en vivo.
- "Goku" de prueba aparece en Inventario crítico (se corrige en el ERP).
- Documentos en borrador: DOC-SST-001..007, Reglamento Interno, Manual de Funciones, manuales PM-01..05, TEC, CAL, AMB.
- Botón "Volver" siempre lleva al Dashboard; el diagrama de flujo no tiene ramas.

**Riesgos para la apertura (13-dic)**
- Mudanza del ERP a otro dominio: el SO pedirá iniciar sesión otra vez. Decidir dónde vive el SO (p. ej. `erp.lanarosacrochet.com/so/`).
- Fondo Emprender exige SG-SST y documentos formales: los borradores siguen sin redactar.
- Historial de incidentes en esta configuración: GitHub Pages del SO y "Exposed schemas" de Supabase ya se apagaron solos una vez; revisarlos antes de la apertura.
- Si alguien queda con rol taller sin "Taller SO", verá Producción y SST; revisar los roles al crear empleados.
