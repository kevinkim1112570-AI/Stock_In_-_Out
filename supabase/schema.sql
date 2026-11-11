-- Schema for the Stock In/Out List (already applied to the Supabase project).
-- Kept here so the database can be rebuilt. Run in the Supabase SQL editor.

create table public.stock_in (
  id uuid primary key default gen_random_uuid(),
  -- Serial No. and Category Code are assigned by the trigger below.
  serial_no integer not null check (serial_no >= 1),
  category text not null
    check (category in ('酒类', '茶类', '礼品饰品类', '橙皮类', '茶具类')),
  category_code text not null check (category_code ~ '^(LW|TL|GP|OP|TW)[0-9]+$'),
  brand_name text not null check (length(btrim(brand_name)) > 0),
  type_expression text not null default '',
  purchaser text not null check (length(btrim(purchaser)) > 0),
  date_of_receipt date not null,
  receiver text not null check (length(btrim(receiver)) > 0),
  quantity integer not null check (quantity >= 1),
  quantity_unit text not null default '',  -- 个, 包, 罐, 套, 片 ...
  storage_code text not null default '',   -- optional
  giftable text not null default 'Unknown' check (giftable in ('Yes', 'No', 'Unknown')),
  detail text not null default '',
  latest_status text not null default 'In stock'
    check (latest_status in ('In stock', 'Reserved', 'Given out', 'Used', 'Damaged')),
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index stock_in_serial_no_key on public.stock_in (serial_no);
create unique index stock_in_category_code_key on public.stock_in (category_code);
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

-- Serial No. = highest existing number + 1, starting at 1.
-- Category Code = category prefix + (highest number used in that category + 1),
-- for example TL1, TL2, TL3. Changing the category gives a new code.
-- The lock makes sure two people adding stock at once never get the same number.
create function public.assign_stock_in_numbers()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  prefix text;
  next_n integer;
begin
  prefix := case new.category
    when '酒类' then 'LW' when '茶类' then 'TL' when '礼品饰品类' then 'GP'
    when '橙皮类' then 'OP' when '茶具类' then 'TW' end;
  if prefix is null then
    raise exception 'Unknown category: %', new.category;
  end if;

  perform pg_advisory_xact_lock(hashtext('stock_in_numbers'));

  if tg_op = 'INSERT' then
    select coalesce(max(serial_no), 0) + 1 into new.serial_no from public.stock_in;
  else
    new.serial_no := old.serial_no;
  end if;

  if tg_op = 'INSERT' or new.category is distinct from old.category then
    select coalesce(max(substr(category_code, 3)::integer), 0) + 1
      into next_n
      from public.stock_in
      where category_code like prefix || '%';
    new.category_code := prefix || next_n;
  else
    new.category_code := old.category_code;
  end if;

  return new;
end;
$$;

create trigger stock_in_assign_numbers
before insert or update on public.stock_in
for each row execute function public.assign_stock_in_numbers();

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

-- ---------------------------------------------------------------------------
-- Two more lists with exactly the same columns, numbering and security rules:
--   public.stock_in_unnumbered  (Unnumbered Stock In List)
--   public.stock_out            (Stock OUT List)
-- Each table counts its own Serial No. and Category Codes from 1.
-- ---------------------------------------------------------------------------
do $mig$
declare
  t text;
begin
  foreach t in array array['stock_in_unnumbered', 'stock_out'] loop
    execute format($f$
      create table public.%1$I (
        id uuid primary key default gen_random_uuid(),
        serial_no integer not null check (serial_no >= 1),
        category text not null
          check (category in ('酒类', '茶类', '礼品饰品类', '橙皮类', '茶具类')),
        category_code text not null check (category_code ~ '^(LW|TL|GP|OP|TW)[0-9]+$'),
        brand_name text not null check (length(btrim(brand_name)) > 0),
        type_expression text not null default '',
        purchaser text not null check (length(btrim(purchaser)) > 0),
        date_of_receipt date not null,
        receiver text not null check (length(btrim(receiver)) > 0),
        quantity integer not null check (quantity >= 1),
        quantity_unit text not null default '',
        storage_code text not null default '',
        giftable text not null default 'Unknown' check (giftable in ('Yes', 'No', 'Unknown')),
        detail text not null default '',
        latest_status text not null default 'In stock'
          check (latest_status in ('In stock', 'Reserved', 'Given out', 'Used', 'Damaged')),
        created_by uuid default auth.uid() references auth.users (id) on delete set null,
        created_at timestamptz not null default now(),
        updated_at timestamptz not null default now()
      )$f$, t);

    execute format('create unique index %I on public.%I (serial_no)', t || '_serial_no_key', t);
    execute format('create unique index %I on public.%I (category_code)', t || '_category_code_key', t);
    execute format('create index %I on public.%I (date_of_receipt desc)', t || '_date_of_receipt_idx', t);
    execute format('create index %I on public.%I (created_by)', t || '_created_by_idx', t);

    execute format($f$
      create function public.%1$I()
      returns trigger
      language plpgsql
      set search_path = ''
      as $body$
      declare
        prefix text;
        next_n integer;
      begin
        prefix := case new.category
          when '酒类' then 'LW' when '茶类' then 'TL' when '礼品饰品类' then 'GP'
          when '橙皮类' then 'OP' when '茶具类' then 'TW' end;
        if prefix is null then
          raise exception 'Unknown category: %%', new.category;
        end if;

        perform pg_advisory_xact_lock(hashtext(%2$L));

        if tg_op = 'INSERT' then
          select coalesce(max(serial_no), 0) + 1 into new.serial_no from public.%2$I;
        else
          new.serial_no := old.serial_no;
        end if;

        if tg_op = 'INSERT' or new.category is distinct from old.category then
          select coalesce(max(substr(category_code, 3)::integer), 0) + 1
            into next_n
            from public.%2$I
            where category_code like prefix || '%%';
          new.category_code := prefix || next_n;
        else
          new.category_code := old.category_code;
        end if;

        return new;
      end;
      $body$$f$, 'assign_' || t || '_numbers', t);

    execute format('create trigger %I before insert or update on public.%I for each row execute function public.%I()',
      t || '_assign_numbers', t, 'assign_' || t || '_numbers');
    execute format('create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      t || '_set_updated_at', t);

    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('create policy %I on public.%I for select to authenticated using ((select auth.uid()) is not null)', 'Signed-in team can view stock', t);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) is not null)', 'Signed-in team can add stock', t);
    execute format('create policy %I on public.%I for update to authenticated using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null)', 'Signed-in team can edit stock', t);
    execute format('create policy %I on public.%I for delete to authenticated using ((select auth.uid()) is not null)', 'Signed-in team can delete stock', t);
    execute format('alter publication supabase_realtime add table public.%I', t);
  end loop;
