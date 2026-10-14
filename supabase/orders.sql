-- Run after supabase/schema.sql in the Supabase SQL Editor.
-- Adds order requests, seller order management, and optional seller UPI payouts.
-- Direct UPI intents send money to the seller but cannot verify payment to this site.

alter table public.profiles add column if not exists payment_upi_id text not null default '';

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id, display_name, phone, role, payment_preference, payment_upi_id)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'name',''), split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'phone',''),
    case when new.raw_user_meta_data->>'role' = 'seller' then 'seller' else 'shopper' end,
    case when new.raw_user_meta_data->>'paymentPreference' in ('upi','gpay','phonepe','none')
      then new.raw_user_meta_data->>'paymentPreference' else 'upi' end,
    coalesce(new.raw_user_meta_data->>'paymentUpiId','')
  );
  return new;
end;
$$;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_group_id uuid not null,
  buyer_id uuid not null references auth.users(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_title text not null,
  product_image text not null,
  seller_name text not null,
  seller_email text not null default '',
  seller_phone text not null default '',
  seller_upi_id text not null default '',
  buyer_name text not null,
  buyer_email text not null,
  buyer_phone text not null,
  delivery_address text not null,
  buyer_note text not null default '',
  quantity integer not null check (quantity between 1 and 20),
  unit_price numeric(12,2) not null check (unit_price >= 1),
  status text not null default 'requested',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.orders drop constraint if exists orders_status_check;
alter table public.orders add constraint orders_status_check check (status in ('requested','accepted','rejected','paid','shipped','completed'));
alter table public.orders add column if not exists seller_email text not null default '';
alter table public.orders add column if not exists seller_phone text not null default '';
alter table public.orders add column if not exists seller_upi_id text not null default '';
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
  v_seller_email text;
  v_seller_phone text;
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
    select email into v_seller_email from auth.users where id = v_item.seller_id;
    select phone into v_seller_phone from public.profiles where id = v_item.seller_id;
    insert into public.orders(
      order_group_id, buyer_id, seller_id, product_id, product_title,
      product_image, seller_name, seller_email, seller_phone, buyer_name,
      buyer_email, buyer_phone, delivery_address, buyer_note, quantity, unit_price
    ) values (
      v_group, v_buyer, v_item.seller_id, v_item.product_id, v_item.title,
      v_item.image, v_item.seller_name, coalesce(v_seller_email, ''), coalesce(v_seller_phone, ''),
      trim(p_buyer_name), v_email, trim(p_buyer_phone), trim(p_delivery_address),
      coalesce(trim(p_buyer_note), ''), v_item.quantity, v_item.price
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
    or (v_order.status = 'accepted' and p_status in ('paid','rejected'))
    or (v_order.status = 'paid' and p_status = 'shipped')
    or (v_order.status = 'shipped' and p_status = 'completed')
  ) then
    raise exception 'That order status change is not allowed.';
  end if;

  update public.orders
    set status = p_status, updated_at = now(),
        seller_upi_id = case when p_status = 'accepted'
          then coalesce((select payment_upi_id from public.profiles where id = v_order.seller_id), '')
          else seller_upi_id end
    where id = p_order_id
    returning * into v_order;
  return v_order;
end;
$$;

revoke all on function public.place_cart_order(text, text, text, text) from public;
revoke all on function public.update_order_status(uuid, text) from public;
grant execute on function public.place_cart_order(text, text, text, text) to authenticated;
grant execute on function public.update_order_status(uuid, text) to authenticated;
