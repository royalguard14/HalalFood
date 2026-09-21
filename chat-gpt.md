
### 2026-09-21 — Aligned Customer Pickup Payment Summary
- Customer Order Details Pickup summary now shows only **Subtotal**, **Downpayment**, **Cash for Pickup**, and **Balance**.
- Pickup Subtotal uses the full order amount before payment deductions.
- Removed the redundant Pickup **Total** row and renamed the cash line to **Cash for Pickup**.
- Delivery Order Summary remains unchanged.
- File changed: `lib/features/order/screens/order_details_screen.dart`
- Commit: 0c8c2b1d113fa3ba5d92550bdd7fc2fb3b952a7a

### 2026-09-21 — Removed Total Paid from Owner Pickup Summary
- Owner Pickup payment summary now shows only **Subtotal**, **GCash Downpayment**, **Cash for Pickup**, and **Balance**.
- Removed the redundant **Total Paid** row as requested.
- Delivery order summary remains unchanged.
- File changed: `lib/features/owner/screens/owner_order_details_screen.dart`
- Commit: f22549c2adfe680acf45d64ce4b97310dc171ff8
### 2026-09-21 — Fixed Pickup final payment exact-balance UX + Customer/Owner summaries

- **User requirement:** For Pickup final payment, the customer must pay the remaining balance exactly. Underpayment and overpayment must be rejected; only the exact balance is accepted.
- **Backend fix:** Updated live `public.record_owner_pickup_payment()` final-payment validation to compare `p_amount` directly against the calculated remaining balance and reject anything that is not exact within the existing 0.005 tolerance. Error is now a clear message: **Payment must be exactly the remaining balance of ₱X.**
- **Owner final-payment dialog:** Now pre-fills the exact remaining balance, displays the exact amount required, blocks mismatched amounts before submitting, and no longer shows the raw `PostgrestException(...)` wrapper in the SnackBar.
- **Customer Order Details:** Pickup tracking now uses `orders.payment_status = paid` to highlight **Full Payment** at the Ready-to-Pick-Up stage, before **Claimed**. Claimed remains the terminal step.
- **Pickup Order Summary:** Delivery Fee is removed. Summary now shows **Subtotal → Downpayment → Cash Payment (Balance) → Total**.
- **Owner Order Details Summary:** Same Pickup-specific breakdown; Delivery orders keep the Delivery Fee line.
- **Files changed:** `lib/features/order/screens/order_details_screen.dart`, `lib/features/owner/screens/owner_order_details_screen.dart`, `supabase/owner_pickup_payment_and_gcash_vault.sql`.
- **GitHub commits:** Customer Order Details `e435f3f9564138cc1d7fe0f5c92b7311bdb6e86e`; Owner Order Details `e6fe45f3a5938600fda0e86828f26bece6073f40` then summary `15257b3ba7724bfaa792fd0877eb54bd779db1b2`; SQL documentation `5b12499aa36c059d47645c0c57badd55632e50d0`.
- **Supabase:** Live function updated by migration `fix_pickup_final_payment_exact_balance_message`; verified with `pg_get_functiondef`.
- **Testing status:** Code/backend changes are not runtime-tested yet.
- **Next exact test:** `git pull` → use a fresh Pickup order → complete downpayment and move it to **Ready to Pick Up** → verify Customer Order Details highlights **Ready to Pick Up** before final payment → Owner opens **Full Payment**, verify the dialog shows the exact remaining balance → test wrong amount (under/over) is blocked with the friendly exact-balance message → enter exact amount and confirm **Full Payment** becomes highlighted on Customer and Owner dashboard, while **Claimed** remains the next action.

### 2026-09-21 — Fixed Pickup payment text/enum type mismatch

- **User-reported error:** Owner Pickup → Confirm GCash Downpayment failed with PostgreSQL `42883`: `operator does not exist: text = public.payment_status`.
- **Root cause:** Live schema verification showed `public.payments.status` and `public.payments.payment_method` are **text**, while `public.orders.payment_status` is the `public.payment_status` enum. The previous fix incorrectly cast values used against the `payments` text columns to enums, causing the comparison operator error.
- **Supabase fix:** Updated live `public.record_owner_pickup_payment()` so comparisons/assignments against `public.payments.status` and `public.payments.payment_method` use text values. Explicit `public.payment_status` casts remain where assigning the enum-valued `orders.payment_status` column.
- **Verification:** Re-read the live function after replacement and confirmed payment-table comparisons use text values while order payment status assignments still use the enum casts.
- **GitHub SQL documentation:** `supabase/owner_pickup_payment_and_gcash_vault.sql` updated to match the live function.
- **Testing:** Not runtime-tested after this backend fix.
- **Next exact test:** **No git pull is required for this backend-only fix.** Repeat **Owner Pickup → Confirm GCash Downpayment → enter Amount Received + Reference Number → Accept Payment**. Report **goods** or the exact new error before we make another edit.

### 2026-09-21 — Hardened Pickup status enum mapping

- **User-reported error:** Owner Pickup status update failed with PostgreSQL 22P02: invalid enum value ready_to_pick_up'.
- **Verified live Supabase enum:** order_status supports only pending, confirmed, preparing, ready, out_for_delivery, delivered, cancelled, and refunded.
- **Fix:** lib/features/owner/screens/owner_order_details_screen.dart now normalizes the status string before any database update by trimming whitespace and removing stray apostrophes. Pickup UI-only ready_to_pick_up is then mapped to the real database value ready; claimed remains mapped to delivered.
- **Reason:** A stale/malformed UI value such as ready_to_pick_up' must never reach the PostgreSQL enum.
- **Supabase schema:** No database enum change was made.
- **Commit:** cdebeca3924b491ddbe383257e3939e29b8927af.
- **Testing status:** Not runtime-tested yet.
- **Next exact test:** git pull → open the Pickup order → Preparing → press Ready to Pick Up → verify it updates successfully to Ready to Pick Up with no PostgREST enum error. Stop there and report the result.

### 2026-09-21 — Pickup realtime + payment corrections

- Fixed **Owner Dashboard realtime order updates**: new/submitted restaurant orders now trigger an automatic dashboard reload; no manual refresh should be required.
- Fixed **Customer Orders tile realtime updates**: changes to the customer's orders, including pickup receipt submission/status changes, trigger an automatic list reload.
- Final Pickup payment is now **Cash only**. Removed the GCash choice from the Owner Full Payment dialog and the database RPC rejects non-cash final payments.
- Final cash payment uses the existing database-supported payment method value **cash_on_delivery** instead of invalid `cash`, fixing the `payments_method_check` error.
- Pickup downpayment acceptance now allows the Owner to record **any amount above 0 up to 100% of the order total**, rather than forcing exactly the configured 50% amount.
- If the Owner records **100% of the order total** as the initial GCash downpayment, the order is immediately marked fully paid; the later Ready to Pick Up step can proceed directly to Claimed without another payment.
- The actual accepted downpayment amount and percentage are saved back to the same order. Final payment remains linked to the same `order_id`, and under/over-payment validation remains enforced.
- Live Supabase function `record_owner_pickup_payment` updated and repo SQL documentation updated.
- Commits: Owner details `b715849055424b91e757df889220910a69fe0387`; Owner realtime `a6726cd600a44e545c0ef8f75224ea719ae57996`; Customer realtime `ac9e74414a319a7d9e152f2bc7425f6a7b1a5b8d`; SQL `1b3283472f75be365ce3e61b79391b1ee8080426`.
- **Testing status:** not runtime-tested after these edits.
- **Next exact test:** `git pull` → create one fresh Pickup order → submit receipt → verify Customer Orders tile updates without refresh AND Owner Dashboard shows the submitted order without refresh. Then Owner Accept → enter an amount up to the full order total + reference → verify status becomes Confirmed and Preparing button appears. For final payment, verify dialog shows **Cash only**, then enter exactly the remaining balance and confirm it succeeds.

### 2026-09-21 — Pickup payment recording + Owner GCash Vault

