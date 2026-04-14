-- ============================================================
-- PLANEJADOR DE CONQUISTAS — Schema Supabase
-- Execute no SQL Editor do Supabase
-- ============================================================

-- Drop policies primeiro (evita erro de duplicata)
DROP POLICY IF EXISTS "usuarios_own"  ON public.usuarios;
DROP POLICY IF EXISTS "areas_own"     ON public.areas;
DROP POLICY IF EXISTS "objetivos_own" ON public.objetivos;
DROP POLICY IF EXISTS "metas_own"     ON public.metas;
DROP POLICY IF EXISTS "checkins_own"  ON public.checkins;

-- ============================================================
-- TABELAS
-- ============================================================

CREATE TABLE IF NOT EXISTS public.usuarios (
  id                  UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nome                TEXT NOT NULL,
  email               TEXT NOT NULL,
  plano               TEXT DEFAULT 'trial',
  xp                  INTEGER DEFAULT 0,
  instagram           TEXT,
  profissao           TEXT,
  nascimento          DATE,
  declaracao_assinada BOOLEAN DEFAULT false,
  declaracao_data     TIMESTAMPTZ,
  criado_em           TIMESTAMPTZ DEFAULT NOW(),
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- Colunas adicionadas posteriormente (idempotente)
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS xp                  INTEGER DEFAULT 0;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS instagram           TEXT;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS profissao           TEXT;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS nascimento          DATE;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS declaracao_assinada BOOLEAN DEFAULT false;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS declaracao_data     TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS public.areas (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nome       TEXT NOT NULL,
  icon       TEXT DEFAULT '📌',
  cor        TEXT DEFAULT '#6366f1',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.objetivos (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  area_id    UUID NOT NULL REFERENCES public.areas(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nome       TEXT NOT NULL,
  descricao  TEXT,
  inicio     DATE,
  fim        DATE,
  prioridade TEXT DEFAULT 'media' CHECK (prioridade IN ('alta','media','baixa')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.metas (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  obj_id     UUID NOT NULL REFERENCES public.objetivos(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nome       TEXT NOT NULL,
  tipo       TEXT DEFAULT 'dias' CHECK (tipo IN ('dias','quantidade')),
  qtd_meta   NUMERIC DEFAULT 0,
  inicio     DATE,
  fim        DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.checkins (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meta_id    UUID NOT NULL REFERENCES public.metas(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  data       DATE NOT NULL,
  status     TEXT DEFAULT 'ok' CHECK (status IN ('ok','fail')),
  qtd        NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(meta_id, data)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.usuarios  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.areas     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.objetivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.metas     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkins  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "usuarios_own"  ON public.usuarios  FOR ALL USING (auth.uid() = id);
CREATE POLICY "areas_own"     ON public.areas     FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "objetivos_own" ON public.objetivos FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "metas_own"     ON public.metas     FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "checkins_own"  ON public.checkins  FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- MAAS (Mapa de Auto Avaliação Sistêmica)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.maas (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dados      JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.maas ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "maas_own" ON public.maas;
CREATE POLICY "maas_own" ON public.maas FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- MASD (Mapa de Avaliação Sistêmica Direcionada)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.masd (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dados      JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.masd ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "masd_own" ON public.masd;
CREATE POLICY "masd_own" ON public.masd FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- JORNADA DO LEITOR CORE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.jornada (
  user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  caps        JSONB DEFAULT '{}'::jsonb,
  notif       BOOLEAN DEFAULT false,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.jornada ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "jornada_own" ON public.jornada;
CREATE POLICY "jornada_own" ON public.jornada FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- TRIGGER: cria perfil automaticamente ao cadastrar
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.usuarios (id, nome, email, plano, criado_em)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nome', split_part(NEW.email,'@',1)),
    NEW.email,
    'trial',
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
