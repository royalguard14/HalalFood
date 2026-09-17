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

Do not only document major milestones. Whenever we make a project change, record it here so a future ChatGPT session can reconstruct exactly what happened.

For **every change**, add an entry to the `PROJECT CHANGE LOG` section containing, as applicable:

- Date/time or date of the change
- What we changed
- File(s) changed
- Why it was changed
- Important behavior/logic added or removed
- Database/Supabase changes, if any
- Testing performed
- Test result
- Git commit/hash
- Current status after the change
- What the next step is

If a change is later reverted or corrected, record that too. **Do not delete the previous history.** Add a new log entry explaining the correction.

After each completed development action, also update:

- `CURRENT STOPPING POINT`
- `IMMEDIATE NEXT TASK`
- relevant feature/status section when necessary

This rule applies even when the change is small, such as UI adjustment, bug fix, query change, Supabase change, auth change, temporary debug change, dependency/config change, file/folder restructuring, test result, or a failed attempt that materially changes our understanding.

The purpose is **AI continuity**: a new ChatGPT must be able to read this file and know exactly what happened without relying on the old conversation.

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
    owner/
      screens/
    ...
  shared/
    widgets/
```

`main.dart` starts the application through `HalalFoodApp`.

`app/app.dart` contains the main `MaterialApp` configuration and currently starts from `SplashScreen`.

Application title: **HALAL Food**  
Debug banner: disabled.

---

## 5. CONFIGURATION / ENVIRONMENT

The project uses dotenv/environment configuration. A previous `dotenv has not been initialized` issue was already fixed.

Keep environment-specific configuration out of source control where appropriate. Never put private Supabase service-role credentials or other private secrets into Dart source code or this handoff file.

---

## 6. SUPABASE

Supabase is already connected.

Important areas/tables:

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

Storage bucket used by owner subscription flow:

```text
subscription-payment-proofs
```

### Security reminder

Do not solve authentication/password problems by directly modifying `auth.users.encrypted_password`. Prefer the Supabase Admin API/service-role workflow for administrative password changes.

### Current database cleanup status

Customer ordering has not yet been activated. Development/test transaction data was therefore removed while preserving the transaction tables and schema.

After cleanup:

- `orders`: 0
- `order_items`: 0
- `payments`: 0
- `user_addresses`: 0

The schema remains intact for the future Customer side.

---

## 7. AUTHENTICATION / TEMPORARY DEBUG LOGIN

A temporary quick-login/test-login feature was added to reduce repeated manual login/logout during development.

- Protected by Flutter `kDebugMode`.
- Must not appear in release/production builds.
- Known commit: `f5dac92fe6d20941659634378a951307af0c6ea0`

Temporary credentials are intentionally not documented here.

---

## 8. DEVELOPMENT STATUS — MAJOR MILESTONES

### Phase 1 — Subscription Management

**Status: DONE / working**

Includes CRUD work for subscription management and testing.

### Admin / Owner subscription workflow

Implemented workflow:

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

### Current overall direction

1. Finish/test Admin + Owner production behavior.
2. Build the Developer/Super Admin control layer.
3. Establish clean baseline migrations and secure backend configuration.
4. Build the Customer/User side.
5. Connect customer ordering with restaurant/owner/admin workflows.

---

## 9. ADMIN — CURRENT IMPLEMENTATION

### `lib/features/admin/screens/admin_action_center_screen.dart`

- Loads pending `halal_verifications` and `subscription_payments`.
- Joins restaurant information.
- Displays action cards.
- Opens halal verification or subscription payment review screens.
- Uses realtime subscriptions for relevant tables.
- Displays an all-caught-up state when no pending actions remain.

### Admin subscription payment review

`lib/features/admin/screens/admin_subscription_payment_review_screen.dart` was hardened in commit `dc4dfd13c893d3f71e85c39c60be07e88ad2ba51`:

- Query loads only `pending` payments.
- Per-payment processing lock prevents rapid double actions.
- Approval requires confirmation.
- Uses actual `subscription_id` from payment, with joined fallback.
- Guarded payment update requires `pending`.
- Guarded subscription activation requires `pending`.
- If subscription activation fails, payment is restored to `pending`.
- Rejection requires a reason.
- Rejection is guarded and uses actual `subscription_id`.
- If subscription rejection fails, payment is restored to `pending`.
- Processing buttons are disabled and show a spinner.

**Runtime test:** User confirmed this batch is working.

---

## 10. OWNER SUBSCRIPTION SUBMISSION

### File

`lib/features/owner/screens/owner_subscribe_screen.dart`

### Before hardening

The screen loaded active plans/payment methods and created a pending subscription, uploaded proof, then created a pending payment. The main risks were duplicate active/pending submissions and orphan pending subscriptions if proof/payment creation failed.

### Owner hardening completed in this batch

- Added a blocking-state query for `pending`, `trial`, `active`, `past_due`, and `grace_period` subscriptions.
- The subscription screen now stops showing new plans/submission controls when a blocking subscription already exists.
- Added a second blocking-state check when a plan button is pressed.
- Added a **final immediate re-check before inserting** `restaurant_subscriptions`, protecting against stale UI/state.
- Added handling for Postgres uniqueness error `23505` so a concurrent duplicate submission produces a clear user message instead of a raw error.
- Added best-effort cleanup after a created subscription later fails: remove uploaded proof and delete the still-pending subscription row.
- Existing cancelled/expired subscriptions are not part of the blocking-state query, so the existing resubmission behavior remains available.

### Supabase hardening migration

New file:

`supabase/owner_subscription_submission_hardening.sql`

It adds:

1. Unique partial index preventing more than one `pending` subscription per restaurant.
2. Owner delete policy limited to their own `pending` subscription rows, used only for rollback cleanup.
3. Owner storage delete policy limited to their own restaurant folder in `subscription-payment-proofs`, used for rollback cleanup.

No existing subscription/payment schema was otherwise changed.

---

## 11. OWNER SUBSCRIPTION MANAGEMENT

### File

`lib/features/owner/screens/owner_subscription_management_screen.dart`

Current behavior:

- Loads restaurant subscriptions newest first.
- Displays current/latest subscription and payment history.
- Handles Active, Trial, Pending Review, Past Due, Grace Period, Suspended, Cancelled, Expired, Approved, and Rejected labels.
- Pending subscriptions display payment-under-review information.
- Resubmission remains allowed for cancelled/expired subscriptions.

---

## 12. DATABASE CLEANUP / DEVELOPER ARCHITECTURE

### Cleanup completed — 2026-09-17

Because the Customer/User ordering side is not active yet, old development transaction data was removed from:

- `orders`
- `order_items`
- `payments`
- `user_addresses` when no longer referenced by an order

The tables, relationships, enums, indexes, and RLS configuration were preserved.

Repository migration:

`supabase/cleanup_pre_customer_test_transactions.sql`

This migration records the cleanup operation for reproducibility. It must **not** be used casually against a production database containing real customer transactions.

### Developer / Super Admin direction

The next architecture will introduce a Developer-only control layer with access to platform configuration and maintenance functions, including:

- user/account management
- roles and permissions
- restaurant management
- menu/category management
- subscriptions and subscription payments
- halal verification
- promo codes
- delivery pricing
- app settings
- maintenance mode
- branding/logo configuration
- theme/color configuration
- feature flags
- controlled database cleanup/maintenance tools

This should be implemented as a protected application role and backend policy model, **not** by exposing a Supabase service-role key inside the Flutter app.

The Developer panel may provide powerful CRUD/maintenance operations, but destructive actions should use explicit confirmations and server-side authorization.

### Important security finding to address

`public.delivery_pricing_settings` currently has RLS disabled. Supabase identifies this as a critical exposure because client roles can otherwise access/modify its rows. We will not blindly enable RLS without first designing the correct Developer/Admin read/write policies so existing delivery functionality is not broken.

### Turnover / one-click setup direction

We will create a clean baseline migration set that can provision a fresh HALAL Food Supabase database with:

- schema/tables
- indexes and foreign keys
- enums/functions/triggers
- RLS policies
- storage policies/buckets as applicable
- seed/reference data
- Developer bootstrap configuration

The Developer account password must **not** be committed as plaintext in GitHub. The final setup will use a secure bootstrap/password-setting mechanism instead.

---

## 13. IMMEDIATE NEXT TASK

1. Inspect the Flutter repository for all existing Developer/Admin configuration needs and current `delivery_pricing_settings` usage.
2. Design the Developer role and protected backend functions/policies.
3. Add Developer control screens for platform settings/branding/maintenance.
4. Harden `delivery_pricing_settings` with policies after verifying app access patterns.
5. Audit SECURITY DEFINER functions and mutable `search_path` functions.
6. Establish the baseline Supabase migration set.
7. Only then move into Customer/User ordering.

---

## 14. EXPECTED TEST FLOW

Developer/Admin work will be tested separately from the Customer flow:

```text
DEVELOPER
  ↓
