-- Drops legacy lookup and join tables that are not referenced by the current app.
-- Tables intentionally kept:
--   public.users
--   public.clothing_items
--   public.clothing_item_images
--   public.clothing_ai_analyses
--   public.clothing_ai_predictions

drop table if exists public.clothing_item_tags cascade;
drop table if exists public.clothing_item_seasons cascade;
drop table if exists public.clothing_item_occasions cascade;
drop table if exists public.clothing_item_attributes cascade;

drop table if exists public.user_style_preferences cascade;

drop table if exists public.subcategories cascade;
drop table if exists public.categories cascade;
drop table if exists public.colors cascade;
drop table if exists public.fits cascade;
drop table if exists public.materials cascade;
drop table if exists public.necklines cascade;
drop table if exists public.occasions cascade;
drop table if exists public.patterns cascade;
drop table if exists public.seasons cascade;
drop table if exists public.sleeve_lengths cascade;
drop table if exists public.tags cascade;
