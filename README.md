# Stock In/Out List

A shared stock register for the team. Sign in, then record every stock-in with serial no., category, category code, brand, type/expression, purchaser, date of receipt, receiver, quantity, storage code, giftable, detail and latest status. Search, filter and sort the table, and edit or delete rows. Changes appear on everyone's screen as they happen.

Data lives in a Supabase table (`stock_in`). Only signed-in people can read or change it.

## Numbering and categories

- **Category** is a dropdown with five choices: 酒类 (LW), 茶类 (TL), 礼品饰品类 (GP), 橙皮类 (OP) and 茶具类 (TW).
- **Category Code** cannot be typed. It fills in after you pick a category: the prefix plus the next number in that category, for example TL1, TL2, TL3.
- **Serial No.** is a plain number starting at 1 (the highest existing number plus 1).
- Both numbers are assigned by the database when you save, so two people adding stock at the same moment never get the same number. Deleting the newest row frees its number for the next one.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app (HTML, CSS and JavaScript in one file) |
| `supabase/schema.sql` | The table, security rules and realtime setup, for rebuilding the database |
| `vercel.json` | Vercel settings: static site, no build step, basic security headers |
| `.gitignore` | Keeps local and Vercel folders out of Git |

## Accounts

The login screen has **Sign in** and **Create account** buttons. A new account needs an email and a password of 6 or more characters.

Supabase settings that control sign-up (Authentication in the Supabase dashboard):

- **Sign In / Providers → Email → Confirm email**: when on, new people must click a link in their confirmation email before they can sign in. When off, they are signed in straight away.
- **URL Configuration → Site URL**: set this to your Vercel address so the confirmation link opens the app.
- **Sign In / Providers → Allow new users to sign up**: turn this off to stop self sign-up. Then add people yourself under **Authentication → Users → Add user**.

Anyone who can create an account can read, add, edit and delete every record. If the site address is shared outside the team, turn off sign-up or restrict it to team emails.

## Deploy to Vercel

1. Sign in at [vercel.com](https://vercel.com) with GitHub.
2. Choose **Add New… → Project** and import this repository.
3. Leave the framework preset as **Other**, with no build command and no output directory override.
4. Click **Deploy**.

Every push to `main` redeploys the site.

## About the key in `index.html`

The Supabase URL and publishable key are in `index.html` on purpose. The publishable key is designed to be public. The security comes from row level security in `supabase/schema.sql`, which blocks anyone who is not signed in. Never put a secret or service role key in this repo.
