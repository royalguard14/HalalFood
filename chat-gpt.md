# HALAL Food — ChatGPT Project Handoff

> **Purpose:** This file is the permanent handoff/context document for AI assistants working on this repository.
> Read this file before making project changes. Update it whenever project progress changes.

---

## 1. PROJECT OVERVIEW

**Project name:** HALAL Food  
**Repository:** `royalguard14/HalalFood`  
**Local project path:** `D:\FlutterApps\HALAL\halalfood`  
**Stack:** Flutter / Dart + Supabase  
**Concept:** A Foodpanda-style food ordering platform focused on **halal restaurants only**.

The long-term product has three major sides:

1. **Customer/User app** — browse halal restaurants, products, cart, checkout, orders, delivery, etc.
2. **Restaurant Owner side** — restaurant management, subscription, payments, halal verification, orders, etc.
3. **Admin side** — restaurant/halal verification, subscription/payment review, platform management, etc.

---

## 2. IMPORTANT DEVELOPMENT RULES / USER PREFERENCES

- Work **step-by-step**.
- User prefers **actual code/repository changes**, not instructions to manually edit files in Notepad.
- When possible, edit the GitHub repository directly, commit the changes, then tell the user to `git pull` and test.
- Do not make broad unrelated refactors while fixing a specific feature.
- Preserve working functionality unless a change is intentionally required.
- The project should use a `.env` approach for configuration/secrets such as map tokens and authentication-related public configuration.
- Never commit real secrets, service-role keys, passwords, or private credentials to this repository.
- Temporary test/debug functionality must be protected by `kDebugMode` or otherwise prevented from appearing in production builds.
- Before changing an important feature, inspect the current implementation first.

### CRITICAL: PROJECT CHANGE LOG RULE

**EVERY SINGLE DEVELOPMENT ACTION/CHANGE MUST BE RECORDED IN THIS FILE.**

For every change, record the date/time, files, reason, behavior/logic, DB/Supabase changes, testing, result, commit/hash, current status, and next step as applicable. Never delete previous history; corrections are new entries.

After each completed development action, also update:

- `CURRENT STOPPING POINT`
- `IMMEDIATE NEXT TASK`
- relevant feature/status section when necessary

---

## 3. DEVELOPMENT ENVIRONMENT

- OS: Windows 11 Pro 64-bit
- Flutter: stable 3.47.0
- Flutter executable: `D:\src\flutter\bin\flutter.bat`
- Project: `D:\FlutterApps\HALAL\halalfood`
- Android emulator: Pixel_8 / `emulator-5554`
- Android API used for testing: API 37
- Chrome/Edge are also available

Do not assume the Flutter executable is under `C:\src\flutter`.

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

`main.dart` starts the application through `HalalFoodApp`.

---

## 5. CONFIGURATION / ENVIRONMENT

The project uses dotenv/environment configuration. A previous `dotenv has not been initialized` issue was fixed.

Keep environment-specific configuration out of source control where appropriate. Never put private Supabase service-role credentials or private passwords into Dart source code or this handoff file.

---

## 6. SUPABASE

Supabase project: `taltqnxhivpfwjqlvxnt`.

Important tables/areas include:

- `restaurants`
- `restaurant_subscriptions`
- `subscription_plans`
- `subscription_payments`
- `halal_verifications`
- `subscription_payment_methods`
- `subscription_plan_payment_methods`
- `orders`
- `order_items`
- `payments`
- `user_addresses`
- `delivery_pricing_settings`
- `app_settings`
- menu/category tables
- `promo_codes`
- `favorite_restaurants`

Storage bucket used by owner subscription flow:

```text
subscription-payment-proofs
```

Never expose a Supabase service-role key in the Flutter application.

---

## 7. AUTHENTICATION / TEMPORARY DEBUG LOGIN

A temporary quick-login/test-login feature was added to reduce repeated manual login/logout during development.

- Protected by Flutter `kDebugMode`.
- Must not appear in release/production builds.
- Known commit: `f5dac92fe6d20941659634378a951307af0c6ea0`
- Temporary credentials are intentionally not documented here.

Developer account currently used for testing has Developer access through `developer_access`; credentials are intentionally not documented in this file.

