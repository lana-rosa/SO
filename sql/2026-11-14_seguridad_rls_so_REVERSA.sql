-- Reversa de 2026-11-14_seguridad_rls_so.sql: vuelve EXACTAMENTE al estado
-- anterior (abierto). Usar solo si la migración rompe algo y hay que volver ya.
begin;
do $$
declare pol record; t record;
begin
  for pol in select tablename, policyname from pg_policies
             where schemaname = 'sistema_operativo'
               and policyname in ('so_admin_todo','so_taller_lectura','so_taller_crear','so_taller_editar') loop
    execute format('drop policy %I on sistema_operativo.%I', pol.policyname, pol.tablename);
  end loop;
  for t in select tablename from pg_tables where schemaname = 'sistema_operativo' and tablename <> 'cache_resumen_negocio' loop
    execute format('create policy so_authenticated_all on sistema_operativo.%I for all to authenticated using (true) with check (true)', t.tablename);
  end loop;
end $$;
create policy so_authenticated_read_cache on sistema_operativo.cache_resumen_negocio for select to authenticated using (true);
grant select on all tables in schema sistema_operativo to anon;
alter default privileges in schema sistema_operativo grant select on tables to anon;
drop function if exists sistema_operativo.fn_proceso_editable_taller(uuid);
drop function if exists sistema_operativo.fn_proceso_visible_taller(uuid);
drop function if exists sistema_operativo.fn_es_taller_so();
drop function if exists sistema_operativo.fn_es_admin_so();
commit;
