-- Schema for the Stock In/Out List (already applied to the Supabase project).
-- Kept here so the database can be rebuilt. Run in the Supabase SQL editor.

create table public.stock_in (
  id uuid primary key default gen_random_uuid(),
  serial_no text not null check (length(btrim(serial_no)) > 0),
  category text not null check (length(btrim(category)) > 0),
  category_code text not null default '',
  brand_name text not null check (length(btrim(brand_name)) > 0),
  type_expression text not null default '',
  purchaser text not null check (length(btrim(purchaser)) > 0),
  date_of_receipt date not null,
  receiver text not null check (length(btrim(receiver)) > 0),
  quantity integer not null check (quantity >= 1),
  storage_code text not null check (length(btrim(storage_code)) > 0),
  giftable boolean not null default false,
  detail text not null default '',
  latest_status text not null default 'In stock'
    check (latest_status in ('In stock', 'Reserved', 'Given out', 'Used', 'Damaged')),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index stock_in_serial_no_key on public.stock_in (lower(serial_no));
create index stock_in_date_of_receipt_idx on public.stock_in (date_of_receipt desc);
create index stock_in_created_by_idx on public.stock_in (created_by);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger stock_in_set_updated_at
before update on public.stock_in
for each row execute function public.set_updated_at();

-- Only signed-in users can read or change stock. Anonymous visitors get nothing.
alter table public.stock_in enable row level security;
revoke all on public.stock_in from anon;

create policy "Signed-in team can view stock"
  on public.stock_in for select to authenticated
  using ((select auth.uid()) is not null);

create policy "Signed-in team can add stock"
  on public.stock_in for insert to authenticated
  with check ((select auth.uid()) is not null);

create policy "Signed-in team can edit stock"
  on public.stock_in for update to authenticated
  using ((select auth.uid()) is not null)
  with check ((select auth.uid()) is not null);

create policy "Signed-in team can delete stock"
  on public.stock_in for delete to authenticated
  using ((select auth.uid()) is not null);

-- Live updates for everyone viewing the list.
alter publication supabase_realtime add table public.stock_in;