end
$mig$;

-- ---------------------------------------------------------------------------
-- Dashboard: the editable Category List (8 slots) and Staff List (12 slots).
-- The Category List replaces the fixed five categories. The number prefix of a
-- new record comes from here. The assign_*_numbers functions above are replaced
-- so the prefix is read from app_categories (category must be on the list), and
-- the old category check and code-format check on the three stock tables are
-- replaced by a plain "2 to 4 capital letters then digits" check.
-- (Applied to the live project as migrations; the functions use:
--    select code into prefix from public.app_categories where name = new.category;
--    ... where category_code ~ ('^' || prefix || '[0-9]+$') )
-- ---------------------------------------------------------------------------
create table public.app_categories (
  slot integer primary key check (slot between 1 and 8),
  name text,
  code text,
  description text not null default '',
  updated_at timestamptz not null default now(),
  constraint app_categories_filled check (
    (name is null and code is null)
    or (coalesce(length(btrim(name)), 0) > 0 and coalesce(code ~ '^[A-Z]{2,4}$', false))),
  constraint app_categories_name_key unique (name) deferrable initially deferred,
  constraint app_categories_code_key unique (code) deferrable initially deferred
);

create table public.app_staff (
  slot integer primary key check (slot between 1 and 12),
  name text check (name is null or length(btrim(name)) > 0),
  updated_at timestamptz not null default now(),
  constraint app_staff_name_key unique (name) deferrable initially deferred
);

alter table public.app_categories enable row level security;
alter table public.app_staff enable row level security;
revoke all on public.app_categories, public.app_staff from anon;