- **User-required Pickup flow:** **For Confirmation → Accept → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**.
- **Initial downpayment:** Owner must not auto-start Preparing when accepting the receipt. After Accept, Owner records the actual GCash downpayment **Amount Received** and **Reference Number**. Date/time is recorded automatically. The order then becomes **Confirmed**.
- **Final payment:** At **Ready to Pick Up**, Owner records the customer's remaining payment. The form records **Amount Received** and lets Owner choose **Cash or GCash**; there is **no Reference Number** for this second payment. Date/time is automatic.
- **Payment integrity:** Both payments are stored against the same order_id. The database validates that the final paid total equals the order bill exactly. Underpayment and overpayment block the transition to full payment/Claimed.
- **Database:** Added payments.paid_at, owner_gcash_cashouts, Owner-only payment visibility, atomic record_owner_pickup_payment(...), and record_owner_gcash_cashout(...) with owner authorization and balance validation.
- **Owner GCash Vault:** Added **GCash Vault** to Owner Dashboard. It shows GCash received, cashouts, available balance, and recorded cashout history. Cashouts reduce the available balance but remain permanently recorded.
- **Files changed:** lib/features/owner/screens/owner_order_details_screen.dart, lib/features/owner/screens/owner_dashboard_screen.dart, lib/features/owner/screens/owner_gcash_vault_screen.dart, supabase/owner_pickup_payment_and_gcash_vault.sql.
- **Commits:** Owner Order Details 3c302756bb74e8e8f4bde0834ac17a773035c627; GCash Vault d292bda89fb1f2dc3187e85acb97534d73fb978e; Owner Dashboard 2fb2d89c501f176d66091cc30f9ea6880661f890; SQL documentation 64f46d6dcd5c1d638f7698370cd1f6295d65d630.
- **Test data reset:** orders=0, order_items=0, payments=0, promo_redemptions=0, owner_gcash_cashouts=0.
- **Storage note:** Existing payment-receipts objects were inspected before the reset. Supabase requires deleting Storage files through the Storage API, not direct SQL; the available database tool cannot safely perform physical Storage deletion. Do not delete storage.objects rows directly because that can orphan the underlying files. Physical receipt-object cleanup remains a separate Storage API operation.
- **Testing status:** Not runtime-tested after this edit.
- **Next exact test:** git pull → create one fresh Pickup order → Owner opens **For Confirmation** → press **Accept** → enter the required downpayment amount and reference → verify the order becomes **Confirmed** and the next button is **Preparing**, not Preparing automatically. Do only this first test and report the result before the next edit.

### 2026-09-21 — Fixed Pickup final-payment gate before Claimed

- **User finding:** After Owner accepted the Pickup downpayment receipt, the order correctly moved to **Preparing** and then **Ready to Pick Up**, but the Owner could see **Claimed** immediately instead of requiring the remaining **Full Payment** first.
- **Root cause:** Accepting the initial downpayment was incorrectly setting `orders.payment_status = 'paid'`. The Owner screen uses `payment_status = paid` to determine whether the final Pickup payment has already been completed, so the downpayment was being mistaken for full payment.
- **Fix:** Accepting the initial Pickup downpayment now only:
  - marks `pickup_downpayment_status = paid`
  - moves the order to `preparing`
  - does **not** mark `orders.payment_status = paid`
- **Final Pickup payment:** When the order reaches **Ready to Pick Up**, the Owner must first press **Full Payment**. Only then is `orders.payment_status = paid`, after which the next action becomes **Claimed**.
- **Wording:** Changed the Owner action from **Payment Complete** to **Full Payment** to match the agreed lifecycle.
- **Pickup lifecycle:** **For Confirmation → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**.
- **File changed:** `lib/features/owner/screens/owner_order_details_screen.dart`
- **Commit:** `b383f308809c6b6a5433c6f45bcc612f1af867e6`
- **Testing status:** Not runtime-tested yet.
- **Next exact test:** `git pull` → use the current Pickup order if it is still at **Ready to Pick Up**. Verify the Owner action is **Full Payment**, not **Claimed**. Press **Full Payment** once; only after that should **Claimed** appear.

### 2026-09-21 — Fixed Owner Pickup first-step wording to For Confirmation

- **User finding:** On **Owner Dashboard → Recent Orders**, a Pickup order whose GCash downpayment receipt has already been uploaded for Owner review was still labeled **Order Placed**.
- **Required Owner-side meaning:** At this point the order is already submitted and is waiting for the Owner to review/confirm the downpayment receipt, so the Owner-facing step should be **For Confirmation**.
- **Fix:** Pickup Recent Order tiles now use **For Confirmation → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**. Delivery tracking remains unchanged.
- **Customer-side tracking:** No change; Customer can continue seeing **Order Placed** for the initial lifecycle step.
- **File changed:** `lib/features/owner/screens/owner_dashboard_screen.dart`
- **Commit:** `0fc0f2b06d7643f14421bc0b619640d55d23523f`
- **Testing status:** Not runtime-tested yet.
- **Next exact test:** `git pull` → create/use a Pickup order with the downpayment receipt submitted → Owner Dashboard → Recent Orders → verify the first highlighted step says **For Confirmation**, not **Order Placed**.

### 2026-09-21 — Differentiated Owner Recent Orders completed tiles

- **User request:** Owner Dashboard → Recent Orders should visually distinguish new/active orders from completed orders; they should no longer look identical.
- **Fix:** Completed/terminal tiles now use a softer neutral appearance, reduced elevation, neutral border/icon/progress color, a **COMPLETED** badge, and a check-circle icon. Active/new tiles retain the green actionable styling.
- **Actions:** Active orders continue to show **Track Order**; completed orders continue to show **View**.
- **File changed:** `lib/features/owner/screens/owner_dashboard_screen.dart`
- **Commit:** 002e867cd915982e87396319f85d9750670950c0
- **Testing status:** Not runtime-tested.
- **Next exact test:** `git pull` → Owner Dashboard → Recent Orders → verify an active/new tile remains green/actionable while a completed tile is visibly subdued and marked **COMPLETED** with **View**.

### 2026-09-21 — Fixed Customer Pickup Tracking final step

- **User finding:** Customer → My Orders → Order Details showed the order header as delivered/completed, but **Pickup Tracking** still highlighted **Order Placed**.
- **Root cause:** Customer _normalizeStatus() maps database `completed` to the Delivery terminal state `delivered`. The Pickup _statusIndex() then did not recognize that normalized value and fell back to index 0.
- **Fix:** In `lib/features/order/screens/order_details_screen.dart`, Pickup _statusIndex() now checks the raw order status first. `completed` and `delivered` both map to the final Pickup step **Claimed**.
- **Result:** A completed Pickup order now highlights **Claimed** in Customer Order Details instead of **Order Placed**.
- **Commit:** 22e47a88e9e33bab8d3155c9fe2151f369a8ab5d
- **Testing status:** Not runtime-tested.
- **Next exact test:** git pull → Customer → My Orders → open the same completed Pickup order → verify **Pickup Tracking** highlights **Claimed**, while the top order status remains correct.

### 2026-09-21 — Fixed Owner Dashboard Pickup completed tile showing Order Placed

- **User finding:** On **Owner Dashboard → Recent Orders → Order Tile**, a Pickup order that was already completed/claimed could still show **Order Placed** and **Track Order**.
- **Root cause:** The Owner Dashboard Pickup tracking mapper handled `claimed`, `picked_up`, and `pickedup`, but did not treat the database status `completed` as the terminal Pickup state. It therefore fell back to tracking index 0 (**Order Placed**).
- **Fix:** Pickup status `completed` now maps to the terminal **Claimed** step. Because the tile is at the final tracking step, its button becomes **View** instead of **Track Order**.
- **File changed:** lib/features/owner/screens/owner_dashboard_screen.dart
- **Commit:** 0746977f8e936c0b925196731cccb38a35a21f8d
- **Testing status:** Not runtime-tested yet.
- **Next exact test:** git pull → Owner Dashboard → Recent Orders → check the completed/claimed Pickup tile. It should show **Claimed** and **View**, not **Order Placed** and **Track Order**.

### 2026-09-21 — Fixed Owner Dashboard terminal order View not appearing

- **User clarification:** The requested change was specifically on the **Owner Dashboard Recent Orders tiles**. The previous edit changed the button logic to **View** for terminal orders, but terminal Pickup/Delivery orders were still being filtered out of the Recent Orders list, so the user could not see the new **View** button at all.
- **Fix:** Owner Dashboard now keeps completed/terminal orders in the Recent Orders tile list. Terminal orders show **View** with the visibility icon; active/in-progress orders show **Track Order**.
- **Pickup terminal:** **Claimed** remains visible and shows **View**.
- **Delivery terminal:** **Delivered/Completed** remains visible and shows **View**.
- **File changed:** lib/features/owner/screens/owner_dashboard_screen.dart
- **Commit:** 872a946129d2a7890933f7de9c8dbf9ce54513f5
- **Testing status:** Not runtime-tested yet.
- **Next exact test:** git pull → Owner Dashboard → check a Claimed Pickup or Delivered/Completed Delivery order in Recent Orders. It should remain in the list and its button should say View, not Track Order. Active orders should still say Track Order.

### 2026-09-21 — Owner Recent Orders completed tile button changed to View

