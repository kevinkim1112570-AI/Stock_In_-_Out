# Stock In/Out List

A shared stock register for the team. Sign in, then record every stock-in with serial no., category, category code, brand, type/expression, purchaser, date of receipt, receiver, quantity, storage code, giftable, detail and latest status. Search, filter and sort the table, and edit or delete rows. Changes appear on everyone's screen as they happen.

Data lives in a Supabase table (`stock_in`). Only signed-in people can read or change it.

## Lists

The page has three tabs, each with its own table in Supabase, so records never mix:

| Tab | Table |
| --- | --- |
| Stock IN List | `stock_in` |
| Unnumbered Stock In List | `stock_in_unnumbered` |
| Stock OUT List | `stock_out` |

All three share one layout and numbering rules, except that the Stock OUT List shows Date of Release (was Date of Receipt) and In-charge (was Receiver, chosen from the Staff List), has no Purchaser, Storage Code, Giftable or Latest Status (its status filter uses Status of Release), and adds Inventory ID (free text), Status of Release (same choices as Latest Status) and Recipient (free text, not tied to the Staff List). The Unnumbered Stock In List has no Category Code, Storage Code or Giftable column (also left out of its form, filter and Excel export), and that Stock OUT Category Codes have a lowercase r (release) after the letters: TLr1, TLr2, LWr1. Each counts its own Serial No. and Category Codes from 1. The address ends in `#unnumbered` or `#out` for the second and third tab, so a tab can be bookmarked. Export downloads the list that is open.

## Numbering and categories

- **Category** is a dropdown filled from the Category List on the Dashboard (up to 8). It starts with 酒类 (LW), 茶类 (TL), 礼品饰品类 (GP), 橙皮类 (OP) and 茶具类 (TW).
- **Category Code** cannot be typed. It fills in after you pick a category: the prefix plus the next number in that category, for example TL1, TL2, TL3.
- **Serial No.** is a plain number starting at 1 (the highest existing number plus 1).
- Both numbers are assigned by the database when you save, so two people adding stock at the same moment never get the same number. Deleting the newest row frees its number for the next one.

## Dashboard

The **Dashboard** link (top right of every list) opens a page with two lists. Both are shared live and saved with their own **Save** button.

- **Category List**: up to 8 rows of category name, 2 to 4 letter code, color and description. The color is picked from a Word-style palette and fills the Category Code cell in every list. Changing a code renames the codes of all existing records in that category (GP1 becomes GD1, GPr1 becomes GDr1); colors update everywhere at once. The code is the prefix of the Category Code (TL becomes TL1, TL2...). The category dropdown and the category filter use this list.
- **Staff List**: up to 12 names. The **Purchaser** and **Receiver** dropdowns use this list.

Renaming a category or a person does not change the name saved in existing records (changing a code does update their Category Codes); an old record keeps its old value and still shows it when edited. Table names: `app_categories` and `app_staff`.

## Accounts, Read Only and Admin

- New accounts start as **Read Only**: when they sign in they get a notice saying so. They can see every list but cannot add, edit or delete anything (the buttons are hidden, and the database refuses changes too).
- The **Admin** link on the sign-in page opens the Admin page after the admin password is entered. It lists every account with **Read Only** / **Edit Access** ticks. **Edit** sets a new password and switches the account between Read Only and Edit Access. **Delete** removes the account, which cannot sign in again and loses access straight away.
- Passwords are stored scrambled by Supabase, so the Admin page cannot show them (it shows dots). Edit sets a new one.
- The admin password is stored only as the `ADMIN_PASSWORD` secret of the `admin-users` edge function (Supabase dashboard, Edge Functions, Secrets). Five wrong tries lock the Admin page for 15 minutes. Never put the password in `index.html`.

## Printing

Print (or Save as PDF) from any of the three lists: the page is set to A4 landscape, every column is printed except Edit/Delete, the search bar, tabs and buttons are left out, and the column titles repeat at the top of every page.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole app (HTML, CSS and JavaScript in one file) |
| `supabase/schema.sql` | The tables, security rules and realtime setup, for rebuilding the database |
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

## Create Account and Forgot Password

- **Create Account** opens a card with Email, Password and Confirm password. Press and hold the eye button to see what you typed. The account must be confirmed from the email Supabase sends; new accounts are always Read Only until the Admin ticks Edit Access.
- **Forgot Password** (left of Create Account) asks for the account email, emails a 6-character OTP (letters and numbers, works once, 10 minutes), then shows a card with the email locked, the OTP, and the new password twice. It runs through the Edge Function `password-reset` and needs the secrets `RESEND_API_KEY` and `RESEND_FROM`.
- Read Only accounts see a small red "(Read Only)" after the list title.
