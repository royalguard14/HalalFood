# HALAL Food — ChatGPT Project Handoff

> **Purpose:** Permanent handoff/context document for AI assistants working on this repository. Read before making project changes and update after every development action.

---

## 1. PROJECT OVERVIEW

**Project:** HALAL Food  
**Repository:** `royalguard14/HalalFood`  
**Local path:** `D:\FlutterApps\HALAL\halalfood`  
**Stack:** Flutter / Dart + Supabase  
**Concept:** Foodpanda-style food ordering platform focused on halal restaurants only.

Main sides:
1. Customer/User app
2. Restaurant Owner side
3. Admin side
4. Developer control layer
5. Future Driver/delivery workflow

---

## 2. DEVELOPMENT RULES / USER PREFERENCES

- Work **step-by-step**.
- User prefers actual repository/code changes, not Notepad/manual editing instructions.
- Inspect current implementation before changing important features.
- Make focused changes; preserve working functionality.
- When possible, edit GitHub directly, commit, then tell the user to `git pull` and test.
- Project must keep `.env` configuration for environment/public config such as map tokens; never commit private secrets, service-role keys, passwords, or credentials.
- Debug/test controls must be protected by `kDebugMode` or otherwise excluded from production.

### Mandatory change-log rule
**Every development action/change must be recorded in this file.** Record date, files, reason, behavior/logic, DB/Supabase changes, testing/result, commit/hash, current stopping point and next task as applicable. Never intentionally delete previous history; corrections are new entries.

---

## 3. DEVELOPMENT ENVIRONMENT

- Windows 11 Pro 64-bit
- Flutter stable 3.47.0
- Flutter executable: `D:\src\flutter\bin\flutter.bat`
- Project: `D:\FlutterApps\HALAL\halalfood`
- Android emulator: Pixel_8 / `emulator-5554`
- Android API: 37
- Chrome/Edge available

Do not assume Flutter is under `C:\src\flutter`.

---

## 4. CURRENT PROJECT STRUCTURE

```text
lib/
  main.dart
  app/
    app.dart
    theme.dart
  core/
    constants/
  features/
    splash/
      splash_screen.dart
    auth/
      screens/
    admin/
      screens/
    developer/
      screens/
    owner/
      screens/
    delivery/
      screens/
        driver_dashboard_screen.dart
    ...
  shared/
    widgets/
```

---

## 5. CONFIGURATION / ENVIRONMENT

Dotenv/environment configuration is already set up; a previous `dotenv has not been initialized` issue was fixed. Keep environment-specific configuration out of source control where appropriate. Never expose a Supabase service-role key in Flutter.

---

## 6. SUPABASE

Supabase project: `taltqnxhivpfwjqlvxnt`.

Important areas include:
- restaurants
- restaurant_subscriptions
- subscription_plans
- subscription_payments
- halal_verifications
- subscription_payment_methods
- subscription_plan_payment_methods
- orders
- order_items
- payments
- user_addresses
- delivery_pricing_settings
- app_settings
- menu/category tables
- promo_codes
- favorite_restaurants

Storage bucket used by owner subscription flow: `subscription-payment-proofs`.

---

## 7. AUTHENTICATION / ROLE ROUTING

Temporary quick-login/debug login exists to reduce repeated login/logout. It is protected by `kDebugMode`; credentials are intentionally not documented here.

Final roles:
1. `customer`
2. `restaurant_owner`
3. `admin`
4. `developer`
5. `driver`

There is **no `verifier` role**.

### Startup routing

```text
No session
  → Login

Developer (`is_developer() == true`)
  → Developer Dashboard

Admin
  → Admin Dashboard

Restaurant Owner
  → Owner Restaurant Selection

Driver
  → Driver Dashboard

Customer / unknown normal role
  → Customer Home
```

Developer access must be checked through `is_developer()` **before** the normal `profiles.role` query because Developer profiles can be hidden by RLS.

---

## 8. MAJOR STATUS

### Subscription Management
**DONE / working.** CRUD and testing completed.

### Admin / Owner subscription workflow

```text
Owner selects plan
→ submits payment information
→ uploads payment proof
→ Pending
→ Admin Action Center
→ Admin review
→ Approve / Reject
→ Owner status updates
```

Current development direction:
1. Build Developer controls one module at a time.
2. Keep operational Admin separate from Developer controls.
3. Secure destructive Developer operations server-side.
4. Finish backend/security hardening.
5. Build Customer/User ordering after the control layer is stable.

