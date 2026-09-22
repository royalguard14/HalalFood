### 2026-09-21 — Owner Pickup Payment Summary Fixed
- User reported that the Owner Desktop **Recent Orders** status/tracking and the opened **Payment Summary** were not showing the intended Pickup flow.
- `lib/features/owner/screens/owner_order_details_screen.dart` was updated directly on `main`.
- Pickup payment summary now shows: **Subtotal (original)** → **Promo** → **GCash Downpayment (actual paid)** → **Cash for Pickup (actual paid)** → remaining **Balance**.
- When Pickup status is `Ready to Pick Up` (`orders.status = ready`), the remaining amount is labeled **Cash Balance**.
- Final cash-payment amount is calculated from the actual paid GCash and actual paid cash records, not from the requested `pickup_downpayment_amount`.
- The server RPC `record_owner_pickup_payment` remains the final authority and requires the exact remaining balance for final cash payment.
- Owner Recent Orders tracking code is present in `lib/features/owner/screens/owner_dashboard_screen.dart` with Pickup steps: **For Confirmation → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**. The local app must pull the latest `main` to receive the current dashboard code.
- **Commit:** `5938b800029a18c3d8983084003c8efc75cbdc95`
- **Testing status:** Code updated; runtime test still pending.
- **Next:** `git pull origin main`, run the Owner Desktop, open Recent Orders, verify the Pickup status timeline, then open the order and verify the payment summary and final Cash Balance.

### 2026-09-21 — Previous Customer Pickup Summary Fix
- Customer Pickup Order Summary uses original `subtotal` as **Subtotal**, not discounted `total_amount`.
- Promo is shown separately as a negative amount.
- Downpayment is based on actual approved/paid GCash payment.
- Ready to Pick Up shows the remaining Cash Balance.
- File: `lib/features/order/screens/order_details_screen.dart`


## 2026-09-21 — Owner Dashboard Pickup Recent Orders Filter
- Owner Dashboard > Recent Orders keeps Pickup orders hidden while no receipt has been uploaded/requested for approval.
- Pickup orders are shown once `pickup_downpayment_status` is `receipt_submitted` or `paid`.
- Dashboard order query now also passes `subtotal`, `promo_discount`, and `delivery_fee` to Owner Order Details so the payment summary has the original order breakdown available.
- Code commit: `dccf27aa52ce11d30ff336efefccee60af705c4d`.


## 2026-09-21 — Developer: Permanent Order Deletion

- Added live Supabase function: `public.developer_delete_order(uuid)`.
- Developer-only backend guard via `public.is_developer()`.
- Deletes connected `payments`, `promo_redemptions`, `order_items`, then the `orders` row.
- Collects `orders.pickup_receipt_path` before deletion so the app can remove the uploaded receipt from Storage bucket `payment-receipts`.
- Added `supabase/developer_order_delete.sql` to GitHub.
- Updated Developer Console → Platform Operations → Orders (existing `AdminOrderManagementScreen`) with a Developer-only **Delete Order Permanently** action and confirmation dialog.
- After the RPC deletes database records, the app removes each returned receipt path from `payment-receipts` and refreshes the order list.
- UI/backend deletion commit: `26c49a158c9923d41e6087da1d0f4d8bbdfc6c65`.
- SQL documentation commit: `32a64be1e7f1f33e1079bd1604708a3c643b328a`.
- Live Supabase function was applied directly to project `taltqnxhivpfwjqlvxnt`.


## 2026-09-21 — Correct Developer Order Deletion Location

- Corrected the previous implementation architecture: permanent order deletion is now a **Developer Console-only** feature.
- Added `lib/features/developer/screens/developer_order_management_screen.dart` for the Developer Console's **Platform Operations → Orders** module.
- Removed the permanent-delete UI and deletion methods from `lib/features/admin/screens/admin_order_management_screen.dart`; Admin Order Management no longer exposes permanent deletion.
- Updated `lib/features/developer/screens/developer_dashboard_screen.dart` so **Platform Operations → Orders** opens `DeveloperOrderManagementScreen` instead of the Admin screen.
- The Supabase RPC `public.developer_delete_order(uuid)` remains independently protected by `public.is_developer()`, so UI access is not the security boundary.
- No Owner/Customer order or payment flow was changed.
- **Previous incorrect UI commit:** `26c49a158c9923d41e6087da1d0f4d8bbdfc6c65`.
- **This correction:** Developer-only order management screen + Admin cleanup + Developer Console routing.


