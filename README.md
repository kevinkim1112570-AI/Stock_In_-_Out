# Stock In/Out List

A shared stock register for the team. Sign in, then record every stock-in with serial no., category, category code, brand, type/expression, purchaser, date of receipt, receiver, quantity, storage code, giftable, detail and latest status. Search, filter and sort the table, and edit or delete rows. Changes appear on everyone's screen as they happen.

Data lives in a Supabase table (`stock_in`). Only signed-in team members can read or change it.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app (HTML, CSS and JavaScript in one file) |
| `supabase/schema.sql` | The table, security rules and realtime setup, for rebuilding the database |
| `vercel.json` | Vercel settings: static site, no build step, basic security headers |
| `.gitignore` | Keeps local and Vercel folders out of Git |

## Add teammates

There is no sign-up screen. Add each person in Supabase:

1. Open the project in the Supabase dashboard.
2. Go to **Authentication → Users → Add user → Create new user**.
3. Enter their email and a password, and tick **Auto Confirm User**.
4. Send them the site link and their password.

To stop strangers creating their own accounts, go to **Authentication → Sign In / Providers** and turn off **Allow new users to sign up**.

## Deploy to Vercel

1. Sign in at [vercel.com](https://vercel.com) with GitHub.
2. Choose **Add New… → Project** and import this repository.
3. Leave the framework preset as **Other**, with no build command and no output directory override.
4. Click **Deploy**.

Every push to `main` redeploys the site.

## About the key in `index.html`

The Supabase URL and publishable key are in `index.html` on purpose. The publishable key is designed to be public. The security comes from row level security in `supabase/schema.sql`, which blocks anyone who is not signed in. Never put a secret or service role key in this repo.
