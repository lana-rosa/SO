-- =====================================================================
-- Fase 1 · Paso 1 — Control documental inmutable (schema sistema_operativo)
-- Fecha: 2026-11-24 · Estado: PROPUESTA, NO APLICADA (espera revisión de
-- seguridad y el «sí» de Jennifer). Reversa: *_REVERSA.sql
-- Reutiliza historial_versiones_documento; no toca los 21 procesos ni los
-- códigos DOC-* existentes. Los 18 documentos actuales están en borrador.
-- =====================================================================
begin;

-- 1) Estados completos (BORRADOR→EN REVISIÓN→APROBADO→VIGENTE→OBSOLETO/ANULADO)
do $$ declare c text; begin
  select conname into c from pg_constraint
   where conrelid='sistema_operativo.documentos'::regclass and contype='c'
     and pg_get_constraintdef(oid) ilike '%estado%';
  if c is not null then execute format('alter table sistema_operativo.documentos drop constraint %I', c); end if;
end $$;
alter table sistema_operativo.documentos
  add constraint documentos_estado_check
  check (estado in ('borrador','en_revision','aprobado','vigente','obsoleto','anulado')),
  add column if not exists tipo_documento text;

-- 2) Versiones: columnas nuevas en el historial existente + solo-agregar
alter table sistema_operativo.historial_versiones_documento
  add column if not exists hash_sha256 text,
  add column if not exists archivo_ref text,
  add column if not exists estado text,
  add column if not exists creado_por uuid default auth.uid();

create or replace function sistema_operativo.fn_hash_texto(p text)
returns text language sql immutable
set search_path = pg_temp
as $$ select encode(extensions.digest(convert_to(coalesce(p,''),'UTF8'),'sha256'),'hex') $$;

create or replace function sistema_operativo.fn_bloquear_cambios()
returns trigger language plpgsql set search_path = pg_temp
as $$ begin
  raise exception 'Registro inmutable: % no permite % (control documental)', tg_table_name, tg_op;
end $$;

create or replace function sistema_operativo.fn_version_hash()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$ declare d record; begin
  select codigo, nombre into d from sistema_operativo.documentos where id = new.documento_id;
  if new.hash_sha256 is null then
    new.hash_sha256 := sistema_operativo.fn_hash_texto(
      coalesce(d.codigo,'')||'|'||coalesce(d.nombre,'')||'|'||new.version||'|'||coalesce(new.archivo_ref,'')||'|'||coalesce(new.cambios,''));
  end if;
  return new;
end $$;

create trigger trg_version_hash before insert on sistema_operativo.historial_versiones_documento
  for each row execute function sistema_operativo.fn_version_hash();
create trigger trg_version_inmutable before update or delete on sistema_operativo.historial_versiones_documento
  for each row execute function sistema_operativo.fn_bloquear_cambios();
create trigger trg_version_no_truncate before truncate on sistema_operativo.historial_versiones_documento
  for each statement execute function sistema_operativo.fn_bloquear_cambios();

-- 3) Bitácora de eventos (solo-agregar)
create table sistema_operativo.documento_eventos (
  id uuid primary key default gen_random_uuid(),
  documento_id uuid not null references sistema_operativo.documentos(id) on delete restrict,
  evento text not null,
  estado_anterior text, estado_nuevo text,
  usuario uuid default auth.uid(),
  detalle jsonb,
  creado_en timestamptz not null default now()
);
create index on sistema_operativo.documento_eventos (documento_id, creado_en);
alter table sistema_operativo.documento_eventos enable row level security;
create policy so_admin_leer on sistema_operativo.documento_eventos for select to authenticated
  using (sistema_operativo.fn_es_admin_so());
create policy so_admin_insertar on sistema_operativo.documento_eventos for insert to authenticated
  with check (sistema_operativo.fn_es_admin_so());
revoke all on sistema_operativo.documento_eventos from anon;
grant select, insert on sistema_operativo.documento_eventos to authenticated;
grant select, insert on sistema_operativo.documento_eventos to service_role;
create trigger trg_evento_inmutable before update or delete on sistema_operativo.documento_eventos
  for each row execute function sistema_operativo.fn_bloquear_cambios();
