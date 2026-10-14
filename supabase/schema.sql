-- Run this once in Supabase Dashboard → SQL Editor.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Maker',
  phone text not null default '',
  role text not null default 'shopper' check (role in ('shopper','seller')),
  payment_preference text not null default 'upi' check (payment_preference in ('upi','gpay','phonepe','none')),
  language text not null default 'en' check (language in ('en','hi')),
  currency text not null default 'INR' check (currency in ('INR','USD','EUR','GBP')),
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
create policy "Read your own profile" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "Update your own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles(id, display_name, phone, role, payment_preference)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'name',''), split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'phone',''),
    case when new.raw_user_meta_data->>'role' = 'seller' then 'seller' else 'shopper' end,
    case when new.raw_user_meta_data->>'paymentPreference' in ('upi','gpay','phonepe','none')
      then new.raw_user_meta_data->>'paymentPreference' else 'upi' end
  );
  return new;
end;
$$;
drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile after insert on auth.users
for each row execute procedure public.create_profile_for_new_user();

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  seller_name text not null,
  title text not null check (char_length(title) between 1 and 100),
  category text not null,
  description text not null check (char_length(description) between 1 and 1200),
  price numeric(12,2) not null check (price >= 1 and price <= 10000000),
  image text not null,
  created_at timestamptz not null default now()
);
alter table public.products enable row level security;
create policy "Anyone can see real published pieces" on public.products for select using (true);
create policy "Sellers publish their own pieces" on public.products for insert to authenticated
with check (
  seller_id = (select auth.uid()) and exists (
    select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'seller'
  )
);
create policy "Sellers edit their own pieces" on public.products for update to authenticated
using (seller_id = (select auth.uid())) with check (seller_id = (select auth.uid()));
create policy "Sellers remove their own pieces" on public.products for delete to authenticated
using (seller_id = (select auth.uid()));

create or replace function public.set_product_seller()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  if tg_op = 'INSERT' then new.seller_id := auth.uid(); end if;
  select display_name into new.seller_name from public.profiles where id = auth.uid();
  return new;
end;
$$;
drop trigger if exists set_product_seller_before_write on public.products;
create trigger set_product_seller_before_write before insert or update on public.products
for each row execute procedure public.set_product_seller();

create table if not exists public.cart_items (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity integer not null default 1 check (quantity between 1 and 20),
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);
alter table public.cart_items enable row level security;
create policy "Read your own bag" on public.cart_items for select to authenticated using (user_id = (select auth.uid()));
create policy "Add to your own bag" on public.cart_items for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Update your own bag" on public.cart_items for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Remove from your own bag" on public.cart_items for delete to authenticated using (user_id = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('clothing', 'clothing', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
allowed_mime_types = array['image/jpeg','image/png','image/webp'];
create policy "View clothing photos" on storage.objects for select using (bucket_id = 'clothing');
create policy "Sellers upload clothing photos" on storage.objects for insert to authenticated
with check (
  bucket_id = 'clothing'
  and (storage.foldername(name))[1] = (select auth.uid())::text
  and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'seller')
);
create policy "Sellers update their clothing photos" on storage.objects for update to authenticated
using (bucket_id = 'clothing' and owner_id = (select auth.uid())::text)
with check (bucket_id = 'clothing' and owner_id = (select auth.uid())::text);
create policy "Sellers delete their clothing photos" on storage.objects for delete to authenticated
using (bucket_id = 'clothing' and owner_id = (select auth.uid())::text);