- **User request:** If an order is already completed, the Recent Order tile should not show **Track Order** because there is no next step to track.
- **Fix:** Owner Dashboard Recent Order tiles now show **View** with a visibility icon when the order is at its terminal tracking step. Active/in-progress orders continue to show **Track Order**.
- **Pickup terminal:** **Claimed** → View.
- **Delivery terminal:** **Delivered/Completed** → View.
- **Commit:** `77fd32f640f23957069c89e5dca3da766fcc7d99`.
- **Testing status:** Not runtime-tested yet.
- **Next exact test:** `git pull` → Owner Dashboard → check a completed/Claimed order tile shows **View**, while an active order still shows **Track Order**.

### 2026-09-21 — Fixed Owner Pickup lifecycle labels/actions and completed-order list

- **User finding:** Owner Pickup orders were still using Delivery-style labels/actions. A Pickup order could show **Delivered** or **Mark as Completed**, and the order tile could remain at **Order Placed** instead of showing the Pickup-specific next step.
- **Required Pickup flow:** **Order Placed → Confirmed → Preparing → Ready to Pick Up → Payment Complete → Claimed**.
- **Owner Order Details fix:** Pickup now has its own action buttons:
  - **Preparing** → **Ready to Pick Up**
  - **Ready to Pick Up** → **Payment Complete**
  - **Payment Complete** → **Claimed**
  - **Claimed** → completed/claimed confirmation card
- **Receipt gate preserved:** While a Pickup order is still pending and its downpayment receipt is not paid, the generic Delivery action button is no longer shown. The Pickup Payment card remains responsible for receipt approval.
- **Status labels fixed:** Owner status display now maps Pickup technical states such as `ready_to_pick_up`, `full_payment`, and `claimed` to the required user-facing labels **Ready to Pick Up**, **Payment Complete**, and **Claimed**. Delivery labels remain separate.
- **Owner Dashboard fix:** Pickup terminal states (**Claimed**) and Delivery terminal states (**Delivered/Completed**) are removed from the active Recent Orders list so completed orders do not remain as active work. The Order Summary label **Completed** is used instead of **Delivered**.
- **Files changed:** `lib/features/owner/screens/owner_dashboard_screen.dart`, `lib/features/owner/screens/owner_order_details_screen.dart`.
- **Commits:** Dashboard `55274280a91dc3291f4f356198ddf3438ba5f08c`; Owner Order Details `b1979aaa29a5ec4abaa705a8a1c924661cba7b06`.
- **Testing status:** Not runtime-tested yet.
- **Next exact test:** `git pull` → open the current Pickup order on Owner side → verify that after **Preparing**, the button says **Ready to Pick Up**; after that status update, verify the next button says **Payment Complete**; after that, verify the next button says **Claimed**. Then return to Owner Dashboard and verify a **Claimed** Pickup order is no longer in the active Recent Orders list. Test only this flow and report the result before any further edit.

### 2026-09-21 — Fixed Pickup receipt re-upload RLS and Owner reject red screen

- **User test finding:** Customer successfully uploaded a Pickup GCash receipt. Owner rejected it, but saving the rejection could produce the known Flutter red screen. After rejection, the Customer could not upload a replacement receipt and received: `StorageException(message: new row violates row-level security policy, statusCode: 403, error: Unauthorized)`.
- **Root cause — Customer re-upload:** The Customer uses Storage `upsert: true` on the same path `<order_id>/receipt.jpg`. The existing Storage policy allowed INSERT and SELECT, but Supabase requires **UPDATE + SELECT + INSERT** when overwriting an existing object. The rejected order was already in `receipt_rejected`, so the missing UPDATE policy caused the 403.
- **Supabase fix:** Added **Customers update own pickup receipts** UPDATE policy on `storage.objects`. It only allows the authenticated customer who owns the Pickup order to replace the receipt while `pickup_downpayment_status = 'receipt_rejected'`.
- **Verification:** The live policy was created successfully and read back from `pg_policies`. Existing INSERT and SELECT policies remain in place.
- **Root cause — Owner red screen:** The rejection dialog's `TextEditingController` was disposed immediately after the dialog future returned. This could race with the dialog/TextField teardown and reproduce the Flutter `_dependents.isEmpty` red-screen assertion seen previously.
- **Flutter fix:** Owner Order Details now defers disposing the rejection dialog controller until the next frame after the rejection flow completes, avoiding the teardown race.
- **Files changed:** `lib/features/owner/screens/owner_order_details_screen.dart`; `supabase/fix_customer_pickup_receipt_reupload_storage_policy.sql`.
- **Commits:** Flutter fix `46152ed5416c891abb0c02923dd76aabac4a49c5`; Storage policy `381f8973c7c949859c47b041d3536edc2ca7316a`.
- **Current stopping point:** Both reported issues have been addressed. Do not reset the order; use the same rejected Pickup order for the verification.
- **Next exact test:** `git pull` → Customer side open the rejected Pickup order → **Upload Receipt** → choose a new receipt photo → verify upload succeeds and status changes to **Receipt Submitted**. Then Owner side open the same order → Reject with a reason once → verify there is **no red screen** and the reject UI closes normally. Report the result before any further edit.

### 2026-09-21 — Reset All Order Test Data for Fresh Testing

- **User request:** Delete all existing order-related test data so we can restart testing from a clean order state.
- **Scope:** All orders — Pickup and Delivery.
- **Deleted from Supabase:** all rows from payments that had an order_id, then all rows from orders. Because order_items and promo_redemptions reference orders with cascade deletion, their connected rows were removed automatically.
- **Verification:** orders = 0, order_items = 0, payments = 0, and promo_redemptions = 0.
- **Important:** This reset did not delete restaurants, users, addresses, menus, promos, or other non-order data.
- **Pickup lifecycle to test next:** **Order Placed → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**.
- **Owner tile wording:** Use the proper customer-facing step names exactly as written above, including **Ready to Pick Up**, **Full Payment**, and **Claimed** — not technical/database-style wording.
- **Current stopping point:** Database order data is cleared for a fresh test. No new order has been created yet.
- **Testing status:** Fresh order not created yet.

### 2026-09-21 — Improved Owner Order Tiles + Collapsed Receipt Viewer

- **Owner Dashboard order tiles:** Recent Order tiles are now compact and no longer dominated by large content.
- **Track Order:** Each Owner order tile now shows a compact progress tracker. The steps branch by fulfillment type:
  - Pickup: **Order Placed → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**
  - Delivery: **Order Placed → Confirmed → Preparing → Ready for Pickup → Out for Delivery → Delivered**
- **Status updates:** The tile maps the current database status to the correct tracking step. When the Owner opens Track Order, updates the order, and returns, the Dashboard reloads so the tile reflects the next step without requiring a separate manual refresh.
- **Receipt UI:** Owner Order Details now keeps the receipt image **hidden by default**. A **View Receipt** button opens it only when needed; **Hide Receipt** collapses it again. This prevents the receipt image from taking over the screen.
- **Files changed:** `lib/features/owner/screens/owner_dashboard_screen.dart`, `lib/features/owner/screens/owner_order_details_screen.dart`.
- **Commits:** Dashboard `a9ae1d0fb2b65e54339396e9497b7f5c3dd4b58b`; Receipt viewer `02792e2704734c4230028eac5e726b27f5a8622d`.
- **Testing status:** Not runtime-tested yet.
- **Next exact test:** `git pull` → Owner Dashboard → open Recent Orders. Verify each tile is compact, shows the Track Order progress, and the receipt is hidden until **View Receipt** is tapped. Open one order, change its next status, return to Dashboard, and verify the tile shows the updated step.
- **Project workflow rule:** Every meaningful development action must be recorded here. After code edits: commit/push → user `git pull` → one exact test → wait for result.

### 2026-09-21 — Updated Customer Pickup Order Tracking

- **User finding:** The Customer Order Details tracking still used the Delivery tracking sequence, so Pickup did not yet reflect the agreed Pickup lifecycle.
- **File changed:** `lib/features/order/screens/order_details_screen.dart`
- **Pickup tracking is now separate from Delivery:** **Order Placed → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**.
- **Pickup UI:** The tracking card is labeled **Pickup Tracking** and uses Pickup-specific descriptions/icons.
- **Delivery tracking remains separate:** Delivery continues to use **Order Placed → Confirmed → Preparing → Ready for Pickup → Out for Delivery → Delivered**.
- **Status support added:** Customer tracking now recognizes `full_payment`, `payment_due`, `claimed`, `picked_up`, and `pickedup` as Pickup lifecycle states.
- **Important:** This edit changes the Customer tracking UI/state mapping only. It does not yet implement the Owner buttons or database transitions for **Ready to Pick Up → Full Payment → Claimed**.
- **Commit:** `397b2ec982b717357b7d1438ad6896b90783425b`.
- **Testing status:** Not runtime-tested yet.
- **Next exact test:** `git pull` → open the same Customer Pickup order → verify the tracking shows the six Pickup steps and that the current **Preparing** step is highlighted after Owner accepts the receipt. Do not test future Full Payment/Claimed transitions yet.