## 2026-09-21 — Developer Permanent Deletion Order List Fixed

- Root cause: DeveloperOrderManagementScreen was querying public.orders directly. Developer users can still be blocked by the table's normal RLS policies, so the screen could show no orders even though orders exist.
- Added live Supabase function public.developer_list_orders() as SECURITY DEFINER.
- The function independently checks public.is_developer() and returns all current public.orders ordered by created_at desc.
- public and anon execution are revoked; only authenticated can execute the RPC.
- Updated lib/features/developer/screens/developer_order_management_screen.dart to load orders through developer_list_orders() instead of direct table select.
- Renamed the Developer screen heading to Permanent Order Deletion and clarified that the displayed orders are available for permanent deletion.
- Existing developer_delete_order(uuid) remains the actual destructive backend operation and remains Developer-only.
- Live Supabase migration applied successfully.
- GitHub commits:
  - UI/RPC loading fix: f6045b1fa42102a9fbf450ec093875143d21a41a
  - SQL documentation: c3dab4ef0c1f06e2d3ebcb7b7e9adb7dc62603ae


## 2026-09-21 — Owner Dashboard Recent Orders Receipt Filter Corrected

- User clarified that Owner Dashboard > Recent Orders must NOT show Pickup orders whose downpayment receipt has not yet been uploaded/submitted.
- Root cause: the existing load-order logic already skipped such Pickup orders for counters, but the Recent Orders list incorrectly returned true for every row, so those same orders still appeared in the list.
- Fixed lib/features/owner/screens/owner_dashboard_screen.dart.
- Recent Orders now excludes Pickup orders unless pickup_downpayment_status is receipt_submitted or paid.
- Delivery orders are unaffected.
- Commit: 06619c24b156b97d7fa821330f46f5360f792fc7.


## 2026-09-21 — Customer Pickup Order Summary Cash/Balance Fix

- User reported that after Pickup reached **Full Payment**, Customer Order Summary still showed a green **Cash Balance** instead of the actual cash paid.
- Fixed `lib/features/order/screens/order_details_screen.dart`.
- Customer Order Summary now loads actual paid `cash_on_delivery` payments from `payments` and displays them as **Cash**.
- The final **Balance** is calculated as total amount minus approved GCash downpayment minus actual cash paid; when `payment_status = paid`, it is explicitly **₱0.00**.
- The old **Cash Balance** row is no longer used for the Pickup summary.
- Cash amount is refreshed after realtime order updates so the summary reflects the owner's final cash payment.
- GitHub commit: `3a579747932ce6e8edbbeb1562b23ef2d0bde6ab`.
- **Next:** pull `origin/main`, open the Customer Pickup Order Details, and verify **Cash = actual cash paid** and **Balance = ₱0.00** after Full Payment.


## 2026-09-21 — Customer Cash Payment Was Hidden by Payments RLS

- Follow-up testing showed the Customer Order Summary code was already querying actual paid `cash_on_delivery` payments, but the Customer could not read `public.payments` because the table only allowed Admins and Restaurant Owners to SELECT payment rows.
- Added a secure Supabase RLS SELECT policy: **Customers can view own payment records**.
- The policy only exposes payment rows whose `order_id` belongs to an order where `customer_id = auth.uid()`; it does not expose other customers' payments.
- This allows the existing Customer Order Summary to display the actual cash amount paid and calculate the final Balance as **₱0.00** after full payment.
- Live policy verified in `pg_policies` after creation.
- Customer UI code commit remains: `3a579747932ce6e8edbbeb1562b23ef2d0bde6ab`.
- **Next:** pull `origin/main` if needed, restart the app, open the same Full Payment Pickup Order, and verify the **Cash** row now shows the actual cash payment.


