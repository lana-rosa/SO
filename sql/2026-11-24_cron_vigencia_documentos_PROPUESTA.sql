-- Fase 1 · Paso 1b — PROPUESTA, NO APLICADA. Requiere el «sí» de Jennifer.
-- Ejecuta fn_vencer_documentos() (ya creada) todos los días 6:00 a. m. hora Bogotá
-- (= 11:00 UTC; Colombia no usa horario de verano). Pasa a OBSOLETO los VIGENTES con
-- fecha_vencimiento anterior a hoy; cada cambio queda en documento_eventos.
-- No corre sábados 9-7 porque a las 6:00 a. m. queda fuera de esa franja; el 12 y 13-dic
-- NO hay documentos vigentes que dependan de esto, pero si se quiere excluir, pausar el job.
select cron.schedule('so-vigencia-documentos', '0 11 * * *', $$select sistema_operativo.fn_vencer_documentos()$$);
-- REVERSA: select cron.unschedule('so-vigencia-documentos');
