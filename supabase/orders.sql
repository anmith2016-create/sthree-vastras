-- Run after supabase/schema.sql in the Supabase SQL Editor.
-- Adds order requests and seller order management. Payments stay off-platform.

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_group_id uuid not null,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_title text not null,
  product_image text not null,
  seller_name text not null,
  buyer_name text not null,
  buyer_email text not null,
  buyer_phone text not null,
  delivery_address text not null,
  buyer_note text not null default '',
  quantity integer not null check (quantity between 1 and 20),
  unit_price numeric(12,2) not null check (unit_price >= 1),
  status text not null default 'requested'
    check (status in ('requested','accepted','rejected','shipped','completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.orders enable row level security;
drop policy if exists "Buyers and sellers can read their own orders" on public.orders;
create policy "Buyers and sellers can read their own orders"
  on public.orders for select to authenticated
  using (buyer_id = (select auth.uid()) or seller_id = (select auth.uid()));

revoke all on public.orders from anon, authenticated;
grant select on public.orders to authenticated;

create or replace function public.place_cart_order(
  p_buyer_name text,
  p_buyer_phone text,
  p_delivery_address text,
  p_buyer_note text
) returns setof public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_buyer uuid := auth.uid();
  v_email text;
  v_group uuid := gen_random_uuid();
  v_item record;
  v_order public.orders%rowtype;
begin
  if v_buyer is null then
    raise exception 'Please sign in before placing an order.';
  end if;
  if length(trim(coalesce(p_buyer_name, ''))) not between 1 and 100 then
    raise exception 'Enter a recipient name.';
  end if;
  if length(trim(coalesce(p_buyer_phone, ''))) not between 7 and 32 then
    raise exception 'Enter a valid phone number.';
  end if;
  if length(trim(coalesce(p_delivery_address, ''))) not between 8 and 500 then
    raise exception 'Enter a delivery address between 8 and 500 characters.';
  end if;
  if length(coalesce(p_buyer_note, '')) > 500 then
    raise exception 'The note must be 500 characters or fewer.';
  end if;

  select email into v_email from auth.users where id = v_buyer;
  if v_email is null then
    raise exception 'Your account email could not be found.';
  end if;
  if not exists (select 1 from public.cart_items where user_id = v_buyer) then
    raise exception 'Your bag is empty.';
  end if;

  for v_item in
    select ci.quantity, p.id as product_id, p.seller_id, p.title, p.image,
           p.seller_name, p.price
    from public.cart_items ci
    join public.products p on p.id = ci.product_id
    where ci.user_id = v_buyer
    order by p.seller_id, p.id
  loop
    if v_item.seller_id = v_buyer then
      raise exception 'Remove your own listing from the bag before ordering.';
    end if;
    insert into public.orders(
      order_group_id, buyer_id, seller_id, product_id, product_title,
      product_image, seller_name, buyer_name, buyer_email, buyer_phone,
      delivery_address, buyer_note, quantity, unit_price
    ) values (
      v_group, v_buyer, v_item.seller_id, v_item.product_id, v_item.title,
      v_item.image, v_item.seller_name, trim(p_buyer_name), v_email,
      trim(p_buyer_phone), trim(p_delivery_address), coalesce(trim(p_buyer_note), ''),
      v_item.quantity, v_item.price
    ) returning * into v_order;
    return next v_order;
  end loop;

  delete from public.cart_items where user_id = v_buyer;
  return;
end;
$$;

create or replace function public.update_order_status(
  p_order_id uuid,
  p_status text
) returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Please sign in before updating an order.';
  end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_order.seller_id <> auth.uid() then
    raise exception 'This order is not assigned to your seller account.';
  end if;

  if not (
    (v_order.status = 'requested' and p_status in ('accepted','rejected'))
    or (v_order.status = 'accepted' and p_status in ('shipped','rejected'))
    or (v_order.status = 'shipped' and p_status = 'completed')
  ) then
    raise exception 'That order status change is not allowed.';
  end if;

  update public.orders
    set status = p_status, updated_at = now()
    where id = p_order_id
    returning * into v_order;
  return v_order;
end;
$$;

revoke all on function public.place_cart_order(text, text, text, text) from public;
revoke all on function public.update_order_status(uuid, text) from public;
grant execute on function public.place_cart_order(text, text, text, text) to authenticated;
grant execute on function public.update_order_status(uuid, text) to authenticated;