---

## 9. ROLE MANAGEMENT RULES

- Current logged-in Admin/Developer must not appear in Users & Roles.
- Users cannot change their own role.
- Developer can manage all five supported roles of other users.
- Admin UI exposes Customer ↔ Restaurant Owner changes only.
- Developer accounts are hidden from Admin.
- Database trigger `enforce_role_management_rules()` blocks self-role changes and unauthorized assignments.

---

## 10. ADMIN IMPLEMENTATION

### Admin Action Center
`lib/features/admin/screens/admin_action_center_screen.dart`

Loads pending halal verifications and subscription payments, joins restaurant information, displays action cards, opens review screens and uses realtime subscriptions.

### Admin subscription payment review
`lib/features/admin/screens/admin_subscription_payment_review_screen.dart`

Hardened in commit `dc4dfd13c893d3f71e85c39c60be07e88ad2ba51`. User runtime test: **PASSED / working**.

### Admin Users & Roles
`lib/features/admin/screens/user_role_management_screen.dart`

- Developer: all five roles.
- Admin: Customer ↔ Restaurant Owner.
- Current account excluded.
- Developer accounts hidden from Admin.
- Database trigger blocks self-role changes.

---

## 11. OWNER SUBSCRIPTION SUBMISSION

`lib/features/owner/screens/owner_subscribe_screen.dart` was hardened against duplicate submissions and orphan pending subscriptions.

Migration: `supabase/owner_subscription_submission_hardening.sql`.

Partial unique index prevents multiple pending subscriptions per restaurant; owner-only rollback policies were added.

Runtime test of duplicate/rollback hardening remains pending.

---

## 12. DATABASE CLEANUP

Development/test transaction data was removed because Customer/User ordering is not active yet.

Verified after cleanup:
- orders: 0
- order_items: 0
- payments: 0
- user_addresses: 0

Migration: `supabase/cleanup_pre_customer_test_transactions.sql`  
Commit: `a7579adeb86ea28cd3f519fd90a5d83686b01721`

Do not casually run this against a production DB containing real customer transactions.

---

## 13. DEVELOPER ARCHITECTURE

Developer is **not** simply another way to open the entire Admin dashboard. Developer controls are built individually.

Planned Developer controls include:
- Users & Roles
- Restaurant management / destructive maintenance
- controlled menu/category management
- subscriptions/payment controls
- halal verification
- delivery pricing
- app settings
- security/audit
- feature flags
- branding/theme
- database health/maintenance

Destructive Developer actions require explicit confirmation and server-side authorization.

---

## 14. DEVELOPER RESTAURANT CONTROL

Developer Dashboard removed the old **Full Admin Console** card and uses a dedicated restaurant-control module.

File: `lib/features/developer/screens/developer_restaurant_management_screen.dart`

Current behavior:
- list restaurants
- search by restaurant name/city/province
- show basic status, halal status, rating/review count
- explicit permanent-delete action with warning
- preserve owner and customer accounts

### Permanent restaurant deletion

Backend function: `public.developer_delete_restaurant(uuid)`  
Migration: `supabase/developer_restaurant_cascade_delete.sql`  
Commit: `f2dcbdd9fec4f34e1fd37caa2b9eee568c8aab91`

Function verifies `public.is_developer()`, uses `SECURITY DEFINER` with pinned `search_path = public`, revokes execution from `public` and `anon`, and grants authenticated execution.

Deletes restaurant-related orders/payments/items, menus/categories, favorites, promos, subscription payments/subscriptions, halal verification, category mappings, hours, photos and restaurant row.

Owner profile, customer profiles and customer addresses are preserved.

Supabase verification confirmed `anon_execute = false`, `authenticated_execute = true`, and Developer authorization exists.

**Open:** database deletion does not automatically clean external Storage objects. Storage bucket/path conventions must be inspected before claiming 100% cleanup.

---

## 15. DEVELOPER DASHBOARD MODULES

Current modules include:
- Users & Roles
- Restaurants
- Menus
- Food Categories
- Orders
- Subscriptions
- Halal Verification
- Delivery Pricing
- Promos & Discounts
- App Settings
- Action Center
- Developer Profile

Add new Developer modules individually; do not create another monolithic Admin screen.

---

## 16. DRIVER / DELIVERY