### 2026-09-21 — Fixed Owner Pickup Accept/Reject immediate UI state

- **File changed:** `lib/features/owner/screens/owner_order_details_screen.dart`
- **Problem:** After Owner accepted or rejected a Pickup receipt, the database updated successfully but the Owner screen continued showing the Accept/Reject buttons until the screen was refreshed.
- **Root cause:** `_buildPickupPaymentCard()` was reading `widget.order['pickup_downpayment_status']`, which is the original navigation payload and does not change after the database update.
- **Fix:** Added local `_pickupPaymentState`, initialized from the order and refreshed from the latest order record when the screen loads. The Pickup payment card now uses this local state.
- **Immediate Accept behavior:** After a successful Accept, the local payment state becomes `paid`, the order status becomes **Preparing**, and the Accept/Reject buttons disappear immediately without refresh. The approved receipt remains visible.
- **Immediate Reject behavior:** After a successful Reject, the local payment state becomes `receipt_rejected`, the rejected receipt image is cleared from the screen immediately, the buttons disappear, and the screen shows **Waiting for customer to upload a new receipt** without refresh.
- **Commit:** `dbe67e63719ce171a847b89bc3889905555bb8dd`
- **Testing status:** Code pushed to GitHub. User must pull and perform one runtime test before any further edit.
- **Next exact test:** `git pull` → run the app → open the same Owner Pickup order with `Receipt Submitted` → test **Accept** once and verify buttons disappear immediately and status becomes **Preparing** without refresh. Report the result before continuing.

### 2026-09-21 — Defined Pickup-specific order lifecycle

- **Important business rule:** Pickup orders have a different order-status flow from Delivery orders and must not reuse the Delivery lifecycle blindly.
- **Pickup order lifecycle:** **Order Placed → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**.
- **Downpayment/receipt is a payment gate, not the final Pickup lifecycle:** The initial Pickup downpayment is handled through the manual GCash receipt workflow. Owner receipt acceptance makes the downpayment paid and allows the order to proceed into **Preparing**.
- **Full payment:** After the order reaches **Ready to Pick Up**, the remaining balance must be collected before the customer can claim the order.
- **Final Pickup state:** After the customer has paid the remaining balance and physically receives the order, the order becomes **Claimed**.
- **Delivery is different:** Delivery will have its own lifecycle and should not be changed to use Pickup-specific states such as **Ready to Pick Up** or **Claimed**.
- **Implementation note for next work:** When editing order-status transitions, UI labels, Owner action buttons, Customer order tracking, payment handling, or database status rules, always branch by `fulfillment_type` so Pickup and Delivery workflows remain separate.
- **Current stopping point:** This lifecycle is now part of the project requirements/documentation. No code change for these final lifecycle states has been made yet.
- **Next relevant implementation:** Continue the Owner Pickup UI fix first (immediate Accept/Reject state update). After that, implement/test the remaining Pickup lifecycle states according to the sequence above.

### 2026-09-21 — Owner Pickup Receipt acceptance/rejection test and next UI fix

- **Latest runtime test:** Customer Pickup order → GCash receipt upload → Owner receipt review is working. Owner can see the submitted receipt image.
- **Reject test:** Owner rejected the submitted receipt successfully. Supabase changed the order to `receipt_rejected`, and the customer side correctly reached the rejected state.
- **Rejected receipt rule:** A Supabase trigger named `trg_clear_rejected_pickup_receipt_path` clears `orders.pickup_receipt_path` whenever the downpayment status becomes `receipt_rejected`. This is intended so the rejected receipt is no longer treated as the active receipt.
- **Replacement rule:** When the customer uploads a new receipt after rejection, it must reuse the same order ID/order number and replace the active receipt rather than creating a new order. Approved receipts must remain available after Owner acceptance.
- **Downpayment display fix:** Owner Dashboard was updated to select `pickup_downpayment_amount` and `pickup_downpayment_percent`, so Owner Order Details can display the actual configured/stored downpayment instead of defaulting to ₱0.
- **Commit for downpayment display:** `c1a48d92d61cbb50eff49cfa00404e78cf2e8f25`.
- **Known Flutter UI issue:** After Owner Accept or Reject, the database update succeeds, but the Owner screen still shows the Accept/Reject buttons until the screen is refreshed because `_buildPickupPaymentCard()` reads the original `widget.order['pickup_downpayment_status']` instead of local state.
- **Required next fix:** Add a local pickup payment state (for example `_pickupPaymentState`) in `owner_order_details_screen.dart`. Initialize it from the order, use it in `_buildPickupPaymentCard()`, and update it immediately after a successful Accept/Reject.
- **Immediate UI behavior required after Accept:** buttons disappear immediately, payment state becomes Paid, order status becomes **Preparing** without refresh, and the approved receipt remains visible.
- **Immediate UI behavior required after Reject:** buttons disappear immediately, rejected receipt image disappears immediately, and the screen shows **Waiting for customer to upload a new receipt** without refresh.
- **Flutter error seen during Reject:** `_dependents.isEmpty` assertion occurred once, but the Reject database update itself succeeded. Do not treat this as a business-logic failure unless it reproduces after the local-state UI fix; if it reproduces, inspect the full Flutter stack trace.
- **Current stopping point:** Receipt image, Owner review, Reject flow, rejected-state trigger, and downpayment amount loading have been tested. The remaining immediate task is the Owner Order Details local-state UI update described above.
- **Next workflow:** User will pull the next code edit, test **one time only**, and report the result before we proceed.
- **Project workflow rule:** Every meaningful development action must be recorded in this file. After code edits: commit/push → user `git pull` → one exact test → wait for result.

### 2026-09-21 — Fixed Supabase Storage policy blocking Owner receipt image

- **User test finding:** Owner still showed `Payment: Receipt Submitted` but no receipt photo.
- **Verified database:** The submitted order has a valid `pickup_receipt_path`, and the corresponding JPG exists in the private `payment-receipts` Storage bucket.
- **Root cause:** The Storage SELECT policy `Owners view pickup receipts` used the wrong folder expression: it checked `storage.foldername(r.name)[1]` instead of the uploaded object's path `storage.foldername(objects.name)[1]`. Therefore the Owner could not create a signed URL for the receipt even though the file existed.
- **Supabase fix:** Replaced the Owner receipt SELECT policy so it matches the order ID from the Storage object's folder and verifies that the restaurant belongs to the authenticated Owner.
- **Migration:** `fix_owner_pickup_receipt_storage_policy` applied successfully.
- **Current stopping point:** Backend Storage access is now corrected. Do not Accept/Reject yet.
- **Next task:** `git pull`, restart the app, open the same Owner pickup order, and check whether the receipt photo is now visible.

### 2026-09-21 — Fixed Owner receipt loading to refresh receipt path directly

- **User test finding:** Owner still showed `Payment: Receipt Submitted` but no receipt image after the dashboard query was updated.
- **Root cause:** Owner Order Details was relying on the order map passed from the dashboard. Even though the dashboard now selects receipt metadata, the receipt viewer should not depend on that navigation payload.
- **Fix:** Owner Order Details now re-queries the order by ID for `pickup_receipt_path` when opening the screen, then creates the signed URL directly from the private `payment-receipts` bucket. It also logs when the database has no receipt path or when signed URL creation fails.
- **Commit:** `a4efc0f20a9f7065cebbf70cee61c2b5b079e915`
- **Current stopping point:** Receipt image visibility is the only test being addressed now. Do not Accept/Reject until the image is visible and manually checked.
- **Next task:** `git pull`, restart the app, open the same Owner pickup order again, and check the receipt image.

### 2026-09-21 — Fixed Owner pickup receipt image loading

- **User test finding:** Owner Order Details showed `Payment: Receipt Submitted` but no uploaded receipt image, so the Owner could not manually verify the GCash transaction.
- **Root cause:** Owner Dashboard loaded recent orders without selecting `pickup_receipt_path`. The order map passed into `OwnerOrderDetailsScreen` therefore had no receipt path, so the private Storage signed URL could not be created.
- **Fix:** Owner Dashboard order query now includes `pickup_receipt_path`, `pickup_receipt_submitted_at`, and `pickup_receipt_rejection_reason`. This allows Owner Order Details to load the submitted receipt from the private `payment-receipts` bucket.
- **Supabase changes:** None; existing private Storage/signed-URL workflow is reused.
- **Commit:** `c05d0ceb445d63b26ad290c885724daa62745970`
- **Current stopping point:** Owner receipt status is already reaching `Receipt Submitted`; the missing receipt path has been fixed in the dashboard query.
- **Next task:** `git pull`, run the app, open the same Owner pickup order, and verify the uploaded receipt image is visible. Do not Accept/Reject yet until the image can be manually checked.

