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

This rule applies even when the change is small, such as:

- UI adjustment
- bug fix
- query change
- Supabase change
- auth change
- temporary debug change
- dependency/config change
- file/folder restructuring
- test result
- failed attempt that materially changes our understanding

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

The project uses dotenv/environment configuration.

A previous issue was:

```text
dotenv has not been initialized
```

This was already fixed.

Keep environment-specific configuration out of source control where appropriate. Never put private Supabase service-role credentials or other private secrets into Dart source code or this handoff file.

---

## 6. SUPABASE

Supabase is already connected.

Important areas/tables already encountered:

- `restaurants`
- `restaurant_subscriptions`
- `subscription_plans`
- `subscription_payments`
- `halal_verifications`

Supabase Storage bucket used by the owner subscription flow:

```text
subscription-payment-proofs
```

### Security reminder

Do not solve authentication/password problems by directly modifying `auth.users.encrypted_password` unless there is a very specific controlled migration reason. Prefer the Supabase Admin API/service-role workflow for administrative password changes.

---

## 7. AUTHENTICATION / TEMPORARY DEBUG LOGIN

A temporary quick-login/test-login feature was added to reduce repeated manual login/logout during development.

- Protected by Flutter `kDebugMode`.
- Must not appear in release/production builds.
- Known commit:

```text
f5dac92fe6d20941659634378a951307af0c6ea0
```

Temporary credentials are intentionally **not** documented here.

---

## 8. DEVELOPMENT STATUS — MAJOR MILESTONES

### Phase 1 — Subscription Management

**Status: DONE / working**

Includes CRUD work for subscription management and testing.

### Admin / Owner subscription workflow

A large part is already implemented and working:

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

This workflow is not a blank feature anymore. **Audit and hardening should happen before rebuilding it from scratch.**

### Current overall direction

1. Harden Admin + Owner subscription/payment flow.
2. Finish/test Admin + Owner production behavior.
3. Build the Customer/User side.
4. Connect customer ordering with restaurant/owner and admin workflows.

---

## 9. ADMIN — CURRENT IMPLEMENTATION

### `lib/features/admin/screens/admin_action_center_screen.dart`

Current behavior:

- Loads pending `halal_verifications`.
- Loads pending `subscription_payments`.
- Joins restaurant information.
- Displays action cards.
- Opens halal verification or subscription payment review screens.
- Uses realtime subscriptions for relevant tables.
- Displays an all-caught-up state when no pending actions remain.

Pending subscription payment review is already integrated into the Admin Action Center.

---

## 10. ADMIN SUBSCRIPTION PAYMENT REVIEW

### File

```text
lib/features/admin/screens/admin_subscription_payment_review_screen.dart
```

### Latest hardening completed

The admin payment review screen was hardened in this batch:

- The review query now loads **only `pending` subscription payments** instead of the full payment history.
- Approve/reject actions now have an in-memory processing lock per payment ID to prevent rapid double taps/simultaneous actions in the same screen.
- Approval now requires an explicit confirmation dialog.
- Approval uses the actual `subscription_id` from the payment record, with the joined subscription ID as fallback.
- Approval updates the payment only when it is still `pending` using a guarded update/select.
- Subscription activation is also guarded by `status = pending`.
- If subscription activation fails after payment was marked paid, the payment is returned to `pending` to avoid leaving the workflow falsely completed.
- Rejection now requires a non-empty reason.
- Rejection also uses a guarded `pending` payment update and the actual `subscription_id`.
- If the subscription rejection update fails, the payment is returned to `pending`.
- Loading/empty messaging now explicitly refers to pending payments.
- Processing buttons show a spinner and are disabled while the selected payment is being processed.

### Approval/rejection behavior after hardening

The intended flow remains:

```text
Pending payment
   ↓
Admin confirms action
   ↓
Guarded payment status update
   ↓
Guarded subscription status update
   ↓
Reload pending list
```

This is still application-level consistency protection. A future database-level RPC/transaction can provide stronger atomicity if schema/RLS review supports it.

---

## 11. OWNER SUBSCRIPTION SUBMISSION

### File

```text
lib/features/owner/screens/owner_subscribe_screen.dart
```

Current behavior:

- Loads active subscription plans.
- Loads linked active payment methods.
- Owner selects monthly/annual billing.
- Owner selects payment method.
- Owner enters transaction/reference information.
- Owner uploads payment screenshot/proof.
- Creates `restaurant_subscriptions` with `pending` status.
- Uploads proof to `subscription-payment-proofs`.
- Creates `subscription_payments` with `pending` status.
- Shows that payment is pending admin verification.

### Known hardening concern

The current flow creates the subscription row before proof upload/payment record completion. If a later step fails, an orphan pending subscription can potentially remain.

Possible future solutions:

- cleanup/rollback logic, or
- Supabase database RPC/transaction-based submission.

Do not implement a complicated transaction/RPC blindly. Inspect current schema and policies first.

### Another hardening task

Prevent duplicate/invalid subscription submissions when a restaurant already has an active or pending subscription.

---

## 12. OWNER SUBSCRIPTION MANAGEMENT

### File

```text
lib/features/owner/screens/owner_subscription_management_screen.dart
```

Current behavior:

- Loads restaurant subscriptions newest first.
- Displays current/latest subscription.
- Displays payment history.
- Handles statuses including Active, Trial, Pending Review, Past Due, Grace Period, Suspended, Cancelled, Expired, Approved, and Rejected.
- Pending subscriptions display payment-under-review information.
- Resubmission is currently allowed for cancelled/expired subscriptions.