create trigger trg_evento_no_truncate before truncate on sistema_operativo.documento_eventos
  for each statement execute function sistema_operativo.fn_bloquear_cambios();

-- 4) Reglas sobre documentos: transiciones válidas, congelar contenido aprobado, sin borrar
create or replace function sistema_operativo.fn_documento_reglas()
returns trigger language plpgsql set search_path = pg_temp
as $$ begin
  if tg_op = 'DELETE' then
    if old.estado <> 'borrador' then
      raise exception 'No se puede borrar un documento en estado %; use ANULADO', old.estado;
    end if;
    return old;
  end if;
  if new.estado is distinct from old.estado then
    if not ((old.estado,new.estado) in (
      ('borrador','en_revision'),('borrador','anulado'),
      ('en_revision','borrador'),('en_revision','aprobado'),
      ('aprobado','vigente'),('aprobado','en_revision'),
      ('vigente','obsoleto'),('vigente','anulado'))) then
      raise exception 'Transición no permitida: % → %', old.estado, new.estado;
    end if;
  end if;
  if old.estado in ('aprobado','vigente','obsoleto','anulado') and (
       new.codigo is distinct from old.codigo or new.nombre is distinct from old.nombre
    or new.version is distinct from old.version or new.proceso_id is distinct from old.proceso_id
    or new.url_archivo is distinct from old.url_archivo) then
    raise exception 'Documento % congelado: cree una nueva versión', old.estado;
  end if;
  return new;
end $$;

create or replace function sistema_operativo.fn_documento_bitacora()
returns trigger language plpgsql security definer set search_path = public, pg_temp
as $$ begin
  if tg_op = 'INSERT' then
    insert into sistema_operativo.documento_eventos(documento_id,evento,estado_nuevo) values (new.id,'creado',new.estado);
  elsif new.estado is distinct from old.estado then
    insert into sistema_operativo.documento_eventos(documento_id,evento,estado_anterior,estado_nuevo)
      values (new.id,'cambio_estado',old.estado,new.estado);
  end if;
  return new;
end $$;

create trigger trg_documento_reglas before update or delete on sistema_operativo.documentos
  for each row execute function sistema_operativo.fn_documento_reglas();
create trigger trg_documento_bitacora after insert or update on sistema_operativo.documentos
  for each row execute function sistema_operativo.fn_documento_bitacora();

-- 5) Codificación PA-02-RIT-v03 (no cambia los códigos DOC-* existentes)
create or replace function sistema_operativo.fn_codigo_documento(p_proceso uuid, p_tipo text, p_version int)
returns text language sql stable security definer set search_path = public, pg_temp
as $$ select pr.codigo||'-'||upper(p_tipo)||'-v'||lpad(p_version::text,2,'0')
        from sistema_operativo.procesos pr where pr.id = p_proceso $$;

-- 6) Vigencia por fecha (America/Bogota). El cron diario se propone aparte.
create or replace function sistema_operativo.fn_vencer_documentos()
returns integer language plpgsql security definer set search_path = public, pg_temp
as $$ declare n int; begin
  update sistema_operativo.documentos set estado='obsoleto', actualizado_en=now()
   where estado='vigente' and fecha_vencimiento < (now() at time zone 'America/Bogota')::date;
  get diagnostics n = row_count; return n;
end $$;

-- 7) Mínimo privilegio en funciones nuevas
revoke execute on function sistema_operativo.fn_hash_texto(text), sistema_operativo.fn_bloquear_cambios(),
  sistema_operativo.fn_version_hash(), sistema_operativo.fn_documento_reglas(), sistema_operativo.fn_documento_bitacora(),
  sistema_operativo.fn_codigo_documento(uuid,text,int), sistema_operativo.fn_vencer_documentos() from public, anon, authenticated;
grant execute on function sistema_operativo.fn_codigo_documento(uuid,text,int) to authenticated;

commit;
