# Sthree Vastras

A responsive clothing marketplace for shoppers and independent sellers. The catalog starts empty and displays only real seller listings.

## Free shared marketplace setup

GitHub Pages is static hosting, so listings need a shared database. This app connects directly to a free Supabase project; no paid server is used.

1. Create a free project at [supabase.com](https://supabase.com). The free plan has usage caps and may pause a project after a week with very little activity.
2. In the Supabase dashboard, open **SQL Editor** and run [`supabase/schema.sql`](supabase/schema.sql) once. It creates the profiles, product listings, shared cart, photo bucket, and row-level access rules. Then run [`supabase/orders.sql`](supabase/orders.sql) to enable order requests. If the existing app is already connected, only the orders file needs to be run.
3. Open **Project Settings → API**. Copy the **Project URL** and the **publishable/anon key** into [`app/supabase-config.js`](app/supabase-config.js). These browser values are public; never use a service-role or secret key.
4. In **Authentication → URL Configuration**, add `https://anmith2016-create.github.io` as the site URL and `https://anmith2016-create.github.io/**` as an allowed redirect URL. In **Authentication → Providers → Email**, turn off **Confirm email** so people can create accounts and sign in without verifying an email address. The app checks Supabase’s public Auth settings before signup and blocks signup unless **Confirm email** is off, so it will not trigger a confirmation message. To honor the no-confirmation requirement, sign-in email changes and email-based password resets are unavailable in this browser-only app.
5. Commit the updated config file to GitHub. The Pages workflow redeploys the app.

Once set up, shoppers and sellers use the GitHub Pages link and see the same listings. Seller photos are stored in Supabase Storage. Do not commit passwords, service-role keys, customer data, or local database files.

## App details

- Sign-up/sign-in uses Supabase Auth with email confirmation disabled; profiles and carts are private to each account. If Confirm email remains enabled in Supabase, sign-up cannot complete and the app explains the required setting.
- Sellers upload real product photos, descriptions, categories, and INR prices.
- Listings are public and shared; the catalog starts empty, with no sample products or invented reviews.
- The sign-in email is fixed. Email-based password reset is disabled so the app never asks users to verify an email address.
- Display currency changes the symbol only; it does not convert prices.
- Shoppers can submit order requests from their bag; sellers can accept, decline, and update orders. Each order is visible only to its buyer and seller.
- Sellers can optionally add a UPI ID. After accepting an order, buyers can open their UPI app with the seller and INR amount prefilled; the transfer goes directly to the seller.
- The site cannot verify a UPI transfer. Sellers must confirm receipt before shipping. It never stores bank account numbers, UPI PINs, or OTPs.
- Supabase Free currently includes capped database, file storage, and bandwidth. Projects can pause after a week of low activity and can be resumed from the dashboard. See [Supabase Free plan details](https://supabase.com/pricing) and [project pausing](https://supabase.com/docs/guides/platform/free-project-pausing).

## Local preview

The legacy Node server is available for offline development with `node app/server.js`; it stores data locally and is not used by GitHub Pages. Do not treat local listings as shared.