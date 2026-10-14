# Sthree Vastras app

The GitHub Pages app at [`/app/`](https://anmith2016-create.github.io/sthree-vastras/app/) uses a free Supabase project for shared accounts, listings, seller photos, and carts. It does not need a paid Node host.

## Connect the free database

1. Create a free Supabase project.
2. In **SQL Editor**, run [`../supabase/schema.sql`](../supabase/schema.sql).
3. In **Project Settings → API**, copy the Project URL and publishable/anon key into `supabase-config.js`.
4. In **Authentication → URL Configuration**, set the site URL to `https://anmith2016-create.github.io` and add `https://anmith2016-create.github.io/**` to allowed redirect URLs.
5. Commit `supabase-config.js` to GitHub. The Pages action will redeploy.

Only the publishable/anon key belongs in this browser config, never a service-role or secret key. The database uses row-level security so seller listings are public while profiles and carts stay private.

Supabase Free is $0 and has storage/database/bandwidth limits. Free projects may pause after 7 days of low activity; resume them from the Supabase dashboard if that happens. Current limits are listed at [Supabase Pricing](https://supabase.com/pricing).

## Honest limits

- The product catalog starts empty and includes no sample products or invented reviews.
- Prices are entered in INR. Other currency choices change the display symbol only; they do not convert the amount.
- Payment preference is informational. Checkout does not process orders or connect to Google Pay or PhonePe.
- The old `server.js` is only a local preview and is not the shared production backend.