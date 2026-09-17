# HALAL Food — ChatGPT Project Handoff

> **Purpose:** This file is the permanent handoff/context document for AI assistants working on this repository.
> Read this file before making project changes. Update it whenever a major feature, architecture decision, bug fix, or development milestone changes.

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

The goal is to build this from the ground up into a production-quality application that can eventually be presented/sold as a working business system.

---

## 2. IMPORTANT DEVELOPMENT RULES / USER PREFERENCES

- Work **step-by-step**. Do not dump a huge unrelated plan when a concrete next task can be completed first.
- The user prefers **actual code changes**, not instructions to manually edit files in Notepad.
- When possible, edit the GitHub repository directly, commit the changes, then tell the user to `git pull` and test.
- Do not make broad unrelated refactors while fixing a specific feature.
- Preserve working functionality unless a change is intentionally required.
- The project should use a `.env` approach for configuration/secrets such as map tokens and authentication-related public configuration.
- Never commit real secrets, service-role keys, passwords, or private credentials to this repository.
- Temporary test/debug functionality must be protected by `kDebugMode` or otherwise prevented from appearing in production builds.
- Before changing an important feature, inspect the current implementation first. Do not assume an older project state is still current.
- After a significant implementation, update this file so another ChatGPT session can continue without needing the entire conversation history.

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

The project has already been refactored away from the default Flutter demo structure.

Important current paths include:

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

The application title is **HALAL Food** and the debug banner is disabled.

---

## 5. CONFIGURATION / ENVIRONMENT

The project uses dotenv/environment configuration.

A previous issue was:

```text
dotenv has not been initialized
```

This was already fixed.

Keep environment-specific configuration out of source control where appropriate. In particular, never put private Supabase service-role credentials or other private secrets into Dart source code or this handoff file.

---

## 6. SUPABASE

Supabase is already connected to the project.

The project uses Supabase for authentication and application data.

Important areas/tables already encountered in the current application include:

- `restaurants`
- `restaurant_subscriptions`
- `subscription_plans`
- `subscription_payments`
- `halal_verifications`

Supabase Storage bucket already used by the owner subscription flow:

```text
subscription-payment-proofs
```

Payment proof paths follow the restaurant/subscription structure used by the current owner screen.

### Security reminder

Do not solve authentication/password problems by directly modifying `auth.users.encrypted_password` unless there is a very specific controlled migration reason. Prefer the Supabase Admin API/service-role workflow for administrative password changes.

---

## 7. AUTHENTICATION / TEMPORARY DEBUG LOGIN

A temporary quick-login/test-login feature was added to reduce repeated manual login/logout during development.

Important:

- It is protected by Flutter `kDebugMode`.
- It must not appear in release/production builds.
- The latest known commit that added/fixed the debug gating was:

```text
f5dac92fe6d20941659634378a951307af0c6ea0
```

The temporary credentials themselves should **not** be documented here. They can be changed in Supabase or the development configuration as needed.

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

The project is moving from the existing Admin/Owner foundation toward:

1. Harden Admin + Owner subscription/payment flow.
2. Finish/test Admin + Owner production behavior.
3. Build the Customer/User side.
4. Connect customer ordering with restaurant/owner and admin workflows.

---

## 9. ADMIN — CURRENT IMPLEMENTATION

### `lib/features/admin/screens/admin_action_center_screen.dart`

Current behavior:

- Uses Supabase.
- Loads pending records from:
  - `halal_verifications` where `status = pending`
  - `subscription_payments` where `status = pending`
- Joins restaurant information.
- Displays action cards for pending admin work.
- Opens:
  - `HalalVerificationScreen` for halal verification.
  - `AdminSubscriptionPaymentReviewScreen` for subscription payment review.
- Uses realtime subscriptions for the relevant tables.
- Displays an all-caught-up state when no pending actions remain.

This confirms that pending subscription payment review is already integrated into the Admin Action Center.

---

## 10. ADMIN SUBSCRIPTION PAYMENT REVIEW

### File

```text
lib/features/admin/screens/admin_subscription_payment_review_screen.dart
```

Current behavior:

- Loads subscription payment records with related:
  - restaurant
  - restaurant subscription
  - subscription plan
- Displays plan, billing cycle, amount, payment method, reference, notes, and payment proof.
- Payment proof is loaded from the `subscription-payment-proofs` Supabase Storage bucket.

### Approval flow currently implemented

For a pending payment, approval currently:

- changes payment status to `paid`
- sets payment dates/billing period information
- changes the related restaurant subscription to `active`
- sets subscription start/current-period/next-billing dates
- clears cancelled/suspended timestamps as appropriate

### Rejection flow currently implemented

For a pending payment, rejection:

- asks the admin for a rejection reason
- changes payment status to `rejected`
- stores the reason in notes
- changes the related subscription to `cancelled`
- sets cancellation information/notes

### Known hardening tasks — NOT YET COMPLETED

These are the next implementation targets:

1. Admin review screen should ideally query only pending payments instead of loading all historical payments.
2. Add protection against double taps / simultaneous approve-reject actions.
3. Before processing, verify that the payment is still pending so a stale screen cannot process an already handled payment.
4. Add a confirmation dialog before approval.
5. Make approve/reject state transitions robust and consistent.
6. Ensure the actual `subscription_id` relationship is used correctly.
7. Consider database-level protection/transactional behavior later if needed.