---

## 13. IMMEDIATE NEXT TASK

The next application batch is now:

### Owner subscription submission hardening

Priority:

1. Prevent a restaurant with an existing `active` or `pending` subscription from opening/submitting another subscription payment.
2. Re-check `active`/`pending` state immediately before creating the new subscription, so stale UI cannot bypass the check.
3. Add cleanup for failed proof upload/payment-record creation where safely possible.
4. Preserve the existing cancelled/expired resubmission behavior.
5. Test complete Owner → Admin → Owner flow after both sides are hardened.

After this batch is stable, move toward the Customer/User side.

---

## 14. EXPECTED TEST FLOW

```text
OWNER
  ↓
Choose plan
  ↓
Choose billing cycle
  ↓
Choose payment method
  ↓
Enter reference number
  ↓
Upload payment proof
  ↓
Submit
  ↓
Verify Pending Review state

ADMIN
  ↓
Open Action Center
  ↓
See pending subscription payment
  ↓
Open review
  ↓
Verify payment details/proof
  ↓
Approve OR Reject

OWNER
  ↓
Refresh/reopen subscription management
  ↓
Verify resulting status
  ↓
Verify payment history
```

For rejection, verify that the rejection reason is retained and that the owner can resubmit according to intended state rules.

Additional hardening tests for the latest admin change:

- Open a pending payment and tap Approve repeatedly: only one processing action should run.
- Open a pending payment and confirm Approve: payment should become paid and subscription active.
- Open a pending payment and reject without a reason: rejection must not proceed.
- Reject with a reason: payment becomes rejected and subscription becomes cancelled.
- Refresh/reopen the review screen: processed records should no longer appear because the screen now queries only pending payments.

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

When a batch is ready for testing, explicitly tell the user:

- what changed
- commit/hash if useful
- that they can now run `git pull`
- exact test steps

---

## 17. IMPORTANT CODE-CHANGE PRINCIPLES

- Preserve existing working screens.
- Prefer focused changes over rewrites.
- Do not remove existing functionality without a reason.
- Reuse existing Supabase tables/relationships unless schema changes are intentional.
- Do not invent database columns.
- Inspect existing queries/schema/migrations where possible before database-dependent changes.
- Handle loading, empty, error, and success states.
- Prevent duplicate submissions from rapid button taps.
- Keep production UI free of debug/test controls.
- Keep secrets out of Git.

---

# 18. PROJECT CHANGE LOG

> **Mandatory:** Add a new entry here for **every development change/action**. Never erase previous entries. Newest entries go at the top.

### 2026-09-17 — Admin subscription payment hardening runtime test PASSED

- **Action:** Recorded the user's runtime test result for the Admin subscription payment hardening batch.
- **Files:** `chat-gpt.md` only for this documentation action.
- **Why:** The user confirmed the updated Admin payment review workflow is working in the local app.
- **Testing performed by user:** Tested the hardened Admin subscription payment review flow after pulling commit `dc4dfd13c893d3f71e85c39c60be07e88ad2ba51`.
- **Test result:** **WORKING / PASSED** according to the user's report.
- **Verified behavior reported:** Admin payment review hardening is functioning as expected. The exact individual test cases were not separately reported, so do not infer additional cases beyond the user's confirmation.
- **Database/Supabase changes:** None during this documentation update.
- **Commit:** This documentation update.
- **Status:** Admin hardening batch is runtime-tested and confirmed working.
- **Next:** Proceed to Owner duplicate-submission and failed-step/orphan-subscription hardening.

### 2026-09-17 — Hardened Admin subscription payment review

- **Action:** Updated `admin_subscription_payment_review_screen.dart` to harden payment approval/rejection handling.
- **Files:** `lib/features/admin/screens/admin_subscription_payment_review_screen.dart`
- **Why:** Prevent stale/double processing and make the admin review list represent only actionable pending payments.
- **Logic changes:**
  - Query filtered to `status = pending`.
  - Per-payment processing lock added.
  - Approval confirmation dialog added.
  - Guarded payment update using `status = pending`.
  - Guarded subscription activation using `status = pending`.
  - Actual payment `subscription_id` is used first.
  - Payment is restored to pending if the following subscription update fails.
  - Rejection requires a reason and is guarded against stale processing.
  - Payment is restored to pending if subscription rejection fails.
  - Processing buttons are disabled and show progress.
- **Database/Supabase changes:** No schema/migration changes.
- **Testing:** User later confirmed the batch is working.
- **Test result:** PASSED in user's local runtime test.
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
- **Next:** Add the mandatory per-change logging rule and continue with subscription hardening.

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

The first Admin subscription payment hardening batch has been **runtime-tested by the user and confirmed working**.

The Admin review screen now focuses on pending payments and protects approve/reject operations against common stale/double-tap cases at the application level.

The next code change is Owner subscription submission hardening.

**Current exact next step:** Inspect the current Owner subscription submission code/schema/policies, then implement duplicate active/pending protection and safe failed-step cleanup. Update this file, commit, tell the user to `git pull`, and test the Owner flow.

---

## 20. FUTURE HANDOFF RULE

Whenever any project action changes the development state, update this file.

At minimum, update:

- `PROJECT CHANGE LOG`
- `CURRENT STOPPING POINT`
- `IMMEDIATE NEXT TASK`
- relevant feature/status section when applicable
- known bugs/issues
- important commit/hash when useful
- latest test result

A new ChatGPT session should read this file **before asking the user to repeat project history**.

This file is the project's **AI continuity / handoff document**.