The `driver` role already exists.

Placeholder screen:
`lib/features/delivery/screens/driver_dashboard_screen.dart`

Current UI:
- welcome/header
- Online/Offline toggle (UI-only)
- Today / Earnings / Completed placeholders
- Current Delivery empty state
- My Deliveries placeholder
- Earnings placeholder
- Delivery Map placeholder
- My Profile placeholder
- Logout

No assignment, location tracking, earnings calculation or online-status persistence exists yet.

---

## 17. DELIVERY PRICING SECURITY FINDING

`public.delivery_pricing_settings` previously had RLS disabled and needs deliberate access design before production. Do not blindly enable RLS without checking existing app access patterns.

---

## 18. SECURITY AUDIT OPEN ITEMS

Review/harden:

### SECURITY DEFINER
- calculate_delivery_fee
- expire_restaurant_subscriptions
- handle_new_user
- is_admin

### Mutable search_path
- set_promo_codes_updated_at
- update_updated_at
- update_updated_at_column
- set_app_settings_updated_at
- set_payments_updated_at
- set_subscription_updated_at

Also review missing FK indexes, duplicate indexes and Auth leaked-password protection before production hardening.

---

## 19. BASELINE MIGRATION DIRECTION

Eventually create clean baseline migrations capable of provisioning a fresh HALAL Food Supabase database with schema, indexes/FKs, enums/functions/triggers, RLS, storage policies/buckets, seed/reference data and Developer bootstrap configuration.

Never commit Developer passwords.

---

## 20. EXPECTED TEST FLOW

```text
DEVELOPER → Developer Control Panel → module → controlled operation → server authorization → result
ADMIN     → Operational Admin console
OWNER     → Restaurant/subscription workflows
DRIVER    → Driver Dashboard → future delivery/map/earnings
CUSTOMER  → future customer ordering
```

Destructive tests must verify confirmation UI, Developer-only backend authorization, non-Developer rejection, intended related-row deletion, preservation of unrelated data, and Storage cleanup once implemented.

---

## 21. GIT WORKFLOW

```text
Inspect current code
→ focused repository change
→ update chat-gpt.md
→ commit to GitHub
→ user git pull
→ user tests
→ user reports result
→ update chat-gpt.md with test result
```

Never tell the user to pull before a new commit exists.

---

## 22. IMPORTANT CODE PRINCIPLES

- Preserve working screens.
- Prefer focused changes.
- Do not remove existing functionality without reason.
- Reuse existing Supabase relationships unless schema changes are intentional.
- Do not invent DB columns.
- Inspect existing schema/queries before DB-dependent changes.
- Handle loading/empty/error/success states.
- Prevent duplicate submissions.
- Keep debug/test controls out of production.
- Keep secrets out of Git.
- Never ship a Supabase service-role key in Flutter.
- Developer destructive actions must be server-authorized and explicitly confirmed.

---

# 23. PROJECT CHANGE LOG

> **Mandatory:** Newest entries are at the top. Add an entry for every development action.

### 2026-09-17 — Implemented global app branding/theme architecture

- **User request:** Remove client-specific branding. There must be one general/global app branding configuration for each deployment/person. Changing a color in Developer Branding must affect the actual app theme, not only the preview.
- **Files changed:**
  - `lib/features/developer/data/brand_config_repository.dart`
  - `lib/features/developer/providers/brand_theme_provider.dart`
  - `lib/features/developer/screens/developer_branding_screen.dart`
  - `lib/app/theme.dart`
  - `lib/app/app.dart`