create policy "Signed-in team can view categories" on public.app_categories for select to authenticated using ((select auth.uid()) is not null);
create policy "Signed-in team can add categories" on public.app_categories for insert to authenticated with check ((select auth.uid()) is not null);
create policy "Signed-in team can edit categories" on public.app_categories for update to authenticated using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy "Signed-in team can view staff" on public.app_staff for select to authenticated using ((select auth.uid()) is not null);
create policy "Signed-in team can add staff" on public.app_staff for insert to authenticated with check ((select auth.uid()) is not null);
create policy "Signed-in team can edit staff" on public.app_staff for update to authenticated using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);

alter publication supabase_realtime add table public.app_categories, public.app_staff;

-- Starting data: the five original categories and the names from the staff sheet.
insert into public.app_categories (slot, name, code, description) values
  (1, '酒类', 'LW', 'Liquid & Wine'), (2, '茶类', 'TL', 'Tea Leaf'),
  (3, '礼品饰品类', 'GP', 'Gift & Present'), (4, '橙皮类', 'OP', 'Orange Peel'),
  (5, '茶具类', 'TW', 'Tea Ware'), (6, null, null, ''), (7, null, null, ''), (8, null, null, '');
insert into public.app_staff (slot, name) values
  (1, '老板'), (2, '美龄'), (3, 'Philip'), (4, 'LK'), (5, 'YK'), (6, 'Yazi'), (7, 'Kevin'), (8, 'William'),
  (9, null), (10, null), (11, null), (12, null);

-- Stock OUT List: Category Codes carry a lowercase r (release) after the letters,
-- e.g. TLr1, LWr2. Applied as migration stock_out_release_code_r.
--   alter table public.stock_out drop constraint stock_out_category_code_format;
--   alter table public.stock_out add constraint stock_out_category_code_format
--     check (category_code ~ '^[A-Z]{2,4}r[0-9]+$');
-- and assign_stock_out_numbers() builds the code as prefix || 'r' || next_n, counting
-- only codes that match '^' || prefix || 'r[0-9]+$'. Existing rows were renamed TL1 -> TLr1.

-- Stock OUT List: Date of Receipt is shown as Date of Release (same column) and
-- Receiver as In-charge (same column). Purchaser, Storage Code and Giftable are no
-- longer used there. Three new free-text columns. Applied as migration stock_out_release_columns.
alter table public.stock_out
  add column inventory_id text not null default '',
  add column release_status text not null default '',
  add column recipient text not null default '';
alter table public.stock_out drop constraint stock_out_purchaser_check;
alter table public.stock_out alter column purchaser set default '';

-- Category colors and live code renaming (migration category_colors_and_code_sync).
-- app_categories.color: hex such as #83C937, shown behind the Category Code in every list.
alter table public.app_categories
  add column color text check (color is null or color ~ '^#[0-9A-Fa-f]{6}$');
-- The three assign_*_numbers functions start with
--   if current_setting('app.renumber', true) = '1' then return new; end if;
-- so sync_category_codes() can rewrite codes. When a category is added or its code
-- changes, every record of that category in all three lists gets the new letters
-- (GP1 -> GD1, and on Stock OUT GPr1 -> GDr1).
-- See the migration for the full sync_category_codes() function and trigger
-- app_categories_sync_codes (after insert or update of name, code).

-- ---------------------------------------------------------------------------
-- Accounts: Read Only / Edit Access, and the Admin page (migration
-- account_roles_read_only_edit_access).
--   app_user_roles(user_id, can_edit)  one row per account; new accounts start Read Only
--   is_member()  true if the signed-in user still has an account row (deleted users lose access at once)
--   can_edit()   true if that row has can_edit = true
--   Policies on stock_in, stock_in_unnumbered, stock_out, app_categories and app_staff:
--     select -> is_member(); insert/update/delete -> can_edit()
--   admin_login_attempts: counts wrong Admin passwords (5 wrong = locked 15 minutes);
--     only the edge function can touch it.
-- The Admin page talks to the edge function supabase/functions/admin-users, which checks
-- the ADMIN_PASSWORD secret and uses the service role key to list, update and delete accounts.
-- The Admin password is NOT in this repo or in index.html.
-- ---------------------------------------------------------------------------

-- Migration: allow_blank_date_and_purchaser
-- Imported legacy rows may have no Date of Receipt / Purchaser, so those
-- columns are nullable / may be empty. (Applied via Supabase migration.)

-- Migration: drop_password_reset (the Forgot Password feature was removed; table password_reset_otps and function pr_find_user dropped)
