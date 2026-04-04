-- Adiciona colunas novas sem apagar dados existentes
ALTER TABLE public.objetivos ADD COLUMN IF NOT EXISTS tipo_obj TEXT DEFAULT 'unico' CHECK (tipo_obj IN ('unico','mensal','anual'));
ALTER TABLE public.metas    ADD COLUMN IF NOT EXISTS recorrencia TEXT DEFAULT 'mensal' CHECK (recorrencia IN ('mensal','unico','anual'));
ALTER TABLE public.metas    ALTER COLUMN tipo TYPE TEXT;
-- Adiciona moeda ao check constraint de metas.tipo
ALTER TABLE public.metas DROP CONSTRAINT IF EXISTS metas_tipo_check;
ALTER TABLE public.metas ADD CONSTRAINT metas_tipo_check CHECK (tipo IN ('dias','quantidade','moeda'));
