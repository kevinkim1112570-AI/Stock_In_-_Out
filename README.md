# Stock In/Out List

A single-page stock register for the team. Record every stock-in with serial no., category, category code, brand, type/expression, purchaser, date of receipt, receiver, quantity, storage code, giftable, detail and latest status. Search, filter and sort the table, and edit or delete rows.

Data is saved in the browser's local storage, so each person and each browser keeps its own list.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app (HTML, CSS and JavaScript in one file) |
| `vercel.json` | Vercel settings: static site, no build step, basic security headers |
| `.gitignore` | Keeps local and Vercel folders out of Git |

## Deploy to Vercel

1. Sign in at [vercel.com](https://vercel.com) with GitHub.
2. Choose **Add New… → Project** and import this repository.
3. Leave the framework preset as **Other**, with no build command and no output directory override.
4. Click **Deploy**. Vercel serves `index.html` at the project URL.

Every push to `main` redeploys the site.

## Run locally

Open `index.html` in a browser. No install or build is needed.