- **Repository logic:** Removed `getAllBrands()` / client selection behavior. Branding now uses one fixed global database key: `halalfood`.
- **Provider logic:** `BrandThemeProvider` loads the global config, saves the global config, and notifies `MaterialApp` so the live app theme rebuilds immediately.
- **App startup:** `MaterialApp` now calls the provider's global `load()` instead of using `Env.brandKey` for client selection.
- **Theme propagation:** Primary, secondary, accent, background, surface, text and border values are mapped into Material 3 `ColorScheme` and common Material components including cards, AppBar, FilledButton, ElevatedButton, inputs, dividers and outlines. Existing `HalalFoodBrandExtension` remains available for screens that need explicit brand colors.
- **Developer UI:** Removed Saved Brands, Client/Brand selector and Brand Key editing. UI is now General App Branding → App Name → Theme Colors → Live Preview → Save Global Branding.
- **Color editing:** Every color has HEX input and Pick Color HSV picker; both edit the same global value.
- **Save behavior:** Save persists to Supabase and immediately updates the in-memory global theme through `BrandThemeProvider`.
- **Supabase:** Queried the actual `brand_configs` schema before changing code. Verified all required columns already exist and verified one existing `halalfood` row. **No DB migration was required.**
- **Dependencies:** No new package added.
- **Testing:** Supabase schema/data verification completed. Local `flutter analyze` and runtime testing are **PENDING** until user pulls the new commits.
- **Commits:**
  - `11c6c7b7fe524f121a163380991a8e514ccd2d88` — global-only repository
  - `597c345ced9a39d78f4b729b3e22fdda573ffe93` — global theme provider
  - `76d26becc3c0480d680a8d65bee12beae854e957` — app startup global branding
  - `988ad4c89be6cc6cd36e586771892af2dadbd8f0` — Material theme propagation
  - `ed1738381e80690ccf4d56541f13c695d4aeb78c` — Developer Branding global UI
- **Current stopping point:** Code is pushed to `main`; waiting for local pull/analyzer/runtime test.
- **Immediate next:** `git pull` → `flutter analyze` → run app → Developer → Branding → change colors → Save → verify actual screens/widgets change globally.

### 2026-09-17 — Developer Branding UI redesigned with HEX + Pick Color

- **User request:** Make Developer Branding easier to use because guessing HEX colors is difficult; provide two color-selection options: exact HEX input and visual Pick Color; improve the Developer UI and group related controls.
- **File changed:** `lib/features/developer/screens/developer_branding_screen.dart`
- **UI changes:**
  - Grouped content into Saved Brands, Brand Identity, Theme Colors and Live Preview cards.
  - Added clear HEX color inputs with color swatch previews.
  - Added **Pick Color** button beside every theme color.
  - Added an in-app HSV color picker dialog with Hue, Saturation and Brightness controls.
  - Picked color automatically converts back to uppercase `#RRGGBB` HEX and fills the field.
  - Existing manual HEX validation remains enforced on save.
  - Improved branding header, icons, spacing and live preview.
  - Live preview now demonstrates background, surface, gradient branding and accent/action color.
- **HEX format:** six-digit RGB only, e.g. `#0B6B3A`.
- **Dependencies:** No new Flutter package added; picker is implemented with Flutter Material/HSV APIs.
- **Supabase DB changes:** None.
- **Testing:** Repository code has been committed, but local `flutter analyze` and runtime UI testing are **PENDING** until the user pulls the commit.
- **Commit:** `04d6295ff1ae584edc098d418d28e72fa6f81d94`
- **Status:** Superseded by the global-only branding implementation above.

### 2026-09-17 — Fixed Developer Branding syntax/analyzer blocker

- **File:** `lib/features/developer/screens/developer_branding_screen.dart`
- **Action:** Fixed malformed `_preview()` syntax/bracket mismatch and updated deprecated dropdown API usage.
- **Commit:** `9571215352d1021e521dfb8701708fe686cc3c2c`

### 2026-09-17 — Fixed startup role routing and added Driver Dashboard

- **Files:** `lib/features/splash/splash_screen.dart`, `lib/features/auth/screens/login_screen.dart`, `lib/features/delivery/screens/driver_dashboard_screen.dart`
- **Routing:** No session → Login; Developer → Developer Dashboard; Admin → Admin Dashboard; Owner → Owner Restaurant Selection; Driver → Driver Dashboard; Customer/unknown → Customer Home.
- **Important:** Developer check uses `is_developer()` before normal profile query because Developer profile visibility can be affected by RLS.
- **Driver:** Added placeholder dashboard with online/offline UI, stats placeholders, current delivery empty state, future tools and logout.
- **Commits:**
  - Driver screen: `fb1afe338cae0bf22692baec6cfc12878fb89950`
  - Splash routing: `ee655029e7ceb447637cc71a4b03de3698178991`
  - Login Driver routing: `e496d200f14c5d884093bc91ff31e984e7ecf9a0`
- **Testing:** Local runtime/analyzer test was pending until pull.

### 2026-09-17 — Developer restaurant control separated from Admin console