## 2026-09-21 — Customer Pickup Downpayment Tile Hidden After Confirmation

- User requested that on the Customer Order Details screen, once the Pickup downpayment is confirmed (`pickup_downpayment_status = paid`), the bottom **Pickup Downpayment / payment confirmation** tile should disappear.
- Updated `lib/features/order/screens/order_details_screen.dart` so `_buildPaymentStatus()` returns `SizedBox.shrink()` when the Pickup downpayment status is `paid`.
- The **Order Summary** remains visible and continues to show the confirmed Downpayment, actual Cash paid, and Balance.
- Delivery payment display is unchanged.
- Commit: a1fdb8e6d4f24f4ef397a9bd5b3b5b18dfa44bff.

### 2026-09-21 — Developer Restaurant Control + Cash/GCash Vault Manipulation

- Developer Console → Platform Operations → Restaurants now has a **Restaurant Control • Cash & GCash Vault** entry for each restaurant.
- Added `lib/features/developer/screens/developer_restaurant_control_screen.dart`.
- The selected restaurant control screen shows two vaults:
  - **Cash Vault** = paid cash-on-delivery payments + developer adjustments.
  - **GCash Vault** = paid GCash payments + developer adjustments − existing GCash cashouts.
- Developer can manipulate either vault using a signed adjustment:
  - positive amount = add funds
  - negative amount = subtract funds
  - a reason/notes field is recorded
- Added live Supabase table `public.developer_restaurant_vault_adjustments`.
- Added protected RPC `public.developer_record_vault_adjustment(uuid,text,numeric,text)`, guarded by `public.is_developer()`.
- RLS/grants were added so Developers can view adjustment history and restaurant Owners can view adjustments belonging to their own restaurant.
- Added a Developer SELECT policy for existing `owner_gcash_cashouts` so the Developer Restaurant Control screen can display existing GCash cashouts.
- Owner Dashboard vault summary now includes Developer vault adjustments.
- Owner GCash Vault balance now includes Developer GCash adjustments.
- Existing `record_owner_gcash_cashout` remains Owner-only; Developer manipulation uses the separate audited adjustment table/RPC.
- Updated `developer_delete_restaurant(uuid)` so permanent restaurant deletion also removes `owner_gcash_cashouts` and developer vault adjustments.
- GitHub commits:
  - `0592cdc595c92317bd2d301bfca63ee9e2cb88bc` — Developer Restaurant Control screen
  - `ef8e0f1b7ae494ea9d1d2eaf68f63202574eeb4b` — Restaurants list entry point
  - `69169e50c4c11c51e7cbad5a1a1acf5895a0f5d5` — Owner GCash Vault balance update
- Live Supabase changes were applied and verified by querying the new RPC/table and RLS policies.
- **Next:** pull `origin/main`, open Developer Console → Platform Operations → Restaurants, select a restaurant's **Restaurant Control • Cash & GCash Vault**, and test a small positive/negative adjustment. Verify the Owner Dashboard/GCash Vault reflects the adjustment.
### 2026-09-22 — Current Checkpoint: Pickup Flow Before New Features

- The last Owner ↔ Customer feature work was the **Pickup order/payment flow**.
- The latest Pickup fixes covered:
  - Customer Pickup Order Summary: original **Subtotal**, separate **Promo**, actual approved/paid **GCash Downpayment**, actual **Cash**, and remaining **Balance**.
  - Owner Recent Orders Pickup tracking: **For Confirmation → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**.
  - Pickup orders are hidden from Owner Recent Orders until the downpayment receipt is submitted/paid.
  - Customer can read their own payment records through the new secure `payments` RLS policy.
  - Customer Pickup Downpayment confirmation tile disappears after `pickup_downpayment_status = paid`.
- Pickup runtime testing was still pending at the last checkpoint.

