-- Reversa de 2026-11-24_documentos_inmutables.sql (no destruye documentos).
-- Si ya hay eventos/versiones, la reversa los conserva en tablas *_respaldo.
begin;
drop trigger if exists trg_documento_bitacora on sistema_operativo.documentos;
drop trigger if exists trg_documento_reglas on sistema_operativo.documentos;
drop trigger if exists trg_version_hash on sistema_operativo.historial_versiones_documento;
drop trigger if exists trg_version_inmutable on sistema_operativo.historial_versiones_documento;
drop trigger if exists trg_version_no_truncate on sistema_operativo.historial_versiones_documento;
drop trigger if exists trg_evento_inmutable on sistema_operativo.documento_eventos;
drop trigger if exists trg_evento_no_truncate on sistema_operativo.documento_eventos;
create table if not exists sistema_operativo.documento_eventos_respaldo as table sistema_operativo.documento_eventos;
drop table sistema_operativo.documento_eventos;
drop function if exists sistema_operativo.fn_vencer_documentos(), sistema_operativo.fn_codigo_documento(uuid,text,int),
  sistema_operativo.fn_documento_bitacora(), sistema_operativo.fn_documento_reglas(), sistema_operativo.fn_version_hash(),
  sistema_operativo.fn_bloquear_cambios(), sistema_operativo.fn_hash_texto(text);
alter table sistema_operativo.documentos drop constraint documentos_estado_check,
  add constraint documentos_estado_check check (estado in ('borrador','vigente','en_revision','obsoleto'));
-- Columnas nuevas se conservan (inofensivas): tipo_documento, hash_sha256, archivo_ref, estado, creado_por.
commit;