- Added dedicated Developer Restaurants module and removed Full Admin Console card.
- Files: `developer_dashboard_screen.dart`, `developer_restaurant_management_screen.dart`.
- Commits: `80c7b4ad065d458b941970d4eb30e16ce44e7adf`, `c47aacc20e459b089c7ba840e38e7039c7448612`.
- Status: Implemented; runtime test pending.

### 2026-09-17 — Added Developer-only permanent restaurant cascade deletion

- Added `public.developer_delete_restaurant(uuid)` through `supabase/developer_restaurant_cascade_delete.sql`.
- Commit: `f2dcbdd9fec4f34e1fd37caa2b9eee568c8aab91`.
- Applied and security-checked in Supabase.
- Storage cleanup remains open.

### 2026-09-17 — Restored Admin Customer/Restaurant Owner role editing

- File: `lib/features/admin/screens/user_role_management_screen.dart`.
- Admin can change Customer ↔ Restaurant Owner; Developer can manage all five roles; Developer accounts remain hidden from Admin.
- Commit: `237ec2070dfe16acb9330581d952a59a0ba5dc20`.
- User confirmed OK.

### 2026-09-17 — Fixed user-role repository filtering query

- Fixed `.neq('id', currentUserId)` ordering in `admin_user_repository.dart`.
- Commit: `e35dfe9716dc0c4aee39f6c1e5ba5579204b2963`.

### 2026-09-17 — Cleaned pre-Customer test transaction data

- Removed development/test transaction data from orders, order_items, payments and user_addresses where applicable.
- Verified counts were zero.
- Migration: `cleanup_pre_customer_test_transactions`.
- Commit: `a7579adeb86ea28cd3f519fd90a5d83686b01721`.

### 2026-09-17 — Owner subscription submission hardening

- Hardened duplicate submissions and failed-step orphan records.
- Files: `owner_subscribe_screen.dart`, `supabase/owner_subscription_submission_hardening.sql`.
- Code commit: `5772d311f86e69175298d15c7abe0403f2bb5f4e`.
- SQL commit: `fd2bd411e932701e767e32ac3075288a6c053d4c`.
- Runtime test remains pending.

### 2026-09-17 — Admin subscription payment hardening runtime test PASSED

- Commit under test: `dc4dfd13c893d3f71e85c39c60be07e88ad2ba51`.
- User reported WORKING / PASSED.

### 2026-09-17 — Created AI handoff document

- Created `chat-gpt.md` for AI continuity.
- Commit: `5bc6457feb926f08efcedcbdffe94d47f4576e3a`.

### 2026-09-17 — Added mandatory per-change logging rule

- Updated `chat-gpt.md` to require complete project-change logging.
- Commit: `353bbd257abf51ae1b909009ffd3469715c1674a`.

---

## 24. CURRENT STOPPING POINT

The current work is **Developer Branding / Theme controls**.

The architecture is now explicitly **global-only**:

```text
One deployment / one app
        ↓
One global brand_configs row (brand_key = halalfood)
        ↓
BrandConfigRepository
        ↓
BrandThemeProvider
        ↓
MaterialApp.theme
        ↓
Actual app-wide Material theme
```

There are no Client 1 / Client 2 branding configurations and no client selector.

### Exact test state

**NOT YET LOCALLY TESTED AFTER THE GLOBAL-THEME IMPLEMENTATION.**

Do not claim runtime/analyzer-clean until the user pulls and reports the result.

Latest implementation commit:
`ed1738381e80690ccf4d56541f13c695d4aeb78c`

---

## 25. IMMEDIATE NEXT TASK

1. User runs:
   ```powershell
   cd D:\FlutterApps\HALAL\halalfood
   git pull
   flutter analyze
   ```
2. If analyzer has errors, fix those first.
3. Run the app.
4. Open Developer → Branding.
5. Test every color field using both:
   - manual HEX
   - Pick Color
6. Save branding.
7. Verify the actual app screens/components change according to the global theme, not just the preview.
8. Verify reload/restart loads the saved global colors from Supabase.
9. Report the first result/error before starting another unrelated feature.
10. Record the test result in this file.

---

## 26. FUTURE HANDOFF RULE

Whenever any project action changes the development state, update this file, including:
- PROJECT CHANGE LOG
- CURRENT STOPPING POINT
- IMMEDIATE NEXT TASK
- relevant feature/status section
- known bugs/issues
- important commit/hash
- latest test result

A new ChatGPT session should read this file before asking the user to repeat project history.

This file is the project's **AI continuity / handoff document**.