### Role-based startup routing

The application now uses the same role model for both fresh login and app restart after the splash screen:

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

Developer access is checked through `is_developer()` **before** reading `profiles.role` because Developer profiles can be hidden by RLS from normal profile queries.

---

## 8. DEVELOPMENT STATUS — MAJOR MILESTONES

### Phase 1 — Subscription Management

**Status: DONE / working**

Includes CRUD work for subscription management and testing.

### Admin / Owner subscription workflow

```text
Owner selects subscription plan
        ↓
Owner submits payment information
        ↓
Owner uploads payment proof
        ↓
Subscription/payment becomes Pending
        ↓
Admin Action Center detects pending item
        ↓
Admin reviews payment
        ↓
Approve OR Reject
        ↓
Owner subscription/payment status updates
```

### Current development order

1. Build Developer controls one module at a time.
2. Keep operational Admin functionality separate from Developer functionality.
3. Secure destructive Developer operations server-side.
4. Finish backend/security hardening.
5. Build Customer/User ordering after the control layer is stable.

---

## 9. ROLE MODEL / ACCESS RULES

Final application roles:

1. `customer`
2. `restaurant_owner`
3. `admin`
4. `developer`
5. `driver`

There is **no `verifier` role**.

Developer access is also represented in `public.developer_access`; this remains authoritative for `is_developer()`.

### Role-management rules

- Current logged-in Admin/Developer must not appear in Users & Roles.
- Users cannot change their own role.
- Developer can manage all supported roles of other users.
- Admin UI exposes Customer ↔ Restaurant Owner role changes only.
- Developer accounts are hidden from normal Admin user management.
- Database trigger `enforce_role_management_rules()` also blocks self-role changes and unauthorized role assignments.

---

## 10. ADMIN — CURRENT IMPLEMENTATION

### Admin Action Center

`lib/features/admin/screens/admin_action_center_screen.dart`

- Loads pending `halal_verifications` and `subscription_payments`.
- Joins restaurant information.
- Displays action cards.
- Opens review screens.
- Uses realtime subscriptions.

### Admin subscription payment review

`lib/features/admin/screens/admin_subscription_payment_review_screen.dart` was hardened in commit `dc4dfd13c893d3f71e85c39c60be07e88ad2ba51`.

Runtime test: **PASSED / working** according to the user.

### Admin Users & Roles

`lib/features/admin/screens/user_role_management_screen.dart` now supports:

- Developer: all five application roles.
- Admin: Customer ↔ Restaurant Owner in the UI.
- Current logged-in account excluded from the list.
- Developer accounts hidden from Admin.
- Self-role changes blocked by database trigger.

---

## 11. OWNER SUBSCRIPTION SUBMISSION

`lib/features/owner/screens/owner_subscribe_screen.dart` was hardened against duplicate submissions and orphan pending subscriptions.

Supabase migration:

`supabase/owner_subscription_submission_hardening.sql`

Adds a partial unique index for one pending subscription per restaurant and owner-only rollback delete policies.

Known follow-up: runtime test of the Owner duplicate/rollback hardening is still pending.

---

## 12. DATABASE CLEANUP

Because the Customer/User ordering side is not active yet, old development/test transaction data was removed while preserving schema.

After cleanup:

- `orders`: 0
- `order_items`: 0
- `payments`: 0
- `user_addresses`: 0

Migration:

`supabase/cleanup_pre_customer_test_transactions.sql`

Commit: `a7579adeb86ea28cd3f519fd90a5d83686b01721`.

This cleanup migration must not be casually run against a production database containing real customer transactions.

---

## 13. DEVELOPER / SUPER ADMIN ARCHITECTURE

The Developer role is being built **one module at a time**.

Important design rule:

> Developer is not simply another way to open the entire Admin dashboard.

Operational Admin users may be numerous, so the Developer dashboard must not depend on one shared "Full Admin Console" screen. Developer gets its own system-level controls while Admin keeps its operational console.

Developer controls will eventually include:

- Users & Roles
- Restaurant management / destructive maintenance
- controlled menu/category management
- subscriptions and subscription payments
- halal verification
- delivery pricing
- app settings
- security/audit
- feature flags
- branding/theme
- database health/maintenance
- other controlled platform operations