Do not mark these as complete until they are actually implemented and tested.

---

## 11. OWNER SUBSCRIPTION SUBMISSION

### File

```text
lib/features/owner/screens/owner_subscribe_screen.dart
```

Current behavior:

- Loads active subscription plans.
- Loads linked active payment methods.
- Owner selects monthly or annual billing.
- Owner selects a payment method.
- Owner enters transaction/reference information.
- Owner uploads a payment screenshot/proof.
- A `restaurant_subscriptions` row is created with `pending` status.
- Payment proof is uploaded to:

```text
subscription-payment-proofs
```

- A `subscription_payments` row is created with `pending` status.
- User sees a message that payment was submitted and is pending admin verification.

### Known hardening concern

The current flow creates the subscription row before the proof upload and payment record are fully completed.

If a later upload/insert fails, an orphaned pending subscription can potentially remain.

Possible future solutions:

- cleanup/rollback logic when a later step fails, or
- a Supabase database RPC/transaction-based submission flow.

Do not implement a complicated transaction/RPC blindly. First inspect the current schema and policies.

### Another hardening task

Prevent duplicate/invalid subscription submissions when a restaurant already has an active or pending subscription.

---

## 12. OWNER SUBSCRIPTION MANAGEMENT

### File

```text
lib/features/owner/screens/owner_subscription_management_screen.dart
```

Current behavior:

- Loads restaurant subscriptions ordered newest first.
- Displays current/latest subscription.
- Displays payment history.
- Uses subscription plan lookup information.
- Handles statuses such as:
  - Active
  - Trial
  - Pending Review
  - Past Due
  - Grace Period
  - Suspended
  - Cancelled
  - Expired
  - Approved
  - Rejected
- Pending subscriptions display payment-under-review information.
- Resubmission is currently allowed for cancelled/expired subscriptions.

This screen is part of the existing subscription workflow and should be preserved while hardening the flow.

---

## 13. IMMEDIATE NEXT TASK

**Do not start editing random features yet.**

The immediate next development batch is:

### Admin + Owner subscription workflow hardening

Priority order:

1. Harden Admin payment review.
2. Prevent duplicate/stale approve/reject operations.
3. Improve pending-state handling.
4. Harden owner duplicate subscription submission.
5. Review failed-upload/orphan-subscription behavior.
6. Test the complete Owner → Admin → Owner flow.

After this batch is stable, move toward the Customer/User side.

---

## 14. EXPECTED TEST FLOW

When a new subscription/payment change is made, test approximately this flow:

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

For rejection, also verify that the rejection reason is retained and that the owner can legitimately resubmit according to the intended state rules.

---

## 15. KNOWN PREVIOUS BUILD ISSUE

A Gradle/Kotlin incremental cache problem previously occurred around `shared_preferences_android`, with an error similar to a storage/cache entry being already registered.

This was a development/build-cache issue, not an application feature requirement.

If it returns, inspect/clean the relevant Gradle/Kotlin caches before changing application code.

---

## 16. GIT WORKFLOW

The GitHub repository is connected to the development workflow.

Preferred workflow:

```text
ChatGPT inspects current code
        ↓
ChatGPT makes focused repository changes
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
ChatGPT continues from that exact state
```

Do not tell the user to pull before a new commit exists.

When a batch is ready for testing, explicitly tell the user:

- what was changed
- the commit/hash if useful
- that they can now run `git pull`
- what exact test steps to perform

---

## 17. IMPORTANT CODE-CHANGE PRINCIPLES

- Preserve existing working screens.
- Prefer focused changes over rewrites.
- Do not remove existing functionality just because it could be implemented differently.
- Reuse existing Supabase table names and relationships unless schema changes are intentional.
- Do not invent database columns.
- Before adding database-dependent code, inspect the existing queries/schema/migrations where possible.
- Handle loading, empty, error, and success states.
- Avoid duplicate network calls where practical.
- Prevent multiple submissions from rapid button taps.
- Keep production UI free of debug/test controls.
- Keep secrets out of Git.

---

## 18. CURRENT STOPPING POINT

The user has confirmed that the temporary debug login functionality is working.

The Admin/Owner subscription workflow was audited and found to be substantially implemented already.

**We have NOT yet applied the next hardening batch.**

The last agreed next step is to edit the Admin + Owner subscription workflow for robustness, then have the user pull and test it.

The user explicitly asked to create this `chat-gpt.md` first so future ChatGPT sessions can read it and immediately understand:

- what the project is
- what has already been built
- what is working
- what remains
- where development stopped
- what the next task is

---

## 19. FUTURE HANDOFF RULE

Whenever a major feature is completed or the development stopping point changes, update this file.

At minimum, update:

- `CURRENT STOPPING POINT`
- `DEVELOPMENT STATUS`
- `IMMEDIATE NEXT TASK`
- relevant feature section
- known bugs/issues
- important commit/hash if it materially helps recovery

This file is the project's **AI continuity/handoff document**.

A new ChatGPT session should read this file before asking the user to repeat project history.