### 2026-09-21 — Removed duplicate checkout implementation

- **Issue:** `checkout_screen.dart` still contained a second copy of the entire checkout implementation beginning at line 2043 (`port 'package:flutter/material.dart';`), causing the 76 analyzer issues.
- **Fix:** Kept the original first 2042 lines, which contain the intended checkout and pickup workflow, and removed the duplicated second implementation.
- **Commit:** `1416d086b70efb8bf4e3458265cb166317f3ce22`
- **Current stopping point:** Duplicate source removed. Local analyzer has not yet been rerun after this exact fix.
- **Next task:** `git pull` → `flutter analyze`.

### 2026-09-21 — Restored checkout screen after accidental deletion

- **Issue found:** The previous cleanup commit accidentally replaced `lib/features/checkout/screens/checkout_screen.dart` with an empty file. The local analyzer then showed 26 issues because the checkout implementation was missing, while the remaining 26 messages were existing infos/warnings.
- **Fix:** Restored the complete checkout screen from the known-good parent commit `da0cb69`. This preserves the pickup/downpayment workflow that existed before the accidental deletion.
- **Commit:** `a68281893803ce9bdf5d75b1c8f07b66069beb50`
- **Current stopping point:** Checkout source restored. The local analyzer has not yet been rerun after this restoration.
- **Next task:** `git pull` → `flutter analyze`. Goal is to eliminate all remaining analyzer issues, including infos/warnings, not only errors.

### 2026-09-21 — Fixed checkout file corruption after pickup workflow edit

- **Issue:** `flutter analyze` reported 76 issues because `lib/features/checkout/screens/checkout_screen.dart` had accidentally been duplicated from line 2043 onward. This caused duplicate classes/imports and the syntax error at line 2043.
- **Fix:** Removed the duplicated second copy and retained the intended pickup payment success flow and receipt-upload navigation in the original checkout file.
- **Verification:** GitHub file now ends at the intended `OrderDetailsScreenById` helper and no longer contains the duplicate second `CheckoutScreen` declaration.
- **Current stopping point:** Checkout source corruption fixed. Local analyzer must be rerun after pulling the commit.
- **Next task:** `git pull` → `flutter analyze`. If analyzer reports remaining issues, fix those before runtime testing.
- **Commit:** `059f4dd39df8ec5e8ab8a4b2f8ec5356648b5f65`

### 2026-09-21 — Implemented manual GCash pickup receipt workflow

- **Concept finalized:** Customer places a Pickup order first, but the Owner does not receive/start it yet. Customer gets two actions while waiting: **Cancel Order** or **Upload Receipt**. Customer pays directly to the restaurant's GCash account.
- **Receipt verification:** After receipt upload, the order becomes `receipt_submitted` and appears to the Restaurant Owner. Owner can **Accept** or **Reject**. Rejection keeps the order alive and lets the customer upload another receipt. Accepting the receipt marks the downpayment paid and automatically starts the order as `preparing`. **Admin has no payment-approval role.**
- **7-day cleanup:** Pickup receipt objects and receipt metadata are scheduled for automatic cleanup after 7 days to prevent Storage/order-queue flooding. Actual completed order/payment audit records are not blanket-deleted.
- **Supabase:** Added restaurant GCash fields (`gcash_name`, `gcash_number`, `gcash_qr_url`), pickup receipt fields on `orders`, `payment-receipts` private Storage bucket, customer/owner Storage policies, and `cleanup-old-pickup-receipts()` with a daily pg_cron job.
- **Flutter files:** Updated checkout success flow, customer order model/repository/details, owner dashboard/order details, and owner restaurant profile. Owner can configure GCash name/number and upload a GCash QR. Customer can upload receipt from gallery.
- **Security:** Receipt bucket is private; access is restricted by customer ownership or restaurant ownership. Receipt URLs are signed for short-lived viewing.
- **Testing:** Supabase schema/bucket/private storage policies verified. A scheduled Edge Function now performs the actual Storage API deletion after 7 days; this avoids orphaning files because Supabase recommends deleting Storage files through the Storage API rather than direct SQL. Flutter runtime/analyzer verification is still pending.
- **Commits:** `e600d784b7a801a6752f7247b52b513b4bac04e`, `116e66caccaa4e2b5543bd9e1ebb3c1d52091ecc`, `ba52d772e9ee7aa7785d94776c5a727390465eff`, `30a0d5514b4966b32ffd7fa8d64cc6d9e5052578`, `28d5feec71d2ef161265545eba4b4be47b2cdfc9`, `d8e4ef69e575661c0fdfb93f18c8a2600e97eeea`, `b6a9c0d31b5d2f83ad65ea421ab3c0b3e469bb7d`, plus Edge Function `cleanup-pickup-receipts` deployment.
- **Current stopping point:** Manual Pickup GCash receipt workflow is implemented in code and database; runtime/analyzer test is next.
- **Next task:** `git pull`, run `flutter analyze`, then test Owner GCash settings → Customer Pickup Place Order → Upload Receipt → Owner Accept/Reject.

### 2026-09-21 — Made restaurant distance display GPS-only

- **File changed:** `lib/features/home/screens/home_screen.dart`
- **Reason:** Customer confirmed distance must be based on actual customer GPS location; if GPS/location is not accepted, no distance should be shown.
- **Fix:** Tightened the restaurant distance helper so it requires valid customer address coordinates and valid restaurant coordinates. It explicitly does not fall back to address text, city/province, or approximate location.
- **Behavior:** If the customer has no valid GPS coordinates, the restaurant tile still appears but the `X.X km away` label is omitted. With valid GPS coordinates, the distance is calculated and displayed.
- **Supabase changes:** None.
- **Testing:** GitHub change committed; runtime verification: PASSED. Customer Home was tested with GPS/location accepted and with GPS/location denied/off; distance appeared only with GPS and was omitted without GPS while restaurants remained visible.
- **Commit:** `3f8edcec22d226fd2f76249bf17efa0513325050`.
- **Current stopping point:** Restaurant distance display is now GPS-only.
- **Next task:** Proceed to the next open milestone: implement the actual online payment flow and server-side payment verification for pickup downpayment.

### 2026-09-21 — Added customer distance to restaurant tiles

- **File changed:** `lib/features/home/screens/home_screen.dart`
- **Reason:** Customer requested each restaurant tile to show the distance from the customer's saved/default location, e.g. `10.2 km away`, alongside the restaurant name, rating/review count, and address.
- **Fix:** Added Haversine distance calculation using the customer's saved/default address coordinates and each restaurant's latitude/longitude.
- **UI:** Added `X.X km away` to both Featured Restaurant cards and the regular restaurant cards. If valid coordinates are unavailable, the distance label is omitted.
- **Supabase changes:** None.
- **Testing:** GitHub change committed; runtime verification pending.
- **Commit:** `d99fa50b37d3dccf170a2f87a17af8903e0a6fa2`.
- **Current stopping point:** Restaurant tiles now have customer-distance display support.
- **Next task:** `git pull`, open Customer Home, and verify the restaurant cards show the expected `X.X km away` value.

### 2026-09-21 — Removed redundant Customer Home nearby notice

- **File changed:** `lib/features/home/screens/home_screen.dart`
- **Reason:** The Home screen already has the **Nearby Restaurants** section and restaurant list below it, so the separate `Nearby restaurants / Showing restaurants...` notice was redundant.
- **Fix:** Removed the delivery-radius/address notice block from Customer Home.
- **Behavior:** The restaurant list remains visible regardless of delivery distance; delivery eligibility is handled separately in Checkout.
- **Supabase changes:** None.
- **Testing:** GitHub change committed; runtime verification pending.
- **Commit:** `e8e7460ae06233d25772c7cd28331e71ee5a8d35`
- **Next task:** `git pull` and visually verify Customer Home now goes directly to the restaurant list without the redundant notice.

### 2026-09-21 — Fixed Checkout analyzer error after Delivery disabling edit