Destructive Developer operations must always use explicit confirmation and server-side authorization.

---

## 14. DEVELOPER — RESTAURANT CONTROL

### Developer Dashboard change

The Developer dashboard previously contained a **Full Admin Console** card. This was intentionally removed.

Reason: if the platform has multiple Admin accounts, Developer should not simply impersonate/use one monolithic Admin console. Developer controls should be explicit and separated.

### New Developer screen

File:

`lib/features/developer/screens/developer_restaurant_management_screen.dart`

The Developer Dashboard now has a dedicated **Restaurants** module instead of the Full Admin Console.

Current Developer restaurant module:

- Lists restaurants.
- Search by restaurant name/city/province.
- Shows basic status, halal status, rating and review count.
- Provides a clearly destructive permanent-delete action.
- Shows a warning before deletion.
- Preserves the restaurant owner account and customer accounts.

### Permanent restaurant deletion

A Developer-only backend function was added:

`public.developer_delete_restaurant(uuid)`

Migration file:

`supabase/developer_restaurant_cascade_delete.sql`

Git commit containing migration file:

`f2dcbdd9fec4f34e1fd37caa2b9eee568c8aab91`

The migration was applied successfully to Supabase.

The function:

1. Verifies `public.is_developer()`.
2. Verifies the restaurant exists.
3. Collects the restaurant's order IDs.
4. Deletes related order payments.
5. Deletes related order items.
6. Deletes the restaurant's orders.
7. Deletes menu items.
8. Deletes menu categories.
9. Deletes favorite-restaurant rows.
10. Deletes restaurant promo codes.
11. Deletes subscription payments.
12. Deletes restaurant subscriptions.
13. Deletes halal verification records.
14. Deletes restaurant-category mappings.
15. Deletes restaurant hours.
16. Deletes restaurant photos.
17. Deletes the restaurant itself.

The owner profile is **not** deleted because `restaurants.owner_id` is `ON DELETE SET NULL` and the requested behavior is to remove the restaurant/data, not the user account.

Customer `user_addresses` are also **not** deleted because they belong to customers and may be used by other orders/restaurants.

### Backend security verification

The function is `SECURITY DEFINER` with a pinned `search_path = public`, explicitly checks `is_developer()`, and has execution revoked from `public` and `anon`.

Supabase verification after migration:

- `anon_execute = false`
- `authenticated_execute = true`
- function definition contains Developer authorization check

The Flutter app does not use a service-role key.

### Important remaining issue

Database deletion does not automatically remove external Storage objects such as restaurant images if those files are stored separately from the database. Storage cleanup must be handled explicitly after we inspect the actual restaurant image bucket/path conventions.

Do **not** claim restaurant deletion is 100% storage-clean until that part is implemented and tested.

---

## 15. DEVELOPER DASHBOARD — CURRENT MODULES

The Developer Dashboard no longer has `Full Admin Console`.

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

These existing operational modules are currently reused where appropriate, but the Developer-specific destructive Restaurant control is separate.

Next Developer modules should be added individually rather than creating another monolithic Admin screen.

---

## 16. DELIVERY / DRIVER

### Driver role

The Supabase role enum now includes `driver` alongside `customer`, `restaurant_owner`, `admin`, and `developer`.

A basic placeholder Driver Dashboard has now been added:

`lib/features/delivery/screens/driver_dashboard_screen.dart`

Current UI is intentionally basic and future-editable. It includes:

- Driver welcome/header card.
- Online / Offline toggle (UI state only for now).
- Today / Earnings / Completed placeholders.
- Current Delivery empty state.
- My Deliveries placeholder.
- Earnings placeholder.
- Delivery Map placeholder.
- My Profile placeholder.
- Logout.

No delivery assignment, location tracking, earnings calculation, or online-status persistence has been implemented yet. Those will be added later when the Driver workflow is developed.

---

## 17. DELIVERY PRICING SECURITY FINDING

`public.delivery_pricing_settings` previously had RLS disabled and needs a deliberate access design before production use.

Do not blindly enable RLS without verifying all existing app access patterns.

---

## 18. SECURITY AUDIT ITEMS STILL OPEN

