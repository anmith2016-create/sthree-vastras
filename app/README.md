# Sthree Vastras

A responsive clothing marketplace with real registration and sign-in, a shared seller catalogue, image uploads, a per-account cart, and editable account preferences. The catalogue starts empty; it is populated only by seller-created listings.

## Run it

1. Install Node.js 18 or newer.
2. Open a terminal in this folder and run `node server.js`.
3. Visit [http://localhost:4173](http://localhost:4173).

The app uses only Node's built-in modules. It creates `data.json` beside the server on first use. That file stores account records (passwords are salted and hashed), product listings, seller-uploaded photos, and carts. Keep it backed up and private. The included `.gitignore` excludes this database. For hosting, set `DATA_FILE` to a persistent path outside the app's public directory (for example `/var/lib/sthree-vastras/data.json`). All people using the same deployed server see the same published listings. Set `NODE_ENV=production` behind HTTPS; this enables secure session cookies. The sample server is intended as a starter, not a hardened production service.

## Before accepting orders

The app does not store card numbers, UPI PINs, or wallet passwords. Payment preferences and display currency are not a payment integration; prices are set in INR, and alternate currency choices change the symbol only. Checkout is an honest handoff notice because no payment, order, shipping, refund, or email-verification provider has been connected. Connect a payment provider and secure hosting before taking real customer payments. Product review scores are omitted until real verified reviews exist. A deployment starts with an empty database; do not upload your local `data.json`, which contains private account and listing data.

## Publish on your own server

For a Linux VPS, copy `server.js` and `index.html` to a private app directory, install Node.js 18+, and start it with `NODE_ENV=production DATA_FILE=/var/lib/sthree-vastras/data.json PORT=4173 node server.js`. Run it as a dedicated, unprivileged service account. Put Nginx, Caddy, or your host's HTTPS proxy in front of port 4173 and point your domain to that proxy. Ensure the data directory is writable by the service account, persistent across restarts, and never served as static files. Keep the firewall closed to direct public access on port 4173. Use your server's process manager so the app restarts after a reboot. For shared hosting, confirm it supports a continuously running Node.js process and writable persistent storage.

## App features

- Responsive shopping experience for phones and desktop screens.
- Shopper and seller accounts with password hashing and server-side sessions.
- Seller listings with a real uploaded product photo, price, category, description, and shared storefront visibility.
- Product detail view, search, categories, seller attribution, and cart with saved quantities and INR totals.
- Account settings for email (confirmed by current password), phone, language, display currency, and sign-out.
- Tapun AI guide that searches the real catalogue without inventing available products.