### 2026-09-22 — Developer Restaurant Vault UI Polish

- Developer Console → Platform Operations → Restaurants now uses compact side-by-side **Control** and **Delete** buttons on each restaurant card.
- **Control** opens the Developer Restaurant Control screen for Cash/GCash Vault.
- **Delete** remains the permanent restaurant deletion action with its existing confirmation and backend protection.
- Developer Restaurant Control now has:
  - **Adjust Vault** for signed Cash/GCash adjustments with notes.
  - **Clear Entire Vault** in a compact Danger Zone section.
- `developer_clear_entire_vault` removes Developer vault adjustment records and Owner GCash cashout records while preserving Orders, Payments, and Restaurant data.
- Important: the Vault's **Received** amount is derived from historical paid Orders/Payments, so clearing vault adjustment/cashout records does not erase historical order/payment totals.
- Latest UI commits:
  - `8f5d0baea5ee382ab533975ee6d0ec690e6c393e` — Developer Restaurant Control UI polish.
  - `d8ac0b009b674c7cfc7a20a955f34eb9e584bd1a` — compact Restaurants Control/Delete buttons.

### 2026-09-22 — Next Testing Checkpoint

- Before adding another major feature, test the complete flow end-to-end:
  1. Developer → Restaurants → **Control**.
  2. Add a small Cash/GCash vault adjustment.
  3. Open the Owner side and verify the corresponding vault balance/adjustment.
  4. Test **Clear Entire Vault**.
  5. Verify adjustment/cashout records are cleared while Orders/Payments remain intact.
  6. Separately finish runtime testing of the Owner ↔ Customer **Pickup** flow and its payment summary.
- Do not delete real Orders/Payments during this test unless intentionally testing the Developer permanent-delete feature.

### 2026-09-22 — Delivery Payment Model Confirmed

For **Delivery**, the required downpayment is calculated from the **entire order total (food + delivery fee)**.

Example:
- Food subtotal: **₱2,000**
- Delivery fee: **₱135**
- Total order: **₱2,135**
- Required DP: **50%**
- Customer DP: **₱1,067** (example rounded amount)
- Remaining balance: **₱1,068**

The remaining ₱1,068 already includes the delivery fee:
- **₱933** = remaining amount needed to complete the ₱2,000 food payment at the restaurant.
- **₱135** = delivery fee.

Rider flow:
1. Customer pays **₱1,067 DP**.
2. Rider goes to the restaurant and advances **₱933**.
3. Restaurant has received **₱1,067 + ₱933 = ₱2,000** for the food.
4. Rider delivers the order.
5. Customer pays the rider **₱1,068 only**.
6. That ₱1,068 consists of **₱933 reimbursement to the rider + ₱135 delivery fee**.
7. Customer's total out-of-pocket is exactly **₱1,067 + ₱1,068 = ₱2,135**.

**Important rule:** Never add the ₱135 delivery fee again on top of the remaining balance. The delivery fee is already included in the remaining balance.

Delivery is therefore different from Pickup mainly in the final collection flow: for Delivery, the rider advances the remaining restaurant food amount and collects the customer's remaining balance (which already contains the delivery fee) upon delivery.


### 2026-09-22 — Restaurant Search Radius Separated and Applied

- Admin now has two separate distance settings in **Delivery Pricing**:
  - **Restaurant Search Radius** = maximum distance from the customer's saved location for restaurant discovery.
  - **Maximum Delivery Distance** = maximum distance from restaurant to delivery address; this remains separate and is NOT changed by this step.
- Live delivery_pricing_settings has restaurant_search_radius_km with the current configured value verified separately from maximum_delivery_distance_km.
- Fixed the existing RPC public.get_customer_restaurant_radius_km() so it now reads restaurant_search_radius_km instead of incorrectly reading maximum_delivery_distance_km.
- Updated lib/features/home/screens/home_screen.dart so Customer Home filters restaurants by the customer's saved/default address GPS coordinates and the configured Restaurant Search Radius.
- Restaurants with valid coordinates beyond the configured search radius are no longer shown in Customer restaurant discovery.
- Restaurants without valid GPS coordinates are excluded when a valid customer location is available, because their distance cannot be safely determined.
- If the customer has no valid saved GPS location, the app does not apply the GPS radius filter yet.
- **GitHub commit:** b757532f24c9ccdb779221474742612badf529cc.
- **Live Supabase migration:** use_restaurant_search_radius_for_discovery applied successfully.