Previously identified functions that should be reviewed/hardened:

### SECURITY DEFINER functions

- `calculate_delivery_fee`
- `expire_restaurant_subscriptions`
- `handle_new_user`
- `is_admin`

### Mutable search_path functions

- `set_promo_codes_updated_at`
- `update_updated_at`
- `update_updated_at_column`
- `set_app_settings_updated_at`
- `set_payments_updated_at`
- `set_subscription_updated_at`

Also review missing FK indexes, duplicate indexes, and Auth leaked-password protection before production hardening.

---

## 19. TURNOVER / BASELINE MIGRATION DIRECTION

Eventually create a clean baseline migration set capable of provisioning a fresh HALAL Food Supabase database with:

- schema/tables
- indexes and foreign keys
- enums/functions/triggers
- RLS policies
- storage policies/buckets as applicable
- seed/reference data
- Developer bootstrap configuration

Never commit the Developer account password as plaintext.

---

## 20. EXPECTED TEST FLOW

```text
DEVELOPER
  ↓
Sign in
  ↓
Developer Control Panel
  ↓
Open one Developer module
  ↓
Perform controlled operation
  ↓
Server-side authorization
  ↓
Confirm result

ADMIN
  ↓
Operational Admin console
  ↓
Manage normal platform operations

OWNER
  ↓
Restaurant/subscription workflows

DRIVER
  ↓
Driver Dashboard
  ↓
Future: delivery requests / active delivery / map / earnings

CUSTOMER
  ↓
To be implemented after backend/control layer is stable
```

For destructive operations, verify:

- confirmation UI
- Developer-only backend authorization
- non-Developer rejection
- successful deletion of all intended related rows
- preservation of unrelated users/data
- Storage cleanup once implemented

---

## 21. GIT WORKFLOW

Preferred workflow:

```text
ChatGPT inspects current code
        ↓
ChatGPT makes focused repository changes
        ↓
ChatGPT records the change in chat-gpt.md
        ↓
Commit changes to GitHub
        ↓
User runs:
    git pull
        ↓
User runs/tests the app
        ↓
User reports result
        ↓
ChatGPT records the test result in chat-gpt.md
        ↓
Continue from that exact state
```

Never tell the user to pull before a new commit exists.

---

## 22. IMPORTANT CODE-CHANGE PRINCIPLES

- Preserve existing working screens.
- Prefer focused changes over rewrites.
- Do not remove existing functionality without a reason.
- Reuse existing Supabase tables/relationships unless schema changes are intentional.
- Do not invent database columns.
- Inspect existing queries/schema/migrations before database-dependent changes.
- Handle loading, empty, error, and success states.
- Prevent duplicate submissions from rapid button taps.
- Keep production UI free of debug/test controls.
- Keep secrets out of Git.
- Never ship a Supabase service-role key in the Flutter application.
- Developer-only destructive actions must be server-authorized and explicitly confirmed.

---

# 23. PROJECT CHANGE LOG

> **Mandatory:** Add a new entry here for **every development change/action**. Never erase previous entries. Newest entries go at the top.

### 2026-09-17 — Fixed startup role routing and added Driver Dashboard

- **User request:** Before continuing other edits, fix the flow after Splash Screen so a logged-in account always goes to the correct dashboard, and prepare a basic Driver screen for future editing.
- **Inspected first:** Existing `splash_screen.dart` already handled Admin and Restaurant Owner but did not handle Developer through `is_developer()` and did not handle Driver.
- **Files changed:**
  - `lib/features/splash/splash_screen.dart`
  - `lib/features/auth/screens/login_screen.dart`
  - `lib/features/delivery/screens/driver_dashboard_screen.dart`
- **Startup routing:**
  - No session → Login
  - Developer via `is_developer()` → Developer Dashboard
  - `admin` → Admin Dashboard
  - `restaurant_owner` → Owner Restaurant Selection
  - `driver` → Driver Dashboard
  - `customer` / unknown normal role → Customer Home
