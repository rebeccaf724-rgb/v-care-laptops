-- Run in Supabase SQL Editor. Create staff accounts in Authentication > Users.
create table if not exists public.inventory (
 id uuid primary key default gen_random_uuid(),
 category text not null check (category in ('Laptop','RAM')),
 brand text not null,
 model text not null,
 specification text not null default '',
 serial_number text not null default '',
 purchase_price numeric(12,2) not null default 0 check (purchase_price >= 0),
 selling_price numeric(12,2) not null default 0 check (selling_price >= 0),
 quantity integer not null default 0 check (quantity >= 0),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.sales (
 id uuid primary key default gen_random_uuid(),
 item_id uuid references public.inventory(id) on delete restrict,
 category text not null,
 item_description text not null,
 quantity integer not null check (quantity > 0),
 unit_purchase_price numeric(12,2) not null,
 unit_sale_price numeric(12,2) not null check (unit_sale_price >= 0),
 customer text not null default '',
 payment_method text not null default 'Cash',
 sale_date date not null default current_date,
 created_by uuid default auth.uid(),
 created_at timestamptz not null default now()
);
create index if not exists inventory_category_idx on public.inventory(category);
create index if not exists sales_date_idx on public.sales(sale_date);
alter table public.inventory enable row level security;
alter table public.sales enable row level security;
-- All authenticated staff share one inventory. Only invite trusted staff.
drop policy if exists inventory_staff_read on public.inventory;
create policy inventory_staff_read on public.inventory for select to authenticated using (true);
drop policy if exists inventory_staff_insert on public.inventory;
create policy inventory_staff_insert on public.inventory for insert to authenticated with check (true);
drop policy if exists inventory_staff_update on public.inventory;
create policy inventory_staff_update on public.inventory for update to authenticated using (true) with check (true);
drop policy if exists inventory_staff_delete on public.inventory;
create policy inventory_staff_delete on public.inventory for delete to authenticated using (true);
drop policy if exists sales_staff_read on public.sales;
create policy sales_staff_read on public.sales for select to authenticated using (true);
-- Atomic sale: validates quantity and records sale in one database transaction.
create or replace function public.record_sale(
 p_item_id uuid, p_quantity integer, p_unit_sale_price numeric,
 p_customer text, p_payment_method text, p_sale_date date
) returns uuid language plpgsql security invoker set search_path = public as $$
declare v_item public.inventory%rowtype; v_sale_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if p_quantity is null or p_quantity <= 0 then raise exception 'Invalid quantity'; end if;
 if p_unit_sale_price is null or p_unit_sale_price < 0 then raise exception 'Invalid sale price'; end if;
 if p_sale_date is null then raise exception 'Sale date required'; end if;
 select * into v_item from public.inventory where id = p_item_id for update;
 if not found then raise exception 'Item not found'; end if;
 if v_item.quantity < p_quantity then raise exception 'Not enough stock: % available', v_item.quantity; end if;
 update public.inventory set quantity = quantity - p_quantity, updated_at = now() where id = p_item_id;
 insert into public.sales(item_id,category,item_description,quantity,unit_purchase_price,unit_sale_price,customer,payment_method,sale_date)
 values (v_item.id,v_item.category,v_item.brand || ' ' || v_item.model || ' ' || v_item.specification,p_quantity,v_item.purchase_price,p_unit_sale_price,coalesce(p_customer,''),coalesce(p_payment_method,'Cash'),p_sale_date)
 returning id into v_sale_id;
 return v_sale_id;
end $$;
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.inventory to authenticated;
grant select, insert on public.sales to authenticated;
grant execute on function public.record_sale(uuid,integer,numeric,text,text,date) to authenticated;
revoke execute on function public.record_sale(uuid,integer,numeric,text,text,date) from public, anon;
