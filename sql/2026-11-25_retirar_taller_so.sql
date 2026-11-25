-- Retira el acceso del rol «taller» al SO y los roles personalizados «Gerencia SO» y «Taller SO»
-- (0 usuarios los usaban). Regla de Jennifer: el SO solo para administradoras.
-- Fecha: 2026-11-25 · Estado: APLICADA el 25-nov-2026 con el sí de Jennifer. Reversa: *_REVERSA.sql
-- Se conservan las funciones fn_es_taller_so / fn_proceso_* (sin uso) para que la reversa sea exacta.
do $$ declare pol record; begin
  for pol in select tablename, policyname from pg_policies
             where schemaname='sistema_operativo' and policyname in ('so_taller_lectura','so_taller_crear','so_taller_editar') loop
    execute format('drop policy %I on sistema_operativo.%I', pol.policyname, pol.tablename);
  end loop;
end $$;
delete from public.roles_personalizados rp
 where rp.nombre in ('Gerencia SO','Taller SO')
   and not exists (select 1 from public.usuarios_roles u where u.rol_personalizado_id = rp.id);