- **Important:** Developer check is performed before the `profiles.role` query because Developer profile visibility is restricted by RLS.
- **Login routing:** Added Driver routing to the existing login flow. Developer/Admin/Owner routing was preserved.
- **Driver screen:** Added a basic, intentionally placeholder Driver Dashboard with Online/Offline UI, stats placeholders, Current Delivery empty state, future tool cards, and logout.
- **Supabase DB changes:** None in this action. The repository already contains the `driver` role migration (`add_developer_driver_roles_remove_verifier.sql`).
- **Git commits:**
  - Driver screen: `fb1afe338cae0bf22692baec6cfc12878fb89950`
  - Splash routing: `ee655029e7ceb447637cc71a4b03de3698178991`
  - Login Driver routing: `e496d200f14c5d884093bc91ff31e984e7ecf9a0`
- **Testing:** Repository changes completed. Local Flutter runtime/analyzer test is **PENDING** until the user pulls the commits.
- **Status:** Implemented; awaiting local test.
- **Next:** `git pull`, run `flutter analyze`, then test Developer/Admin/Owner/Driver/Customer startup routing.

### 2026-09-17 — Developer restaurant control separated from Admin console

- **Action:** Removed the Developer Dashboard's `Full Admin Console` module and replaced it with a dedicated Developer Restaurants module.
- **Files changed:**
  - `lib/features/developer/screens/developer_dashboard_screen.dart`
  - `lib/features/developer/screens/developer_restaurant_management_screen.dart`
- **Why:** Developer must not simply depend on a monolithic Admin console, especially when the platform may have multiple Admin users. Developer controls are being built individually.
- **Behavior:** Developer now has a dedicated restaurant-control screen with search and a destructive delete action.
- **Git commits:**
  - New screen: `80c7b4ad065d458b941970d4eb30e16ce44e7adf`
  - Dashboard update: `c47aacc20e459b089c7ba840e38e7039c7448612`
- **Testing:** Repository implementation completed. Local Flutter runtime test is **PENDING** until user pulls.
- **Status:** Implemented; awaiting local runtime test.
- **Next:** Test Developer → Restaurants and verify the delete confirmation/UI before using it on any real restaurant.

### 2026-09-17 — Added Developer-only permanent restaurant cascade deletion

- **Action:** Added `public.developer_delete_restaurant(uuid)` and applied the migration to Supabase.
- **Migration:** `supabase/developer_restaurant_cascade_delete.sql`
- **Supabase migration name:** `developer_restaurant_cascade_delete`
- **Git commit:** `f2dcbdd9fec4f34e1fd37caa2b9eee568c8aab91`
- **Why:** Developer must be able to permanently remove a restaurant and application data directly related to that restaurant, including orders, order items, payments, menus, subscriptions, subscription payments, halal verification, promos, favorites, hours, photos and category mappings.
- **Security:** Function checks `public.is_developer()`, uses `SECURITY DEFINER` with pinned `search_path`, revokes execution from `public` and `anon`, and grants execution only to `authenticated`.
- **Verification:** Supabase query confirmed `anon_execute = false`, `authenticated_execute = true`, and the Developer authorization check is present.
- **Preserved:** Owner account, customer accounts, and customer addresses are not deleted.
- **Storage:** Restaurant Storage objects are not yet automatically removed by this DB function; storage cleanup remains a separate task after bucket/path inspection.
- **Status:** Backend function applied and security-checked.
- **Next:** Runtime test with a disposable/test restaurant, then implement Storage cleanup.

### 2026-09-17 — Restored Admin Customer/Restaurant Owner role editing

- **Action:** Restored the Admin role-edit UI while preserving Developer full role management.
- **File:** `lib/features/admin/screens/user_role_management_screen.dart`
- **Behavior:** Admin can change Customer ↔ Restaurant Owner; Developer can manage all five supported roles. Developer accounts remain hidden from Admin.
- **Commit:** `237ec2070dfe16acb9330581d952a59a0ba5dc20`
- **Status:** User confirmed this is OK.

### 2026-09-17 — Fixed user-role repository filtering query

- **Action:** Fixed Supabase query chaining in `admin_user_repository.dart` so `.neq('id', currentUserId)` is applied before `.order(...)`.
- **Why:** Flutter analyzer reported `The method 'neq' isn't defined for the type 'PostgrestTransformBuilder'` with the previous query order.
- **Commit:** `e35dfe9716dc0c4aee39f6c1e5ba5579204b2963`
- **Status:** Corrected; remaining analyzer issues were unrelated pre-existing owner warnings/info.

