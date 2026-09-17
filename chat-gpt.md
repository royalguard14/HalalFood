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

Current behavior:

- Loads subscription payment records with related restaurant, subscription, and plan data.
- Displays plan, billing cycle, amount, payment method, reference, notes, and payment proof.
- Payment proof uses the `subscription-payment-proofs` bucket.

### Approval flow currently implemented

For a pending payment:

- payment → `paid`
- payment dates/billing period updated
- restaurant subscription → `active`
- subscription start/current-period/next-billing dates updated
- cancelled/suspended timestamps cleared as appropriate

### Rejection flow currently implemented

For a pending payment:

- admin enters rejection reason
- payment → `rejected`
- reason stored in notes
- subscription → `cancelled`
- cancellation information/notes updated

### Known hardening tasks — NOT YET COMPLETED

1. Query only pending payments in the admin review screen.
2. Protect against double taps/simultaneous approve-reject actions.
3. Verify payment is still pending before processing.
4. Add approval confirmation dialog.
5. Make state transitions robust and consistent.
6. Ensure actual `subscription_id` relationship is used correctly.
7. Consider database-level transactional protection later if needed.

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

**Do not start editing random features yet.**

The immediate next development batch is:

### Admin + Owner subscription workflow hardening

Priority:

1. Harden Admin payment review.
2. Prevent duplicate/stale approve/reject operations.
3. Improve pending-state handling.
4. Harden owner duplicate subscription submission.
5. Review failed-upload/orphan-subscription behavior.
6. Test complete Owner → Admin → Owner flow.

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
- **Commit:** This update.
- **Status:** Done.
- **Next:** No application code changes yet. Next application task remains Admin + Owner subscription workflow hardening.

---

## 19. CURRENT STOPPING POINT

The temporary debug login functionality is confirmed working.

The Admin/Owner subscription workflow was audited and found to be substantially implemented already.

The next hardening batch has **NOT yet been applied**.

The user requested that `chat-gpt.md` be the permanent continuity document and specifically requires that **every project action/change be recorded in it**.

**Current exact next step:** Harden the Admin + Owner subscription workflow, then commit, update this log, tell the user to `git pull`, and have the user test.

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
