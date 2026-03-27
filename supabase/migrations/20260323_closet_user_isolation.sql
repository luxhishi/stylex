create extension if not exists "pgcrypto";

create table if not exists public.clothing_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  image_url text not null,
  status text not null default 'draft',
  source text not null,
  ai_processed boolean not null default false,
  is_confirmed boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.clothing_item_images (
  id uuid primary key default gen_random_uuid(),
  clothing_item_id uuid not null references public.clothing_items(id) on delete cascade,
  image_url text not null,
  image_type text not null default 'original',
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.clothing_ai_analyses (
  id uuid primary key default gen_random_uuid(),
  clothing_item_id uuid not null references public.clothing_items(id) on delete cascade,
  provider text not null,
  model text not null,
  raw_response jsonb not null default '{}'::jsonb,
  confidence_score double precision,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.clothing_ai_predictions (
  id uuid primary key default gen_random_uuid(),
  analysis_id uuid not null references public.clothing_ai_analyses(id) on delete cascade,
  field_name text not null,
  predicted_slug text,
  predicted_label text,
  confidence_score double precision,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists clothing_items_user_id_created_at_idx
  on public.clothing_items (user_id, created_at desc);

create index if not exists clothing_item_images_clothing_item_id_idx
  on public.clothing_item_images (clothing_item_id);

create index if not exists clothing_ai_analyses_clothing_item_id_idx
  on public.clothing_ai_analyses (clothing_item_id, created_at desc);

create index if not exists clothing_ai_predictions_analysis_id_idx
  on public.clothing_ai_predictions (analysis_id);

alter table public.clothing_items enable row level security;
alter table public.clothing_item_images enable row level security;
alter table public.clothing_ai_analyses enable row level security;
alter table public.clothing_ai_predictions enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_items'
      and policyname = 'Users can view their own clothing items'
  ) then
    create policy "Users can view their own clothing items"
      on public.clothing_items
      for select
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_items'
      and policyname = 'Users can insert their own clothing items'
  ) then
    create policy "Users can insert their own clothing items"
      on public.clothing_items
      for insert
      to authenticated
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_items'
      and policyname = 'Users can update their own clothing items'
  ) then
    create policy "Users can update their own clothing items"
      on public.clothing_items
      for update
      to authenticated
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_items'
      and policyname = 'Users can delete their own clothing items'
  ) then
    create policy "Users can delete their own clothing items"
      on public.clothing_items
      for delete
      to authenticated
      using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_item_images'
      and policyname = 'Users can view their own clothing item images'
  ) then
    create policy "Users can view their own clothing item images"
      on public.clothing_item_images
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_item_images'
      and policyname = 'Users can insert their own clothing item images'
  ) then
    create policy "Users can insert their own clothing item images"
      on public.clothing_item_images
      for insert
      to authenticated
      with check (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_item_images'
      and policyname = 'Users can update their own clothing item images'
  ) then
    create policy "Users can update their own clothing item images"
      on public.clothing_item_images
      for update
      to authenticated
      using (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_item_images'
      and policyname = 'Users can delete their own clothing item images'
  ) then
    create policy "Users can delete their own clothing item images"
      on public.clothing_item_images
      for delete
      to authenticated
      using (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_ai_analyses'
      and policyname = 'Users can view their own clothing analyses'
  ) then
    create policy "Users can view their own clothing analyses"
      on public.clothing_ai_analyses
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_ai_analyses'
      and policyname = 'Users can insert their own clothing analyses'
  ) then
    create policy "Users can insert their own clothing analyses"
      on public.clothing_ai_analyses
      for insert
      to authenticated
      with check (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_ai_analyses'
      and policyname = 'Users can update their own clothing analyses'
  ) then
    create policy "Users can update their own clothing analyses"
      on public.clothing_ai_analyses
      for update
      to authenticated
      using (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_ai_analyses'
      and policyname = 'Users can delete their own clothing analyses'
  ) then
    create policy "Users can delete their own clothing analyses"
      on public.clothing_ai_analyses
      for delete
      to authenticated
      using (
        exists (
          select 1
          from public.clothing_items items
          where items.id = clothing_item_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_ai_predictions'
      and policyname = 'Users can view their own clothing predictions'
  ) then
    create policy "Users can view their own clothing predictions"
      on public.clothing_ai_predictions
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.clothing_ai_analyses analyses
          join public.clothing_items items on items.id = analyses.clothing_item_id
          where analyses.id = analysis_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_ai_predictions'
      and policyname = 'Users can insert their own clothing predictions'
  ) then
    create policy "Users can insert their own clothing predictions"
      on public.clothing_ai_predictions
      for insert
      to authenticated
      with check (
        exists (
          select 1
          from public.clothing_ai_analyses analyses
          join public.clothing_items items on items.id = analyses.clothing_item_id
          where analyses.id = analysis_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_ai_predictions'
      and policyname = 'Users can update their own clothing predictions'
  ) then
    create policy "Users can update their own clothing predictions"
      on public.clothing_ai_predictions
      for update
      to authenticated
      using (
        exists (
          select 1
          from public.clothing_ai_analyses analyses
          join public.clothing_items items on items.id = analyses.clothing_item_id
          where analyses.id = analysis_id
            and items.user_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1
          from public.clothing_ai_analyses analyses
          join public.clothing_items items on items.id = analyses.clothing_item_id
          where analyses.id = analysis_id
            and items.user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'clothing_ai_predictions'
      and policyname = 'Users can delete their own clothing predictions'
  ) then
    create policy "Users can delete their own clothing predictions"
      on public.clothing_ai_predictions
      for delete
      to authenticated
      using (
        exists (
          select 1
          from public.clothing_ai_analyses analyses
          join public.clothing_items items on items.id = analyses.clothing_item_id
          where analyses.id = analysis_id
            and items.user_id = auth.uid()
        )
      );
  end if;
end
$$;

insert into storage.buckets (id, name, public)
select 'closet-items', 'closet-items', false
where not exists (
  select 1
  from storage.buckets
  where id = 'closet-items'
);

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can upload their own closet images'
  ) then
    create policy "Users can upload their own closet images"
      on storage.objects
      for insert
      to authenticated
      with check (
        bucket_id = 'closet-items'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can read their own closet images'
  ) then
    create policy "Users can read their own closet images"
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id = 'closet-items'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can update their own closet images'
  ) then
    create policy "Users can update their own closet images"
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id = 'closet-items'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
      with check (
        bucket_id = 'closet-items'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can delete their own closet images'
  ) then
    create policy "Users can delete their own closet images"
      on storage.objects
      for delete
      to authenticated
      using (
        bucket_id = 'closet-items'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;
end
$$;