Sign in
  ↓
Developer control panel
  ↓
Manage platform configuration
  ↓
Change branding/theme/settings
  ↓
Manage controlled backend data
  ↓
Test confirmations and authorization

OWNER / ADMIN
  ↓
Existing subscription and halal workflows remain working

CUSTOMER
  ↓
To be implemented after backend/control layer is stable
```

For destructive maintenance operations, verify confirmation dialogs and ensure the action is rejected for non-Developer accounts.

---

## 15. KNOWN PREVIOUS BUILD ISSUE

A Gradle/Kotlin incremental cache problem previously occurred around `shared_preferences_android`, with an error similar to a storage/cache entry being already registered.

If it returns, inspect/clean the relevant Gradle/Kotlin caches before changing application code.

---

## 16. GIT WORKFLOW

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

**Never tell the user to pull before a new commit exists.**

---

## 17. IMPORTANT CODE-CHANGE PRINCIPLES

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

# 18. PROJECT CHANGE LOG

> **Mandatory:** Add a new entry here for **every development change/action**. Never erase previous entries. Newest entries go at the top.

### 2026-09-17 — Cleaned pre-Customer test transaction data

- **Action:** Removed development/test transaction data because the Customer/User ordering side is not active yet.
- **Supabase project:** `halalfood` / `taltqnxhivpfwjqlvxnt`
- **Tables affected:** `orders`, `order_items`, `payments`, `user_addresses`.
- **Why:** Keep the current database clean before building the Customer side while preserving all transaction schema for future use.
- **Data removed:** All current rows from `orders`, `order_items`, and `payments`; unreferenced `user_addresses` were also removed.
- **Schema changes:** None. Tables, relationships, enums, indexes, and RLS were preserved.
- **Verification:** `orders = 0`, `order_items = 0`, `payments = 0`, `user_addresses = 0` after cleanup.
- **Supabase migration:** `cleanup_pre_customer_test_transactions` applied successfully.
- **Repository file:** `supabase/cleanup_pre_customer_test_transactions.sql`.
- **Git commit:** `a7579adeb86ea28cd3f519fd90a5d83686b01721` for the migration file.
- **Documentation commit:** current `chat-gpt.md` update.
- **Status:** Cleanup completed and verified.
- **Next:** Build the Developer/Super Admin architecture and secure backend configuration.

### 2026-09-17 — Owner subscription submission hardening implemented

- **Action:** Hardened the Owner subscription submission flow against duplicate subscriptions and failed-step orphan records.
- **Files changed:**
  - `lib/features/owner/screens/owner_subscribe_screen.dart`
  - `supabase/owner_subscription_submission_hardening.sql`
  - `chat-gpt.md`
- **Why:** Prevent a restaurant with an existing active/pending subscription from opening/submitting another subscription and reduce orphan pending subscriptions when later submission steps fail.
- **Application logic:**
  - Checks blocking statuses before loading the plan UI.
  - Re-checks when a plan is selected.
  - Re-checks immediately before subscription insert.
  - Handles database uniqueness violation `23505` as a duplicate-subscription message.
  - Best-effort cleanup removes proof storage and deletes the pending subscription after later submission failure.
  - Cancelled/expired remain eligible for resubmission.
- **Supabase changes:** Added a partial unique index for one pending subscription per restaurant, plus owner-only pending subscription delete and owner-only proof delete policies for rollback.
- **Testing:** Code/schema audit completed. Runtime testing by user is **PENDING**.
- **Commits:**
  - Code: `5772d311f86e69175298d15c7abe0403f2bb5f4e`
  - SQL migration: `fd2bd411e932701e767e32ac3075288a6c053d4c`
  - Documentation: this commit
- **Status:** Ready for user pull + Supabase migration + runtime test.
- **Next:** Run the SQL migration, pull the latest commits, then test Owner duplicate blocking, normal submission, cancelled/expired resubmission, and the full Owner → Admin → Owner workflow.

### 2026-09-17 — Admin subscription payment hardening runtime test PASSED

- **Action:** Recorded the user's runtime test result for the Admin subscription payment hardening batch.
- **Files:** `chat-gpt.md` only for this documentation action.
- **Why:** User confirmed the updated Admin payment review workflow is working in the local app.
- **Testing performed by user:** Tested after pulling commit `dc4dfd13c893d3f71e85c39c60be07e88ad2ba51`.
- **Test result:** **WORKING / PASSED** according to the user's report.
- **Database/Supabase changes:** None during this documentation update.
- **Commit:** Documentation update.
- **Status:** Admin hardening batch is runtime-tested and confirmed working.
- **Next:** Owner duplicate subscription submission and failed-step/orphan-subscription hardening.

### 2026-09-17 — Hardened Admin subscription payment review

- **Action:** Updated `admin_subscription_payment_review_screen.dart` to harden payment approval/rejection handling.
- **Files:** `lib/features/admin/screens/admin_subscription_payment_review_screen.dart`
- **Why:** Prevent stale/double processing and make the admin review list represent only actionable pending payments.
- **Logic changes:** Query filtered to pending; per-payment processing lock; approval confirmation; guarded payment/subscription updates; rollback to pending if the second update fails; rejection reason required; processing buttons disabled with progress.
- **Database/Supabase changes:** No schema/migration changes.
- **Testing:** User later confirmed the batch is working.
- **Commit:** `dc4dfd13c893d3f71e85c39c60be07e88ad2ba51`
- **Status:** Done and tested.
- **Next:** Owner duplicate subscription submission and failed-step cleanup.

### 2026-09-17 — Created AI handoff document

- **Action:** Created `chat-gpt.md`.
- **Purpose:** Preserve project context so a different ChatGPT session can continue development without relying on the old conversation.
- **Files:** `chat-gpt.md`
- **Code changes:** None.
- **Database changes:** None.
- **Testing:** Not applicable.
- **Commit:** `5bc6457feb926f08efcedcbdffe94d47f4576e3a`
- **Status:** Done.
- **Next:** Add mandatory per-change logging and continue subscription hardening.

### 2026-09-17 — Added mandatory per-change logging rule

- **Action:** Updated `chat-gpt.md` to require that **every project action/change** be documented here.
- **Purpose:** Ensure complete AI continuity across ChatGPT sessions.
- **Files:** `chat-gpt.md`
- **Code changes:** None.
- **Database changes:** None.
- **Testing:** File update committed successfully.
- **Commit:** `353bbd257abf51ae1b909009ffd3469715c1674a`
- **Status:** Done.
- **Next:** Continue with application development and record every action.

---

## 19. CURRENT STOPPING POINT

The Supabase development/test transaction data has been cleaned successfully. The transaction schema remains intact for the future Customer/User side.

The project is now ready for the next architectural step: a protected Developer/Super Admin control layer that can manage platform configuration, branding, maintenance, and controlled backend CRUD without exposing service-role credentials to the Flutter client.

The existing Admin subscription payment hardening is runtime-tested and confirmed working. Owner subscription hardening is implemented but still needs user runtime testing.

**Next exact action:** Inspect the current Flutter repository for Developer/Admin configuration needs and all usage of `delivery_pricing_settings`, then implement the Developer role/control layer and backend authorization before continuing with Customer ordering.

---

## 20. FUTURE HANDOFF RULE

Whenever any project action changes the development state, update this file.

At minimum, update:

- `PROJECT CHANGE LOG`
- `CURRENT STOPPING POINT`
- `IMMEDIATE NEXT TASK` / next-step section
- relevant feature/status section when applicable
- known bugs/issues
- important commit/hash when useful
- latest test result

A new ChatGPT session should read this file **before asking the user to repeat project history**.

This file is the project's **AI continuity / handoff document**.