### Next Plan — Maximum Delivery Distance

1. Keep **Restaurant Search Radius** responsible only for which restaurants appear in Customer discovery.
2. Create/use a separate value/RPC for **Maximum Delivery Distance** so Delivery eligibility checks the restaurant-to-delivery-address distance only.
3. Do not reuse public.get_customer_restaurant_radius_km() for Delivery eligibility after this separation.
4. Trace the current Delivery enable/disable logic and replace its old radius source with the dedicated Maximum Delivery Distance value.
5. Verify with the current Admin values before changing them; do not assume the configured Maximum Delivery Distance is 20 KM.
6. Test the original case where the restaurant was about 13.4 KM away and Delivery was disabled even though the intended Maximum Delivery Distance was higher.
7. After that, test Delivery checkout and server-side eligibility to ensure the same distance rule is enforced securely.


### 2026-09-22 — Maximum Delivery Distance Separated from Restaurant Search Radius

- Kept the already-working Restaurant Search Radius logic unchanged.
- Added dedicated Supabase RPC: `public.get_maximum_delivery_distance_km()`, which reads only `maximum_delivery_distance_km`.
- Updated `lib/features/home/data/restaurant_repository.dart` with `getMaximumDeliveryDistanceKm()`.
- Updated `lib/features/checkout/screens/checkout_screen.dart` so Delivery eligibility loads the dedicated Maximum Delivery Distance instead of reusing `getCustomerRestaurantRadiusKm()`.
- Server-side `public.calculate_delivery_fee(restaurant_id, address_id)` was inspected and already enforces `maximum_delivery_distance_km`; no change was made to that working backend logic.
- Verified live Supabase values after the change:
  - Restaurant Search Radius = **15.00 KM**
  - Maximum Delivery Distance = **15.00 KM**
- GitHub commits:
  - `7fe12051a383adbcbd3863523041e92a2a48217d` — repository method.
  - `2cbdebc107b950686802a6ffcd413dfeba797e46` — Checkout uses Maximum Delivery Distance.
- Next: runtime-test Customer Checkout with a restaurant/address distance below and above the configured Maximum Delivery Distance. Do not change the already-working Restaurant Search Radius code.


### 2026-09-22 — Customer Delivery Downpayment Implementation Started

- Customer Checkout now applies the configured downpayment percentage to Delivery as well as Pickup.
- Delivery downpayment base is food subtotal + delivery fee - promo discount. Current configured percentage is loaded through the existing pickup downpayment setting (currently 50%).
- Delivery order creation now stores the downpayment amount/status in the existing downpayment fields and creates a pending online payment record, mirroring the working Pickup implementation.
- Customer Checkout now shows a Delivery Downpayment card and explains that the remaining balance already includes the delivery fee.
- Customer Order Details now supports the same GCash receipt flow for Delivery: pending -> receipt submitted -> paid.
- Added secure live RPC public.submit_delivery_downpayment_receipt(p_order_id, p_receipt_path) for Delivery receipt submission. It checks auth.uid(), order ownership, fulfillment type, and allowed receipt states.
- Verified the new RPC: anon cannot execute it; authenticated can execute it.
- Customer Order model now exposes promo_discount so summaries can show the actual promo separately.
- Runtime test is still pending. Next: pull latest main, run Customer Delivery checkout, verify Subtotal + Delivery Fee - Promo = Total, verify 50% Delivery Downpayment, place the order, open Customer Order Details, and verify the Delivery Downpayment GCash/QR receipt upload flow. Do not move to Owner yet until this Customer flow is verified.


