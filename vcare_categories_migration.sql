-- Run once in Supabase SQL Editor BEFORE publishing the updated HTML.
-- Allows custom categories and adds a staff-managed category list.
ALTER TABLE public.inventory DROP CONSTRAINT IF EXISTS inventory_category_check;
CREATE TABLE IF NOT EXISTS public.inventory_categories (
 name text PRIMARY KEY CHECK (char_length(trim(name)) BETWEEN 1 AND 60),
 created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.inventory_categories(name) VALUES ('Laptop'),('RAM'),('SSD'),('Battery'),('Charger'),('Keyboard'),('Screen'),('Accessories') ON CONFLICT DO NOTHING;
INSERT INTO public.inventory_categories(name) SELECT DISTINCT category FROM public.inventory WHERE category IS NOT NULL ON CONFLICT DO NOTHING;
ALTER TABLE public.inventory_categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS categories_staff_read ON public.inventory_categories;
CREATE POLICY categories_staff_read ON public.inventory_categories FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS categories_staff_insert ON public.inventory_categories;
CREATE POLICY categories_staff_insert ON public.inventory_categories FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS categories_staff_delete ON public.inventory_categories;
CREATE POLICY categories_staff_delete ON public.inventory_categories FOR DELETE TO authenticated USING (true);
GRANT SELECT,INSERT,DELETE ON public.inventory_categories TO authenticated;