- **User test:** `flutter analyze` found 1 blocking error in `checkout_screen.dart` plus non-blocking infos/warnings.
- **Root cause:** Delivery `RadioListTile` was inside a `const Column` while using runtime state for its availability/color. It also used deprecated per-radio `onChanged`.
- **Fix:** Removed the invalid `const` parent and switched Delivery to `enabled: _deliveryAvailable`; the existing `RadioGroup` remains responsible for selection changes.
- **Cleanup:** Removed obsolete `DistanceUtils` import and unused customer-location variable from Home after radius filtering was removed.
- **Other analyzer infos:** Existing interpolation suggestions remain non-blocking.
- **Supabase changes:** None.
- **Testing:** User should pull and rerun `flutter analyze`; runtime Delivery-disabled behavior remains pending.
- **Checkout commit:** `00359f1582a6f3ef202c7f55945b3745e31234e3`
- **Home commit:** `df756b663f96b4b4a094cada0b9e28a906dba7ae`
- **Current stopping point:** Blocking analyzer error addressed.
- **Next task:** `git pull`, then rerun `flutter analyze` only.

### 2026-09-21 — Disabled Delivery for restaurants beyond maximum distance

- **User finding:** Customer Home correctly keeps far restaurants visible, but Checkout still allowed selecting Delivery for a restaurant 13.59 km away when Maximum Delivery Distance was 10 km. The server then returned a raw PostgREST error.
- **File changed:** `lib/features/checkout/screens/checkout_screen.dart`
- **Fix:** Checkout now loads the configured maximum delivery distance and compares it with the calculated restaurant/customer distance. If the restaurant is beyond the limit, the **Delivery** option is disabled and cannot be selected. **Pick-up remains selectable.**
- **UX:** The disabled Delivery option explains the actual distance and configured maximum. Restaurants are still discoverable; distance limits only affect Delivery eligibility.
- **Security:** Existing server-side delivery-distance validation remains in place as the final enforcement layer.
- **Supabase changes:** None.
- **Testing:** Code committed; runtime verification pending.
- **Commit:** `56b516f37960c2928274eaac235a9b792de899ba`
- **Current stopping point:** Checkout now prevents customers from selecting Delivery when the restaurant is outside the configured delivery range.
- **Next task:** User should `git pull`, open the 13.59 km restaurant with maximum distance 10 km, and confirm Delivery is visibly disabled while Pick-up can still be selected.

### 2026-09-21 — Fixed Customer restaurant visibility beyond delivery radius

- **User finding:** With Maximum Delivery Distance set to 10 km, Customer Home showed no restaurants. This conflicted with the required fulfillment rule.
- **Required behavior:** Restaurants must remain visible regardless of distance. Restaurants within the configured maximum support Delivery + Pickup; restaurants beyond it remain visible for Pickup only.
- **File changed:** `lib/features/home/screens/home_screen.dart`
- **Fix:** Removed the Customer Home distance-based restaurant filtering. Search and category filtering remain unchanged. Distance/radius data is no longer used to exclude restaurants from discovery.
- **Delivery enforcement:** Existing server-side delivery-distance validation in checkout remains authoritative, so Delivery cannot bypass the configured maximum. Pickup remains available without the delivery-distance restriction.
- **Supabase changes:** None.
- **Testing:** Code change committed. Runtime verification pending.
- **Commit:** `0967bf6707aef234cd6cc89f7220b7894bab70bb`
- **Current stopping point:** Customer Home now keeps restaurants visible beyond the maximum delivery distance.
- **Next task:** User should `git pull`, open Customer Home with Maximum Delivery Distance = 10 km, and confirm restaurants beyond 10 km are visible. Then test that a far restaurant offers Pickup while Delivery is unavailable.

### 2026-09-21 — Fixed Pickup Downpayment checkout analyzer error

- **User test:** `flutter analyze` found one blocking error in `lib/features/checkout/screens/checkout_screen.dart`: `pickupDownpayment` was referenced inside `_placeOrder()` but had only been declared in the build scope.
- **Fix:** Moved/recomputed the pickup downpayment inside `_placeOrder()`, using the cart subtotal after the selected promo discount and the configured pickup percentage.
- **Other analyzer output:** Existing informational interpolation suggestions in `promo_code_repository.dart` and `home_screen.dart`, plus the pre-existing unused `_NoAddressView` warning, were not changed because they are unrelated to the blocking error.
- **Testing:** Code fix committed. User should pull and rerun `flutter analyze`; no claim of a clean analyzer result until user confirms.
- **Commit:** `16700a4e9ab907d00bfc123572c67a6ba0d070f1`.
- **Current stopping point:** Blocking analyzer error from the pickup downpayment edit is fixed.
- **Next task:** `git pull`, rerun `flutter analyze`, then report the result before we continue pickup payment testing.

### 2026-09-21 — Added configurable Pickup Downpayment foundation

- **User requirement:** Pickup orders require a configurable percentage downpayment; current agreed default is **50%** and the downpayment is **non-refundable** under the pickup no-show rule.
- **Supabase changes:** Added `delivery_pricing_settings.pickup_downpayment_percent` with default 50.00 and 0–100 validation. Added `orders.pickup_downpayment_percent`, `orders.pickup_downpayment_amount`, and `orders.pickup_downpayment_status`. Added authenticated RPC `get_pickup_downpayment_percent()` and a customer INSERT policy for pending pickup downpayment payment records.
- **Flutter changes:** Admin Delivery Pricing now exposes a Pickup Downpayment percentage field. Checkout loads the configured percentage, calculates the pickup downpayment from the discounted pickup subtotal, and displays the amount plus the non-refundable rule. Pickup order creation stores the configured percentage/amount and creates a pending online payment record.
- **Important limitation:** The payment record is currently **pending**. No customer online payment gateway/verification has been implemented yet, so this change establishes the amount, database state, and checkout presentation but must not be treated as completed payment processing.
- **Verification:** Supabase migration succeeded. Database value and RPC both return **50.00%**. Flutter runtime/analyzer has not been run after this edit.
- **GitHub commits:** Admin repository `0a32827280cd949fd4ef5e8e3ec9d81ffece1a9a`; Admin pricing screen `cbf8ed61cb4e3851652f1cb81bbf66288b68c137`; Checkout `f5b820320bc2d967163a6328185ffe343ee9bb33`; Order repository `5881e9d16d6819b2463d981639f09e82da6804e3`; migration documentation `342c05e19523a88697f8649e553c58ac7549c12`.
- **Current stopping point:** Pickup downpayment configuration/calculation/storage foundation is implemented.
- **Next test:** User should `git pull`, run the app, open Admin → Delivery Pricing and verify Pickup Downpayment shows **50%**. Then open Customer Checkout, choose Pick-up, and verify the downpayment card shows 50% and the calculated amount. Do not treat the order as paid yet.
- **Next development milestone after this test:** Implement the actual customer payment method/gateway and server-side payment verification before allowing a pickup order to move into restaurant processing.

### 2026-09-21 — Fixed Admin access to Delivery Pricing settings

- **User-reported issue:** Delivery Pricing screen displayed all values as `₱0`, and saving failed with PostgreSQL RLS error `42501` on `delivery_pricing_settings`.
- **Root cause:** The existing table policy allowed only Developers to manage `delivery_pricing_settings`. Admin users could not read the existing row or insert/update it through the Flutter client. The row itself was NOT deleted or reset.
- **Verified existing values in Supabase:** Base Fee `₱30`, Included Distance `2 km`, Additional Fee Per KM `₱10`, Fuel Adjustment `₱5`, Minimum Fee `₱25`, Maximum Delivery Distance `15 km`, Rain/Peak/Night Surcharge `₱0`.
- **Supabase fix:** Replaced the Developer-only management policy with separate SELECT/INSERT/UPDATE/DELETE policies allowing both `public.is_admin()` and `public.is_developer()`.
- **Flutter pricing values:** No pricing values were changed by this fix. The previous edit only changed the Maximum Distance label/description.
- **Testing:** Pending user refresh/pull and runtime verification as Admin.
- **Migration:** Applied directly to Supabase as `fix_delivery_pricing_admin_access`.
- **Current stopping point:** Delivery Pricing values remain intact and Admin access is restored at the RLS level.
- **Next action:** User should `git pull` (for the previously pushed Home/radius changes), reopen Admin → Delivery Pricing, and verify the original prices appear. Do not change/save values yet unless they appear correctly.

### 2026-09-21 — Made server-side delivery distance authoritative at Place Order

- **Reason:** The existing `public.calculate_delivery_fee()` already enforces `maximum_delivery_distance_km`, but Customer Checkout was previously using only the Flutter-side fee calculation when creating the order.
- **File changed:** `lib/features/checkout/data/order_repository.dart`
- **Fix:** For Delivery orders, `OrderRepository.createOrder()` now calls `public.calculate_delivery_fee(p_restaurant_id, p_address_id)` before inserting the order. The returned server-calculated fee becomes the authoritative `delivery_fee`.
- **Security/behavior:** If the Restaurant → Customer distance exceeds the platform maximum, the database function raises an error and the order is not inserted. This protects the rule even if the client is manipulated.
- **Pickup:** Pickup orders continue with a zero delivery fee and do not call the delivery calculation.
- **Testing:** Runtime test is pending. Current test coordinates are too close to demonstrate an out-of-range delivery.
- **Commit:** `c95edb753c67fbb9f67c860565b6be58fda2cc7b`
- **Current stopping point:** Customer discovery filtering and server-side delivery-radius enforcement are both implemented.
- **Next action:** User should `git pull` and run the Customer Home/Checkout flow. Do not mark out-of-range C8.5 as PASSED until a separated test location is available.

