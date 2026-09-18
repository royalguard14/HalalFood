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

```
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

Temporary quick-login/debug login exists to reduce repeated login/logout. It is protected by `kDebugMode` or the explicit opt-in `HALAL_TEST_LOGIN` build define; credentials are intentionally not documented here.

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

### Current development direction
Developer control work and core Admin/Owner workflows have been established. The next focus is **final Admin-side tasks and Customer-side audit/testing** before expanding Customer ordering or starting broader backend/security work.

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

### Admin remaining work
Admin is **not being treated as completely finished yet**. There are still Admin-side checks/features to inspect and test before finalizing the Admin milestone. Do not skip back to Developer work unless specifically requested.

---

## 11. OWNER SUBSCRIPTION SUBMISSION

`lib/features/owner/screens/owner_subscribe_screen.dart` was hardened against duplicate submissions and orphan pending subscriptions.

Migration: `supabase/owner_subscription_submission_hardening.sql`.

Partial unique index prevents multiple pending subscriptions per restaurant; owner-only rollback policies were added.

Core Owner subscription flow has now been tested through the current Owner audit.

---

## 12. OWNER CURRENT TEST STATUS

The following Owner-side tests have been reported by the user as **GOODS / PASSED**:

### Test 1 — Owner Subscription
- Owner login/routing
- Owner restaurant selection
- Owner dashboard
- Subscription status/plan/expiry
- Submit subscription/payment
- Pending state

### Test 2 — Admin receives Owner request
- Logout Owner
- Login Admin
- Action Center
- Find subscription request
- Review restaurant/owner/plan/amount/payment information
- Approve

### Test 3 — Owner after approval
- Owner Dashboard
- Subscription status
- Plan
- Expiry
- Restaurant Status
- Menu
- Orders

### Test 4 — Order lifecycle
- Customer creates order
- Owner receives/sees order
- Order status: Pending → Preparing → Ready

**Conclusion for current milestone:** Owner core workflow is considered **working based on the tests above**. This does not mean every edge case or every Owner feature is permanently closed.

---

## 13. CUSTOMER AUDIT / TEST PLAN

Customer-side testing is now the next major active workstream.

### TEST C1 — Customer Profile & Account
1. Login as Customer.
2. Open Profile/Account.
3. Verify account information.
4. Logout and login again.
5. Verify role-based routing returns to Customer Home.

### TEST C2 — Customer Addresses
1. Add Address.
2. Verify Latitude/Longitude and current-location capture.
3. Edit Address.
4. Verify saved Lat/Lng are displayed.
5. Use **Update Current Location**.
6. Save.
7. Reopen and verify coordinates persist.
8. Test Delete Address.
9. Test Set Default Address.

### TEST C3 — Restaurant Discovery
1. Customer Home.
2. Restaurant list.
3. Search/filter/category.
4. Restaurant details.
5. Menu display.

### TEST C4 — Cart
1. Add item.
2. Increase/decrease quantity.
3. Remove item.
4. Verify cart total.
5. Verify delivery fee.

### TEST C5 — Checkout
1. Address selection.
2. GPS coordinates.
3. Delivery fee.
4. Payment method.
5. Order summary.
6. Place Order.

### TEST C6 — Orders
1. Pending.
2. Preparing.
3. Ready.
4. Order details.
5. Order history.

### TEST C7 — Realtime / status behavior
1. Owner changes order status.
2. Customer observes the updated status.

### TEST C8 — Edge cases
- Empty cart.
- No address.
- Restaurant unavailable.
- Expired subscription.
- Invalid/out-of-range delivery location.
- Failed order/payment scenarios.

**Workflow rule:** Run **one Customer test at a time**. User reports `goods` or the exact error/screenshot before moving to the next test.

**Immediate Customer task:** Start with **TEST C1 — Customer Profile & Account**.

---

## 14. CUSTOMER ADDRESS GPS FIX

### 2026-09-18 — Fixed Customer Edit Address GPS controls

- **User finding:** Customer **Add Address** already showed Latitude/Longitude and a GPS capture control, but **Edit Address** did not expose the location controls.
- **File changed:** `lib/features/address/screens/edit_address_screen.dart`
- **Fix:** Added the same Geolocator-based location capture flow to Edit Address. Existing latitude/longitude are loaded from the address model and displayed. The user can tap **Update Current Location** to capture new GPS coordinates.
- **Save behavior:** Edit Address now passes the current `_latitude` and `_longitude` values to `AddressRepository.updateAddress()`, so changed coordinates are persisted to `user_addresses`.
- **Existing behavior preserved:** Address text fields, default-address handling, validation and save flow remain unchanged.
- **Supabase/database changes:** None; the existing `latitude` and `longitude` columns and repository update support were already present.
- **Testing:** Code fix pushed to GitHub. Runtime verification remains part of TEST C2.
- **Commit:** `33a727d8efa3607c51c9c7b5d8cfc757503be0ff`
- **Documentation commit:** `26bf4ce4b2923e18dbe44cc902196e30ae941b25`

---

## 15. DATABASE CLEANUP

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

## 16. DEVELOPER ARCHITECTURE

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

## 17. DEVELOPER RESTAURANT CONTROL

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

## 18. DEVELOPER DASHBOARD MODULES

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

## 19. GLOBAL BRANDING / THEME

Global-only branding is implemented and the user confirmed it is **OK / working**.

Architecture:

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

Features:
- Manual HEX editing.
- Visual Pick Color HSV picker.
- Generate from Primary.
- Generate Entire Palette.
- Live Preview.
- Save Global Branding.
- Material 3 theme propagation across common widgets.

Latest branding generator commit: `be1a5ca29452995570040b0310bd22331e89f4a5`

No Supabase schema change was required.

---

## 20. DRIVER / DELIVERY

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

## 21. SECURITY AUDIT OPEN ITEMS

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

**Important sequencing update:** Backend/security hardening remains an important milestone, but it is **not the immediate task while Admin and Customer audit work is still being completed**. Return to this section after the current Admin/Customer workstream unless a security issue blocks the current task.

---

## 22. BASELINE MIGRATION DIRECTION

Eventually create clean baseline migrations capable of provisioning a fresh HALAL Food Supabase database with schema, indexes/FKs, enums/functions/triggers, RLS, storage policies/buckets, seed/reference data and Developer bootstrap configuration.

Never commit Developer passwords.

---

## 23. EXPECTED TEST FLOW

```text
DEVELOPER → Developer Control Panel → module → controlled operation → server authorization → result
ADMIN     → Operational Admin console → verify remaining Admin features/workflows
OWNER     → Restaurant/subscription workflows → core tests PASSED
CUSTOMER  → Profile → Address → Discovery → Cart → Checkout → Orders → Realtime → Edge cases
DRIVER    → Driver Dashboard → future delivery/map/earnings
```

Destructive tests must verify confirmation UI, Developer-only backend authorization, non-Developer rejection, intended related-row deletion, preservation of unrelated data, and Storage cleanup once implemented.

---

## 24. GIT WORKFLOW

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

## 25. IMPORTANT CODE PRINCIPLES

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

# 26. PROJECT CHANGE LOG

### 2026-09-18 — Allowed Developer to view KYC images

- **User requirement:** Developer may view Customer, Rider/Driver and Restaurant Owner identity-verification images, but Developer must **not** approve or reject them.
- **Supabase change:** Updated the private `identity-verifications` Storage SELECT policy so authenticated **Admin or Developer** accounts can view identity files. User upload/delete ownership rules remain unchanged.
- **Approval authority:** The Admin Identity Verification screen remains the operational review/approval path. No Developer approval action was added.
- **Privacy:** The bucket remains private; access is controlled by Storage RLS rather than public URLs.
- **Migration:** `developer_identity_storage_view_access`
- **Testing:** Migration applied successfully. Runtime Developer image-view test remains pending.
- **Current stopping point:** Developer has backend permission to view private KYC images; Admin remains the only intended approver.
- **Next task:** Continue KYC upload test with a test Customer account, then verify Admin review and Developer image viewing.


### 2026-09-18 — Fixed Login → Splash → Identity Verification routing

- **User test finding:** After Login, the app was going directly to the role dashboard/home. The expected flow **Login → Splash → Identity Verification** did not appear.
- **Root cause:** `lib/features/auth/screens/login_screen.dart` was performing its own role lookup and navigating directly to the role destination after successful authentication. This bypassed `SplashScreen`, where the identity-verification gate is implemented.
- **File changed:** `lib/features/auth/screens/login_screen.dart`
- **Fix:** After successful authentication, Login now navigates to `SplashScreen`. Splash remains the single centralized startup router and performs the identity-verification check before Customer, Driver and Restaurant Owner accounts enter the protected app.
- **Behavior:** Admin and Developer still route to their normal dashboards through Splash; unverified Customer/Driver/Restaurant Owner accounts now reach the Identity Verification screen through the same startup path.
- **Supabase changes:** None.
- **Testing:** User reported the expected verification screen did not appear. Code fix is now committed; runtime retest is required.
- **Commit:** `7e791356f5bb2e342a083bd0f190dabda3bd766b`
- **Current stopping point:** Login routing now passes through Splash. Runtime verification has not yet been confirmed.
- **Next task:** `git pull`, log in with a test Customer account, and verify **Login → Splash → Identity Verification**. Do not upload real government ID/selfie documents during development testing.


### 2026-09-18 — Added logout control to required identity-verification screen

- **File changed:** `lib/features/identity/screens/identity_verification_screen.dart`
- **Reason:** An unverified user is intentionally prevented from backing out into the protected app, so the verification screen now provides an explicit Logout action.
- **Behavior:** Logout signs out through Supabase Auth and returns to Login. The control is disabled while a verification submission is in progress.
- **Supabase changes:** None.
- **Testing:** Not runtime-tested yet.
- **Commit:** `7e21f9fddc35fabe29f989a104a0709b5afd150e`
- **Current stopping point:** Identity verification implementation is ready for runtime testing.
- **Next task:** `git pull`, test Customer verification submission/status first, then Admin review/approve/reject, then Driver and Restaurant Owner.


### 2026-09-18 — Implemented Identity Verification / KYC foundation

- **User requirement:** Customer, Rider/Driver and Restaurant Owner accounts must submit a valid government ID plus a selfie holding the same ID before using the protected app. Admin reviews the submission and can approve/reject it. Rejected users can resubmit after correcting the requirements.
- **Existing implementation inspected:** The existing `halal_verifications` table is for restaurant halal classification/certification and is separate from personal identity verification. No existing personal KYC/identity-verification implementation was found in the Flutter repository.
- **New database:** Added `public.identity_verifications` with role, ID type, private Storage paths, status (pending/approved/rejected), rejection reason, reviewer, review timestamp and submission/update timestamps. Added indexes and one-pending-submission-per-user protection.
- **Backend authorization:** Added `public.is_identity_verified()` as a security-definer helper with pinned `search_path`. It treats Admin/Developer as internally trusted and requires an approved verification matching the user's current role for Customer, Driver and Restaurant Owner.
- **Backend enforcement:** Customer order creation and Restaurant Owner restaurant creation/update now require `is_identity_verified()`; client-side routing is not the only protection.
- **Private storage:** Added private Supabase Storage bucket `identity-verifications`. Users can upload/view/delete only inside their own user folder; Admin can view verification files. Documents are not public URLs. Admin uses short-lived signed URLs for review.
- **New Customer/Owner/Driver screen:** `lib/features/identity/screens/identity_verification_screen.dart`. It collects a government ID photo and a camera selfie with the same ID, uploads both privately, submits a pending record, shows pending/approved/rejected state and allows resubmission after rejection.
- **New Admin screen:** `lib/features/admin/screens/identity_verification_management_screen.dart`. Admin can filter Pending/Approved/Rejected, review account/role/ID type, view the ID and selfie through temporary signed URLs, then Approve or Reject with a reason.
- **Admin navigation:** Added Identity Verification under Admin → Users & Accounts.
- **Startup routing:** `lib/features/splash/splash_screen.dart` now checks identity verification after role resolution and routes unverified Customer/Driver/Restaurant Owner accounts to the verification screen. Admin/Developer routing remains unchanged.
- **Important privacy rule:** Real government IDs/selfies must not be placed in GitHub or public storage. Development tests should use test documents/accounts only.
- **Supabase changes:** Migration applied directly to project `taltqnxhivpfwjqlvxnt` using migration name `identity_verification_kyc_foundation`.
- **Testing:** Database migration succeeded. GitHub code changes were committed. Flutter runtime verification is still pending; do not mark the KYC flow as fully tested until the user runs it.
- **GitHub commits:** identity screen + admin screen created; startup routing commit `2904a47b1a4b0d82395e6b37d87e5d2bbd24acce`; Admin navigation commit `4a57646b08fed06a911c0e39819d184cc6eaf909`.
- **Current stopping point:** KYC foundation is implemented in Supabase and GitHub, but runtime testing has not yet been performed.
- **Next task:** User should `git pull`, run the app, and test the identity-verification route using a test Customer account first. Then test Admin review. After that, test Driver and Restaurant Owner flows.


### 2026-09-18 — Updated handoff guide for remaining Admin + Customer work

- **User clarification:** Owner core testing is already working, but there are still items to do on the **Admin side** and **Customer side**. The Customer test sequence must therefore remain documented for the next session/work block.
- **Documentation updated:** `chat-gpt.md`
- **Added/updated:** Owner current test status, remaining Admin work note, full Customer audit sequence C1–C8, Customer address GPS verification, and current sequencing note.
- **Customer test order:** C1 Profile & Account → C2 Addresses → C3 Restaurant Discovery → C4 Cart → C5 Checkout → C6 Orders → C7 Realtime → C8 Edge Cases.
- **Workflow:** Continue one test at a time and wait for the user's result before advancing.
- **Immediate Customer task:** TEST C1 — Customer Profile & Account.
- **Admin note:** Admin is not marked 100% complete yet; remaining Admin features/checks must be identified and tested before closing the Admin milestone.
- **Backend/security note:** Security hardening remains important but is temporarily sequenced after the current Admin + Customer workstream unless a blocking issue appears.
- **Supabase/database changes:** None.
- **Testing:** Documentation-only update; no Flutter runtime/analyzer test performed.
- **Current stopping point:** Owner core flow passed Tests 1–4; Customer audit is queued; Admin still has remaining work.
- **Next task:** Continue with the remaining Admin-side work as needed, then start Customer TEST C1.

### 2026-09-18 — Fixed Customer Edit Address GPS controls

- **User finding:** Customer **Add Address** already showed Latitude/Longitude and a GPS capture control, but **Edit Address** did not expose the location controls.
- **File changed:** `lib/features/address/screens/edit_address_screen.dart`
- **Fix:** Added the same Geolocator-based location capture flow to Edit Address. Existing latitude/longitude are loaded from the address model and displayed. The user can tap **Update Current Location** to capture new GPS coordinates.
- **Save behavior:** Edit Address now passes the current `_latitude` and `_longitude` values to `AddressRepository.updateAddress()`, so changed coordinates are persisted to `user_addresses`.
- **Supabase/database changes:** None.
- **Commit:** `33a727d8efa3607c51c9c7b5d8cfc757503be0ff`
- **Documentation commit before this entry:** `26bf4ce4b2923e18dbe44cc902196e30ae941b25`
- **Current stopping point:** Customer Edit Address now has GPS controls; runtime verification belongs to TEST C2.

### 2026-09-18 — Developer Branding / palette milestone confirmed working

- User confirmed the latest Developer Branding/palette work is **OK / working**.
- Manual HEX editing, Pick Color, Generate from Primary, Generate Entire Palette, Live Preview and Save Global Branding are considered working.
- Latest implementation commit: `be1a5ca29452995570040b0310bd22331e89f4a5`.
- No Supabase schema change was required.
- The next major area was previously planned as Backend & Security Hardening; this has now been temporarily sequenced after remaining Admin + Customer work.

### 2026-09-18 — Owner core audit Tests 1–4 passed

- **Test 1:** Owner subscription flow — **GOODS**.
- **Test 2:** Admin receives and approves Owner subscription request — **GOODS**.
- **Test 3:** Owner after approval — status/plan/expiry/restaurant/menu/orders — **GOODS**.
- **Test 4:** Customer creates order and Owner receives it; order moves Pending → Preparing → Ready — **GOODS**.
- **Current interpretation:** Owner core operational workflow is working for the tested path.
- **Next:** Remaining Admin checks and Customer audit/testing.

---

# 27. CURRENT STOPPING POINT

## Owner
Core tested workflow is **working / PASSED** through Tests 1–4.

## Admin
**Not yet marked 100% complete.** Some Admin-side features/checks remain to be identified and tested.

## Customer
Customer audit is the active workstream.

### Immediate Customer test
**KYC routing verification comes first:** verify **Login → Splash → Identity Verification** with a test Customer account. After that is confirmed, resume **TEST C1 — Customer Profile & Account**.

After C1, continue:
**C2 Addresses → C3 Restaurant Discovery → C4 Cart → C5 Checkout → C6 Orders → C7 Realtime → C8 Edge Cases**

## Backend / Security
Important but temporarily queued until Admin + Customer work is sufficiently complete, unless a blocking security issue is found.

---

# 28. FUTURE HANDOFF RULE

Whenever any project action changes the development state, update this file, including:
- PROJECT CHANGE LOG
- CURRENT STOPPING POINT
- NEXT MILESTONE / IMMEDIATE NEXT TASK
- relevant feature/status section
- known bugs/issues
- important commit/hash
- latest test result

A new ChatGPT session should read this file before asking the user to repeat project history.

This file is the project's **AI continuity / handoff document**.