### 2026-09-22 — Customer Delivery Downpayment Success Screen Corrected
- User caught that after placing a Delivery order, the app showed the generic **Order Placed!** success state instead of immediately directing the customer into the downpayment flow.
- Updated `lib/features/checkout/screens/checkout_screen.dart`.
- `OrderSuccessScreen` now treats any order with a required downpayment amount as a **Downpayment Required** state for both Pickup and Delivery.
- It shows the applicable **Pickup Downpayment** or **Delivery Downpayment** amount and a **Continue to Downpayment** button that opens Customer Order Details where the GCash/receipt flow is handled.
- Generic **Back to Home** remains available as **Do This Later** for downpayment orders.
- Pickup flow was preserved; the change generalizes the existing working Pickup success behavior to Delivery.
- **Commit:** `a8b51b743bd5624a23ea45d4112a852dff7f7b6f`
- Next: `git pull origin main`, place a Delivery order again, and verify it lands on **Downpayment Required → Continue to Downpayment** instead of the generic success state.


### 2026-09-22 — Customer Delivery Tracking + Owner GCash Information

- User completed Customer Delivery downpayment receipt submission and requested finishing the Customer side before moving to Owner.
- Updated `lib/features/order/screens/order_details_screen.dart`.
- Customer Delivery Order Tracking now shows the agreed full status sequence:
  **For Confirmation → Confirmed → Preparing → Ready for Pickup → Rider Assigned → Rider Going to Restaurant → Rider at Restaurant → Full Payment → Picked Up → Out for Delivery → Delivered / Cash Collected → Completed**.
- Added status normalization/index handling for these delivery states and common stored aliases, while preserving the existing Pickup tracking flow.
- Added a dedicated Customer **GCash Information** card on Order Details using the restaurant owner's existing `gcash_name`, `gcash_number`, and `gcash_qr_url`.
- The GCash Information card is separate from the downpayment upload card, so the owner's GCash details remain visible on the customer order details screen when configured.
- GitHub commit: `32145bc4f1f2bdf5aab4302888adcd762cf37c69`.
- Next: pull latest `main`, runtime-test the Customer Delivery tracking and GCash Information display. Do not move to Owner until Customer side is confirmed complete.


### 2026-09-22 — Owner GCash Information for Customer Downpayment

- User clarified that GCash setup should be handled first on the **Owner side**, because the Owner's GCash details must appear on the Customer's downpayment requirement screen.
- Verified that `public.restaurants` already has `gcash_name`, `gcash_number`, and `gcash_qr_url` columns.
- Verified restaurant-owner UPDATE RLS exists for the restaurant record and Storage policies already allow owners to upload/update files under their restaurant folder in `restaurant-images`.
- Updated `lib/features/owner/screens/owner_restaurant_profile_screen.dart`.
- Owner Restaurant Profile now has a proper **GCash Information** section with:
  - GCash Account Name
  - GCash Number
  - Upload/Replace GCash QR
  - Preview of the saved GCash QR
- The section explicitly tells the Owner that customers will see these details on the downpayment requirement screen.
- Removed the misplaced old GCash form that was accidentally inside the error-state UI; GCash settings now appear in the normal Owner Restaurant Profile form.
- GitHub commit: `1085924458937f8500efbb92fb15643f416b942f`.
- Next: pull and test Owner GCash Information first. After confirming the Owner can save/upload the details, verify the Customer downpayment requirement screen displays the same Owner GCash information.


### 2026-09-22 — Owner GCash Displayed on Customer Downpayment Required Screen

- Updated `lib/features/checkout/screens/checkout_screen.dart` in the existing `OrderSuccessScreen`.
- The Customer **Downpayment Required** screen now loads the restaurant attached to the newly created order and displays the Owner's saved GCash information directly on that screen:
  - GCash Account Name
  - GCash Number
  - GCash QR Code