### 2026-09-21 — Added dynamic Customer Restaurant Discovery + Delivery Radius

- **User requirement:** Admin and Developer must control a dynamic maximum distance in kilometers. Customers should only see restaurants within that radius of their saved/default address, and customers must also be unable to order beyond the same platform radius.
- **Existing backend capability reused:** `public.delivery_pricing_settings.maximum_delivery_distance_km` already existed and `public.calculate_delivery_fee()` already calculates Restaurant → Customer distance with Haversine and rejects a delivery when the distance exceeds that maximum.
- **Design decision:** Use the existing platform-wide `maximum_delivery_distance_km` as the single global **Customer Restaurant Discovery + Delivery Maximum** setting. No hardcoded 10 km value was added. Admin and Developer can change the value from the existing Delivery Pricing module.
- **Supabase change:** Added `public.get_customer_restaurant_radius_km()`, a `SECURITY DEFINER`, `STABLE` function with `search_path = ''`. It exposes only the maximum radius to authenticated customers instead of exposing the full delivery-pricing configuration.
- **Supabase permissions:** Execute was revoked from `public` and `anon`, and granted only to `authenticated`.
- **Customer Home change:** `lib/features/home/screens/home_screen.dart` now loads the customer's default saved address (falling back to the first saved address), loads the platform radius, and filters restaurants by actual Restaurant → Customer Haversine distance before showing Featured/Nearby results.
- **Location validation:** Restaurants with missing/invalid coordinates are excluded from radius-filtered results. Customers without a saved address with valid GPS coordinates are shown a clear prompt instead of an unrestricted restaurant list.
- **Repository change:** `lib/features/home/data/restaurant_repository.dart` now reads the radius through the new RPC.
- **Admin/Developer UI clarification:** `lib/features/admin/screens/delivery_pricing_screen.dart` now labels the setting **Maximum Customer & Delivery Distance** and explains that it controls both customer discovery and delivery ordering.
- **SQL documentation:** Added `supabase/customer_restaurant_discovery_radius.sql` matching the live Supabase function.
- **Important:** The current development test data has Restaurant and Customer coordinates that are the same/very close, so an actual out-of-range runtime test cannot be meaningfully demonstrated yet. The code path is now ready for a future test using clearly separated coordinates.
- **Testing status:** C8.5 missing-GPS behavior was already confirmed by the user: Place Order is disabled when the selected Delivery address has no latitude/longitude. The new radius/discovery feature itself has not yet been runtime-tested by the user.
- **Commits:** Restaurant radius repository `63b4762d0cd9e3a5c52f08e31127cc6db2c01cd6`; Customer Home filtering `5fc8a0e598d01f0b3d6f2714cfade2cfbf736535`; Admin/Developer UI clarification `e8e5d6197328fc90fc4421aebedfdb448d250dde`; SQL documentation `446ee780c88e81029691b8199f6171b618d3cd4f`.
- **Current stopping point:** Dynamic global customer radius is implemented. Do not change the distance algorithm unless a later test exposes a problem.
- **Next action:** User should `git pull`, run the app, and verify the Customer Home loads normally. A real out-of-range C8.5 test can be done later after creating clearly separated test coordinates or test locations.

### 2026-09-21 — Fixed Promo/Coupon order placement database error

- **User-reported error:** Customer could select a promo, but Place Order failed with PostgreSQL error `42702` because `promo_code_id` was ambiguous inside `public.claim_promo_code()`.
- **Root cause:** The function returns a column named `promo_code_id`, which is also a column name in `promo_redemptions`; unqualified references could be resolved as either the PL/pgSQL output variable or table column.
- **Supabase fix:** Updated `public.claim_promo_code(uuid, text)` directly in project `taltqnxhivpfwjqlvxnt`. Qualified `promo_redemptions` references with alias `pr` and qualified `orders` references with alias `o` in the final update.
- **Verification:** Re-read the live function definition from Supabase after replacement; the corrected qualified references are present and the function compiles successfully.
- **GitHub documentation:** Updated `supabase/customer_checkout_promo_codes.sql` to match the live function.
- **No Flutter code change:** The Place Order client flow remains unchanged.
- **Testing:** User should `git pull` and retry the same Checkout → Place Order flow with the selected promo. Confirm order succeeds and promo redemption is recorded.
- **Current stopping point:** Promo selection is confirmed working; Place Order was blocked by this backend ambiguity and is now fixed. Do not move to C8.5/C8.6 until the user confirms Place Order succeeds.
- **Next action:** User runs `git pull`, retries Place Order with the promo, then reports **goods** or the exact new error.
### 2026-09-21 — Fixed Promo/Coupon dropdown selection

- **Issue:** User reported that the new Promo/Coupon dropdown was visible but promo options could not be selected.
- **File changed:** `lib/features/checkout/screens/checkout_screen.dart`
- **Fix:** Replaced the nullable dropdown item value used for “No promo” with the explicit sentinel value `__none__`, and updated `initialValue` and `onChanged` handling accordingly. Actual promo IDs remain unchanged.
- **Backend/Supabase:** No changes.
- **Commit:** `e9788cbaab2edc4439dc86bdd3181eba36b534dd`
- **Testing:** Pending user `git pull` + runtime verification.
- **Stopping point:** Do not continue to C8.5/C8.6 until Promo dropdown selection is confirmed working.
- **Next action:** User runs `git pull`, then tests Checkout → Promo/Coupon → opens dropdown → selects an actual promo → verifies description and discount update.

### 2026-09-18 — End-of-session handoff updated for next ChatGPT session

- **Purpose:** Updated this handoff so the next ChatGPT can continue the HALAL Food project without asking the user to repeat the project history.

### 2026-09-21 — Fixed Pickup Owner order-status enum error

- **User-reported error:** Owner Pickup order update failed with PostgreSQL `22P02`: Invalid input value for enum `order_status`: `ready_to_pick_up`.
- **Verified live Supabase enum:** `order_status` only contains `pending`, `confirmed`, `preparing`, `ready`, `out_for_delivery`, `delivered`, `cancelled`, and `refunded`. The custom Pickup labels `ready_to_pick_up`, `full_payment`, and `claimed` are not valid database enum values.
- **Root cause:** Owner Pickup UI was trying to store UI lifecycle labels directly into the `orders.status` enum.
- **Flutter fix:** `lib/features/owner/screens/owner_order_details_screen.dart` now maps Pickup `ready_to_pick_up` → database `ready`; records final Pickup payment using `orders.payment_status = paid` instead of changing `order_status`; and maps Pickup `claimed` → database terminal status `delivered`.
- **Reload behavior:** The screen now reads `payment_status` when loading the order so a Pickup order in `ready` can correctly show the final-payment/claim step after reopening.
- **No Supabase schema change:** The existing `order_status` enum remains unchanged.
- **Commit:** `7d6623961864694fe86b7606f1d9c9ad59521f22`.
- **Verification:** Live enum was queried directly before the code fix. Flutter runtime test is still pending.
- **Next action:** User should `git pull`, open the Owner Pickup order, advance it from Preparing → Ready to Pick Up, and confirm there is no enum error. Then mark final payment paid and confirm the next button becomes Claimed. Report the first result/error before any further edit.


### 2026-09-21 — Fixed Owner Dashboard Recent Orders Pickup tile completion detection

- **Issue:** Completed Pickup orders could still appear like active/new orders in Owner Dashboard → Recent Orders because the tile tracker did not map the real database terminal status `delivered` to the final Pickup step.
- **Root cause:** The Pickup `_trackingIndex()` handled UI-only values such as `claimed`, but the database now correctly stores the completed Pickup order as `delivered` because `order_status` has no `claimed` enum value.
- **Additional fix:** Pickup orders with database status `ready` now use `payment_status = paid` to show the `Full Payment` tracker step instead of remaining at `Ready to Pick Up`.
- **Query fix:** Recent Orders now also selects `payment_status` so the tile can determine the Pickup payment step.
- **Result:** A completed Pickup order stored as `delivered` now gets `current = 5`, which activates the existing completed-tile styling: neutral appearance, check icon, `COMPLETED` badge, and `View` button.
- **Commit:** `11ed198f2bb3235b1b7da0af554104ed0df30e9f`.
- **Testing:** Pending user runtime test.
- **Next action:** User should `git pull`, open Owner Dashboard → Recent Orders, and compare one active/new order with one completed Pickup order. The completed Pickup tile should now visibly use the completed/neutral style and `View` button.