### 2026-09-17 — Cleaned pre-Customer test transaction data

- **Action:** Removed development/test transaction data because the Customer/User ordering side is not active yet.
- **Tables:** `orders`, `order_items`, `payments`, `user_addresses` when unreferenced.
- **Verification:** `orders = 0`, `order_items = 0`, `payments = 0`, `user_addresses = 0`.
- **Migration:** `cleanup_pre_customer_test_transactions`.
- **Commit:** `a7579adeb86ea28cd3f519fd90a5d83686b01721`.
- **Status:** Cleanup completed and verified.

### 2026-09-17 — Owner subscription submission hardening implemented

- **Action:** Hardened Owner subscription submission against duplicate subscriptions and failed-step orphan records.
- **Files:** `lib/features/owner/screens/owner_subscribe_screen.dart`, `supabase/owner_subscription_submission_hardening.sql`.
- **Commits:** Code `5772d311f86e69175298d15c7abe0403f2bb5f4e`; SQL `fd2bd411e932701e767e32ac3075288a6c053d4c`.
- **Status:** Implemented; runtime testing remains pending.

### 2026-09-17 — Admin subscription payment hardening runtime test PASSED

- **Action:** Recorded the user's runtime test result for the Admin subscription payment hardening batch.
- **Commit under test:** `dc4dfd13c893d3f71e85c39c60be07e88ad2ba51`.
- **Result:** **WORKING / PASSED** according to the user's report.

### 2026-09-17 — Hardened Admin subscription payment review

- **Action:** Hardened pending-payment review, processing locks, confirmation, guarded updates and rollback behavior.
- **Commit:** `dc4dfd13c893d3f71e85c39c60be07e88ad2ba51`.
- **Status:** Done and runtime-tested.

### 2026-09-17 — Created AI handoff document

- **Action:** Created `chat-gpt.md` for AI continuity.
- **Commit:** `5bc6457feb926f08efcedcbdffe94d47f4576e3a`.

### 2026-09-17 — Added mandatory per-change logging rule

- **Action:** Updated `chat-gpt.md` to require complete project-change logging.
- **Commit:** `353bbd257abf51ae1b909009ffd3469715c1674a`.

---

## 24. CURRENT STOPPING POINT

The startup authentication flow is now prepared for the complete current role model.

After the Splash Screen, an existing session is routed by role:

```text
Developer  → Developer Dashboard
Admin      → Admin Dashboard
Owner      → Owner Restaurant Selection
Driver     → Driver Dashboard
Customer   → Customer Home
No session → Login
```

Developer authorization is checked through `is_developer()` before the normal profile query so the Developer account is not accidentally sent to Customer Home because of profile RLS visibility.

A basic Driver Dashboard exists and is intentionally placeholder-level for future development.

### Current exact test state

**The new routing and Driver Dashboard have NOT yet been runtime-tested locally.**

The user needs to pull the latest commits before testing.

---

## 25. IMMEDIATE NEXT TASK

1. User runs `git pull` from `D:\FlutterApps\HALAL\halalfood`.
2. Run `flutter analyze`.
3. Run the app.
4. Test Developer login → Developer Dashboard.
5. Restart the app while logged in as Developer → Splash → Developer Dashboard.
6. Test Admin → Admin Dashboard.
7. Test Restaurant Owner → Owner Restaurant Selection.
8. Test Driver → Driver Dashboard.
9. Test Customer → Customer Home.
10. Report the first runtime result/error before we continue editing another feature.

Do not start unrelated UI edits until this routing flow is confirmed working.

---

## 26. FUTURE HANDOFF RULE

Whenever any project action changes the development state, update this file.

At minimum, update:

- `PROJECT CHANGE LOG`
- `CURRENT STOPPING POINT`
- `IMMEDIATE NEXT TASK`
- relevant feature/status section
- known bugs/issues
- important commit/hash
- latest test result

A new ChatGPT session should read this file before asking the user to repeat project history.

This file is the project's **AI continuity / handoff document**.