- The GCash section appears only when the restaurant has GCash information configured; otherwise the existing downpayment screen remains unchanged.
- The existing **Continue to Downpayment** and receipt-upload flow was preserved.
- GitHub commit: `4f0d44d3f32f09675e5abed5c54e591700b616e9`.
- Next: `git pull origin main`, place a new Pickup or Delivery downpayment order, and verify the Owner's GCash details appear on the **Downpayment Required** screen before continuing to receipt upload.


### 2026-09-22 — Pickup GCash Clarification on Downpayment Required Screen

- Updated the same Customer `OrderSuccessScreen` so the GCash section is explicitly labeled according to the fulfillment type: **Pickup GCash Information** or **Delivery GCash Information**.
- The instruction also now identifies whether the displayed GCash account is for the Pickup or Delivery downpayment.
- This confirms the same Owner GCash details are presented for both Pickup and Delivery downpayment orders.
- Existing payment and receipt-upload behavior was not changed.
- GitHub commit: `9bef9e78ec781d59d8f3fec67c5c1ede4dc8f237`.


### 2026-09-22 — Owner Delivery Flow Corrected

- Updated `lib/features/owner/screens/owner_order_details_screen.dart` so Owner Order Details now uses a shared horizontal order-flow tracker for Pickup and Delivery.
- Pickup flow: **For Confirmation → Confirmed → Preparing → Ready to Pick Up → Full Payment → Claimed**.
- Delivery flow: **For Confirmation → Confirmed → Preparing → Ready for Pickup → Rider Assigned → Rider Going to Restaurant → Rider at Restaurant → Full Payment → Picked Up → Out for Delivery → Delivered / Cash Collected → Completed**.
- Delivery action flow was corrected so it no longer jumps from **Preparing → Completed**. Owner can move Delivery through **Confirm Order → Preparing → Ready for Pickup**; after Ready for Pickup, the order is handed to the rider flow instead of being incorrectly completed by the Owner.
- The existing shared downpayment receipt/payment review card remains above the order items for both Pickup and Delivery, including **View Receipt / Reject / Accept** when a receipt is submitted.
- Horizontal tracker is scrollable so the complete Delivery sequence remains readable on smaller screens.
- **GitHub commit:** aeaf24f6fe63ad92d105983724d34f4434598d32
- Next: pull latest `main` and runtime-test one Pickup and one Delivery order in Owner Order Details. Verify Delivery starts at **For Confirmation**, receipt review works, then **Confirmed → Preparing → Ready for Pickup**, and that it does not incorrectly mark the delivery as completed.


### 2026-09-22 — DELIVERY/RIDER MASTER PLAN (LOCKED BEFORE IMPLEMENTATION)

**Important:** This section is the working plan for the next Delivery/Rider build so we do not repeat or change the agreed flow accidentally.

#### Delivery responsibility boundary

**Owner responsibility ends at Out for Delivery.**
Owner flow:
**For Confirmation → Confirmed → Preparing → Ready for Delivery → Rider Assigned → Rider at Restaurant → Full Payment → Out for Delivery**

- At **Rider Assigned**, the order enters the Rider queue.
- Owner does not manage the rider's travel to the restaurant.
- At **Rider at Restaurant**, Owner records the actual amount received from the Rider for the restaurant food payment.
- Owner must accept/confirm **Full Payment** before the order can move to **Out for Delivery**.
- Once **Out for Delivery**, Owner has **no further action**. Owner only sees the order as ongoing/Out for Delivery.
- Owner does NOT manually mark the order Completed.
- When Rider later completes the delivery cycle, the final backend order state becomes **Completed**, which must reflect on Owner + Customer + Rider.

#### Rider responsibility

Rider flow:
**Rider Assigned → Take Order → Rider Going to Restaurant → Rider at Restaurant → Picked Up → Out for Delivery → Delivered / Cash Collected → Completed**

- Rider queue appears when Owner reaches **Rider Assigned**.
- Rider can **Take Order** to claim an available delivery.
- Rider screen must calculate/display the amount the Rider needs to advance to the restaurant.
- Rider must NOT be required to manually calculate this amount.
- After pickup, Rider proceeds to **Out for Delivery**.
- At delivery, Rider sees the exact customer collection amount.
- Rider records the customer payment / cash collection.
- After successful collection, Rider can mark **Completed**.
- Rider completion is the final event that completes the entire order cycle.

