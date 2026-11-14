-- =====================================================================
-- Seguridad del Sistema Operativo (schema sistema_operativo)
-- Fecha: 2026-11-14 · Estado: PROPUESTA, NO APLICADA
--
-- Problema: las 54 tablas tienen la política "so_authenticated_all"
-- (USING true / WITH CHECK true para authenticated), y en este mismo
-- proyecto inician sesión las clientas de la tienda web. Cualquiera de
-- ellas podía leer y modificar todo el SO. Además hay grants SELECT a anon.
--
-- Reglas nuevas:
--   * administrador (incluye "Gerencia SO", cuyo rol base es administrador):
--     acceso total.
--   * taller (incluye "Taller SO"): SOLO LECTURA de los procesos
--     PM-02 (Producción) y PA-07 (SST), sin datos personales sensibles
--     (evaluaciones médicas y perfil sociodemográfico quedan fuera).
--     Puede crear/editar tareas, no conformidades y auditorías 5S de PM-02.
--   * cajero, contador, clientas, anon: nada.
--   * service_role (Worker, cron de la caché) no cambia: se salta RLS.
-- =====================================================================
begin;

-- 1) Funciones de apoyo (security definer: leen procesos sin depender de RLS)
create or replace function sistema_operativo.fn_es_admin_so()
returns boolean language sql stable security definer
set search_path = public, pg_temp
as $$ select coalesce(public.fn_rol_actual() = 'administrador', false) $$;

create or replace function sistema_operativo.fn_es_taller_so()
returns boolean language sql stable security definer
set search_path = public, pg_temp
as $$ select coalesce(public.fn_rol_actual() = 'taller', false) $$;

-- Procesos que el Taller puede ver
create or replace function sistema_operativo.fn_proceso_visible_taller(p_proceso_id uuid)
returns boolean language sql stable security definer
set search_path = sistema_operativo, public, pg_temp
as $$
  select exists (select 1 from sistema_operativo.procesos
                 where id = p_proceso_id and codigo in ('PM-02','PA-07'))
$$;

-- Procesos donde el Taller puede escribir
create or replace function sistema_operativo.fn_proceso_editable_taller(p_proceso_id uuid)
returns boolean language sql stable security definer
set search_path = sistema_operativo, public, pg_temp
as $$
  select exists (select 1 from sistema_operativo.procesos
                 where id = p_proceso_id and codigo = 'PM-02')
$$;

revoke all on function sistema_operativo.fn_es_admin_so(),
                       sistema_operativo.fn_es_taller_so(),
                       sistema_operativo.fn_proceso_visible_taller(uuid),
                       sistema_operativo.fn_proceso_editable_taller(uuid)
  from public, anon;
grant execute on function sistema_operativo.fn_es_admin_so(),
                          sistema_operativo.fn_es_taller_so(),
                          sistema_operativo.fn_proceso_visible_taller(uuid),
                          sistema_operativo.fn_proceso_editable_taller(uuid)
  to authenticated, service_role;

-- 2) Quitar a anon todo acceso al schema
revoke all on all tables    in schema sistema_operativo from anon;
revoke all on all sequences in schema sistema_operativo from anon;
revoke all on all functions in schema sistema_operativo from anon;
alter default privileges in schema sistema_operativo revoke all on tables    from anon;
alter default privileges in schema sistema_operativo revoke all on sequences from anon;
alter default privileges in schema sistema_operativo revoke all on functions from anon;

-- 3) Borrar las políticas abiertas y crear la de administrador en TODAS las tablas
do $$
declare t record; pol record;
begin
  for pol in select tablename, policyname from pg_policies
             where schemaname = 'sistema_operativo'
               and policyname in ('so_authenticated_all','so_authenticated_read_cache') loop
    execute format('drop policy %I on sistema_operativo.%I', pol.policyname, pol.tablename);
  end loop;

  for t in select tablename from pg_tables where schemaname = 'sistema_operativo' loop
    execute format('alter table sistema_operativo.%I enable row level security', t.tablename);
    execute format($p$create policy so_admin_todo on sistema_operativo.%I
                      for all to authenticated
                      using (sistema_operativo.fn_es_admin_so())
                      with check (sistema_operativo.fn_es_admin_so())$p$, t.tablename);
  end loop;
end $$;

-- 4) Lectura para Taller
-- 4a) Tablas con proceso_id (sin datos personales sensibles)
do $$
declare t text;
begin
  foreach t in array array[
    'pasos_flujo','tareas','documentos','indicadores','riesgos','proyectos',
    'no_conformidades','auditorias_5s',
    'identificacion_peligros','capacitaciones_sst','entrega_epp',
    'responsable_sst','accidentes_incidentes','sgsst_autoevaluacion'
  ] loop
    execute format($p$create policy so_taller_lectura on sistema_operativo.%I
                      for select to authenticated
                      using (sistema_operativo.fn_es_taller_so()
                             and sistema_operativo.fn_proceso_visible_taller(proceso_id))$p$, t);
  end loop;
end $$;

-- 4b) Catálogos
create policy so_taller_lectura on sistema_operativo.procesos
  for select to authenticated
  using (sistema_operativo.fn_es_taller_so() and codigo in ('PM-02','PA-07'));
create policy so_taller_lectura on sistema_operativo.lineas_estrategicas
  for select to authenticated
  using (sistema_operativo.fn_es_taller_so());

-- 5) Escritura para Taller (solo PM-02; sin borrar)
do $$
declare t text;
begin
  foreach t in array array['tareas','no_conformidades','auditorias_5s'] loop
    execute format($p$create policy so_taller_crear on sistema_operativo.%I
                      for insert to authenticated
                      with check (sistema_operativo.fn_es_taller_so()
                                  and sistema_operativo.fn_proceso_editable_taller(proceso_id))$p$, t);
    execute format($p$create policy so_taller_editar on sistema_operativo.%I
                      for update to authenticated
                      using (sistema_operativo.fn_es_taller_so()
                             and sistema_operativo.fn_proceso_editable_taller(proceso_id))
                      with check (sistema_operativo.fn_es_taller_so()
                                  and sistema_operativo.fn_proceso_editable_taller(proceso_id))$p$, t);
  end loop;
end $$;

commit;