### 2026-09-21 — Fixed Owner Pickup GCash amount-input Flutter framework exception

- **User-reported runtime error:** When the Owner starts entering the **Amount Received** in the **Confirm GCash Downpayment** dialog, Flutter throws framework exceptions including `'_dependents.isEmpty': is not true` and `Tried to build dirty widget in the wrong build scope.`
- **Likely trigger in the affected dialog:** The payment dialog used a `StatefulBuilder` even though it had no dialog-local state, while the dialog's TextEditingControllers were disposed immediately after `showDialog()` returned. This can race Android keyboard/dialog teardown while the amount field is focused.
- **Flutter fix:** Removed the unnecessary `StatefulBuilder` from the Pickup payment dialog. Validation SnackBars now use the dialog's own `dialogContext`. Controller disposal is deferred with `WidgetsBinding.instance.addPostFrameCallback` so disposal does not race the dialog/keyboard teardown.
- **Supabase changes:** None.
- **Commit:** `5ae1494bc49d3416e335357c5e9775db706bbb2f`.
- **Testing:** Not runtime-tested by ChatGPT. User must pull and test the exact GCash amount-entry flow.
- **Current stopping point:** The immediate target is the Flutter framework exception while typing the GCash Amount Received.
- **Next action:** `git pull`, open Owner Pickup → Confirm GCash Downpayment, tap **Amount Received**, type an amount (do not submit yet), and confirm the framework exception no longer appears. Report **goods** or the exact new error before any further edit.


### 2026-09-21 — Fixed Owner Pickup GCash payment_status enum error

- **User-reported error:** Owner Pickup → Confirm GCash Downpayment failed with PostgreSQL `42804`: `column "payment_status" is of type public.payment_status but expression is of type text`.
- **Root cause:** `record_owner_pickup_payment()` used a text `CASE` expression when assigning the `orders.payment_status` enum. The payment fields also relied on implicit enum conversion.
- **Supabase fix:** Updated the live `public.record_owner_pickup_payment()` function to explicitly cast payment enum values to `public.payment_status` and payment method values to `public.payment_method`.
- **Behavior preserved:** Flexible GCash downpayment remains allowed up to 100% of the order total; partial payment leaves `payment_status = pending`; full payment sets `payment_status = paid`; final pickup payment remains cash-only.
- **Verification:** Re-read the live function after the update and confirmed the explicit enum casts are present.
- **GitHub SQL documentation:** `supabase/owner_pickup_payment_and_gcash_vault.sql` updated to match the live function.
- **Supabase migration:** `fix_owner_pickup_payment_status_enum_cast`.
- **GitHub documentation commit:** `34f3a00fd1666db88f09728b87cc8116fdfdbe16`.
- **Testing:** Not runtime-tested after the database fix.
- **Next action:** No Flutter code pull is required for this backend-only fix. Repeat **Owner Pickup → Confirm GCash Downpayment → enter Amount Received + Reference Number → Accept Payment**. Report **goods** or the exact new error.


### 2026-09-21 — Added Owner Payment Breakdown + Restaurant Vault Summary

- Owner Pickup Order Details now loads actual paid payment records and displays GCash Downpayment, Cash for Pickup, Total Paid, and remaining Balance.
- Cash for Pickup is the actual cash payment received, not the remaining balance.
- Owner Dashboard now shows a Restaurant Vault near the top with actual paid Cash Vault and current GCash Vault for the selected restaurant.
- GCash Vault subtracts recorded owner GCash cashouts.
- Vault values are filtered to paid payments belonging to the selected restaurant.
- Files changed: lib/features/owner/screens/owner_order_details_screen.dart and lib/features/owner/screens/owner_dashboard_screen.dart.
- Testing: not runtime-tested by ChatGPT; user should pull and verify a Pickup order with GCash downpayment and final cash payment, then verify dashboard vault amounts.


### 2026-09-21 — Fixed Owner Vault Supabase Relationship Error
- Runtime error found in Owner Dashboard: PostgREST PGRST200 because payments has an order_id column but no foreign-key relationship to orders in the live schema.
- Verified live Supabase schema for project taltqnxhivpfwjqlvxnt.
- payments columns include order_id, amount, payment_method, status, paid_at, etc., but there is no payments.order_id -> orders.id FK.
- Updated lib/features/owner/screens/owner_dashboard_screen.dart to avoid nested payments -> orders PostgREST relation queries.
- New vault flow: first load the selected restaurant's order IDs from orders, then query paid payments using inFilter('order_id', orderIds).
- Cash Vault still sums paid cash_on_delivery; GCash Vault still sums paid gcash and subtracts owner_gcash_cashouts.
- Commit: 57192476e6528881f7d4565fe6e2a51e1a5bc535
- Runtime testing pending after git pull.


### 2026-09-21 — Fixed Pickup Order Summary Display
- Pickup order summary was showing Subtotal as ₱0 when the incoming order map did not contain a `subtotal` field.
- For Pickup, Subtotal now falls back to the order `total_amount`, representing the full order amount before subtracting GCash Downpayment and Cash for Pickup.
- Removed the redundant `Total Paid` row because the `Balance` row already communicates the remaining amount.
- Expected example: Subtotal ₱1,000; GCash Downpayment -₱800; Cash for Pickup -₱200; Balance ₱0.
- Commit: a82ef3c3cb77e8d9524b0b81ffa1cb58f515b00c


### 2026-09-21 — Fixed Customer Order Summary RenderFlex Overflow

- **User-reported error:** Customer Order Details showed `A RenderFlex overflowed by 86 pixels on the right` (and a larger overflow) around `order_details_screen.dart` line 1197.
- **Root cause:** The recent Pickup summary edit accidentally escaped Dart string interpolation as `₱\\${...}` instead of `₱${...}`. This caused the literal interpolation expression to render as text, making the summary value extremely wide and overflowing the Row.
- **Flutter fix:** Restored the five affected currency interpolations in `lib/features/order/screens/order_details_screen.dart` to normal Dart interpolation.
- **Behavior:** Pickup summary structure remains Subtotal, Downpayment, Cash for Pickup, Balance; Delivery summary remains unchanged.
- **Commit:** `1600ef4c9dbabb845a5a6867231a5b81f2bd1dc9`.
- **Testing:** Not runtime-tested by ChatGPT. User should pull and hot reload/restart, then reopen Customer Order Details and confirm the yellow/black overflow indicators are gone.


### 2026-09-21 — Fixed Customer Promo Place Order Trigger Error

- **User-reported error:** Customer Checkout with a promo failed at Place Order with: `PostgrestException(message: Customers may only update pickup receipt fields, code: P0001, ...)`.
- **Scenario:** Subtotal ₱1,400, promo discount -₱700, expected total ₱700.
- **Root cause:** `public.claim_promo_code()` is a trusted `SECURITY DEFINER` workflow that updates `orders.promo_code_id`, `promo_discount`, and `total_amount` after the order is inserted. The customer-order BEFORE UPDATE guard correctly blocked normal customer updates, but it could not distinguish this trusted promo update from a direct client update.
- **Supabase fix:** `claim_promo_code()` now sets a transaction-local flag `app.claim_promo_code = true` before its internal order update. `guard_customer_pickup_update()` recognizes that flag and allows only the promo workflow's permitted fields to remain unchanged while the promo fields are updated. Normal customer order updates remain protected.
- **Security behavior:** The flag is transaction-local and the guard still rejects changes to restaurant, customer, address, fulfillment type, subtotal, delivery fee, notes, payment status, pickup payment fields/status, receipt fields, and order status during the promo workflow.
- **Verification:** Executed the live `claim_promo_code('ab81b1d9-ef0e-44a4-ae70-138ccdadc1a3','666')` inside a transaction and rolled it back. The function successfully calculated **₱700 discount** from **₱1,400 subtotal** and produced **₱700 total**, confirming the trigger no longer blocks the trusted promo update.
- **GitHub SQL:** Updated `supabase/customer_checkout_promo_codes.sql` to match the live promo function.
- **Live Supabase functions updated:** `public.claim_promo_code(uuid,text)` and `public.guard_customer_pickup_update()`.
- **Commit:** `59f4133889b6e887a50b6f9f05e9fa837ea109b4`.
- **Flutter changes:** None required for this error.
- **Next action:** User should pull and retry Customer Checkout with the same promo. Expected result: Subtotal ₱1,400 → Promo -₱700 → Total ₱700, and Place Order should proceed.
