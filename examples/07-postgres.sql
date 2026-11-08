SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SELECT pg_catalog.set_config('search_path', '', false);

CREATE TABLE public.proyecto (
    id integer NOT NULL GENERATED ALWAYS AS IDENTITY,
    nombre character varying(120) NOT NULL,
    etiquetas text[],
    presupuesto numeric(14,2),
    inicio timestamp with time zone NOT NULL,
    costo_total numeric(14,2) GENERATED ALWAYS AS ((presupuesto * 1.19)) STORED
);

CREATE TABLE public.tarea (
    id bigint NOT NULL,
    proyecto_id integer NOT NULL,
    titulo text NOT NULL,
    peso double precision,
    meta jsonb
);

CREATE TABLE public.bitacora (
    id bigint NOT NULL,
    proyecto_id integer,
    registrado_en timestamp without time zone NOT NULL,
    detalle text
) PARTITION BY RANGE (registrado_en);

CREATE TABLE public.bitacora_2025 PARTITION OF public.bitacora
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

ALTER TABLE ONLY public.proyecto
    ADD CONSTRAINT proyecto_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.tarea
    ADD CONSTRAINT tarea_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.bitacora
    ADD CONSTRAINT bitacora_pkey PRIMARY KEY (id, registrado_en);

ALTER TABLE ONLY public.tarea
    ADD CONSTRAINT tarea_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES public.proyecto(id) ON DELETE CASCADE;

ALTER TABLE public.bitacora
    ADD CONSTRAINT bitacora_proyecto_id_fkey FOREIGN KEY (proyecto_id) REFERENCES public.proyecto(id);

COMMENT ON TABLE public.proyecto IS 'Proyectos activos e históricos';
COMMENT ON COLUMN public.tarea.peso IS 'Peso relativo dentro del proyecto';