#### Customer display flow

Customer must see:
**For Confirmation → Confirmed → Preparing → Ready for Pickup → Rider Assigned → Rider Going to Restaurant → Rider at Restaurant → Picked Up → Out for Delivery → Delivered / Cash Collected → Full Payment → Completed**

- Customer must NOT see the internal Rider → Owner restaurant payment as a customer-facing payment step.
- The internal Rider → Owner payment happens before Owner allows Out for Delivery.
- Customer's final Full Payment display happens after Delivered / Cash Collected according to the agreed customer-facing sequence.
- When Rider completes the order, Customer sees **Completed**.

#### Delivery payment rules

- Customer Delivery Downpayment is based on the configured percentage of the final order total.
- Remaining Balance already includes the Delivery Fee. **Never add the Delivery Fee again.**
- Rider's restaurant advance = the remaining food amount that still needs to be paid to the restaurant.
- Rider's customer collection = the customer's remaining Balance, which already includes the Delivery Fee.
- Owner Full Payment records the actual amount received from Rider.
- Rider final collection records the actual amount received from Customer.
- Payment amounts must be validated server-side; do not trust client-calculated values.

#### Rider account / approval requirements

Current state:
- **No Rider account has been created yet.**
- **No Rider screen exists yet.**
- There is currently **no Rider Instant Login button**.
- The database already has the `driver` role in the existing `user_role` enum.
- The existing `identity_verifications` table already supports role `driver`, ID document, selfie-with-ID, pending/approved/rejected status, reviewer, and rejection reason.

Required Rider onboarding:
1. Rider registers/creates an account using the existing member/identity-verification approach.
2. Rider submits valid ID + selfie with ID.
3. Admin must review the submitted verification.
4. Rider must be **approved** before Rider functions/screens can be used.
5. Rejected Rider verification must not unlock Rider operations.
6. We will reuse the existing secure approval pattern where appropriate rather than creating a parallel unsafe role system.

#### Rider Instant Login

- Add a temporary Developer/Testing-only **Instant Login → Rider** option.
- This is only for development/testing, matching the existing temporary role shortcuts.
- It must not bypass the real Rider approval rules for normal Rider accounts.
- The Rider test account must be an actual Rider/driver-role account so the Rider screen and RLS can be tested correctly.

#### Implementation order

1. Inspect existing member registration/identity approval code and admin approval flow.
2. Inspect current role/authorization and confirm how `driver` is assigned safely.
3. Design the Rider data model and secure RLS/RPC transitions before building the Rider UI.
4. Add Rider account/approval support where missing.
5. Add temporary Rider Instant Login.
6. Build Rider queue + Take Order/claim flow.
7. Build Rider order screen and delivery status transitions.
8. Add secure Rider → Restaurant payment/advance tracking.
9. Add Owner Full Payment checkpoint before Out for Delivery.
10. Add Rider customer collection and final Completed action.
11. Update Customer Delivery tracking to the agreed display sequence without changing Pickup.
12. Runtime-test the complete Delivery flow end-to-end.
13. **PICKUP SCREEN = LOCKED.** Do not modify Pickup UI, payment, receipt, status flow, summary, buttons, or logic while implementing Rider/Delivery.

#### Current database facts verified before implementation

- `public.order_status` currently contains:
  `pending`, `confirmed`, `preparing`, `ready`, `out_for_delivery`, `delivered`, `cancelled`, `refunded`.
- There are currently no Rider-specific tables/functions found by the existing Rider search.
- Existing `profiles.role` uses `user_role`.
- Existing `identity_verifications.role` already includes `driver`.
- Existing Delivery/Pickup downpayment fields are currently shared in `orders`; Rider-specific settlement data should be designed separately rather than overloading Pickup behavior.
