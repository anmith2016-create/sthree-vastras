# Sthree Vastras

The runnable marketplace app is in [`app/`](app/). The existing root `index.html` is kept intact.

To run the marketplace, use Node.js 18+ and run `node server.js` from the `app` folder. It needs a persistent Node.js host for accounts, seller listings, and carts; GitHub Pages alone cannot run its server. See [app setup and deployment notes](app/README.md).

Never commit the generated `data.json` database or SSH private keys.