-- Reversa de 2026-11-25_retirar_taller_so.sql: devuelve las políticas del rol taller y los 2 roles.
do $$ declare t text; begin
  foreach t in array array['pasos_flujo','tareas','documentos','indicadores','riesgos','proyectos','no_conformidades','auditorias_5s','identificacion_peligros','capacitaciones_sst','entrega_epp','responsable_sst','accidentes_incidentes','sgsst_autoevaluacion'] loop
    execute format('create policy so_taller_lectura on sistema_operativo.%I for select to authenticated using (sistema_operativo.fn_es_taller_so() and sistema_operativo.fn_proceso_visible_taller(proceso_id))', t);
  end loop;
  foreach t in array array['tareas','no_conformidades','auditorias_5s'] loop
    execute format('create policy so_taller_crear on sistema_operativo.%I for insert to authenticated with check (sistema_operativo.fn_es_taller_so() and sistema_operativo.fn_proceso_editable_taller(proceso_id))', t);
    execute format('create policy so_taller_editar on sistema_operativo.%I for update to authenticated using (sistema_operativo.fn_es_taller_so() and sistema_operativo.fn_proceso_editable_taller(proceso_id)) with check (sistema_operativo.fn_es_taller_so() and sistema_operativo.fn_proceso_editable_taller(proceso_id))', t);
  end loop;
end $$;
create policy so_taller_lectura on sistema_operativo.procesos for select to authenticated using (sistema_operativo.fn_es_taller_so() and codigo = any (array['PM-02','PA-07']));
create policy so_taller_lectura on sistema_operativo.lineas_estrategicas for select to authenticated using (sistema_operativo.fn_es_taller_so());
insert into public.roles_personalizados(id,nombre,rol_base,descripcion,created_at) values
 ('a0c45b18-caaa-4692-ae61-c85161ed91a6','Taller SO','taller','Acceso al Sistema Operativo desde el rol Taller — pensado para quien lidera o participa en el taller y necesita ver/gestionar procesos, proyectos y tareas del SO.','2026-08-15T15:59:48.354587+00'),
 ('4d5b5769-1921-4eef-915d-ea204c9f158f','Gerencia SO','administrador','Acceso completo al Sistema Operativo (procesos, proyectos, riesgos, indicadores) además de todo lo que ya incluye el rol Administrador en el ERP.','2026-08-15T15:59:48.354587+00')
on conflict (id) do nothing;
