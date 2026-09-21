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
- **Commits:** `e600d784b7a801a6752f724b7a52b513b4bac04e`, `116e66caccaa4e2b5543bd9e1ebb3c1d52091ecc`, `ba52d772e9ee7aa7785d94776c5a727390465eff`, `30a0d5514b4966b32ffd7fa8d64cc6d9e5052578`, `28d5feec71d2ef161265545eba4b4be47b2cdfc9`, `d8e4ef69e575661c0fdfb93f18c8a2600e97eeea`, `b6a9c0d31b5d2f83ad65ea421ab3c0b3e469bb7d`, plus Edge Function `cleanup-pickup-receipts` deployment.
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
- **Latest completed development:** Customer Checkout Promo/Coupon UI was changed from multiple promo tiles to a scalable **dropdown**. Selecting a promo shows its description/details below; minimum-order-invalid promos are disabled.
- **Promo behavior to preserve:** Customer sees active Admin/global promos plus promos belonging to the current restaurant. Each promo can be redeemed **once per customer**. After successful redemption it disappears from that customer's available list. Server-side RPC enforcement prevents reuse even if the client is manipulated. Promo redemption is only consumed after successful order creation/claim.
- **Latest relevant code commit:** `492df41356468913c774a2f9316676d09f506f20`.
- **Latest documentation commit before this handoff update:** `3735e958ab6692bd7582cdaa87b7b66102df12dc`.
- **Testing status:** The dropdown change has **NOT yet been confirmed by the user's latest local `flutter analyze`/runtime test**. Do not mark it passed until the user reports the result.
- **User workflow preference:** Make changes directly in GitHub when possible. After a code change, update this file, tell the user to `git pull`, give the exact next test, and wait for the user's result before moving on. Do not jump ahead.
- **Important:** Do not edit the deleted duplicate `lib/features/order/screens/checkout_screen.dart` for Customer Checkout. The real Cart → Checkout route is `lib/features/checkout/screens/checkout_screen.dart`.

## NEXT WORK ORDER — FOLLOW THIS SEQUENCE

### STEP 0 — Finish current Promo/Coupon verification
1. User runs:
   `git pull`
   `flutter analyze`
2. Test Customer → Restaurant → Add Food → Cart → Checkout.
3. Verify:
   - Promo/Coupon is a dropdown, not many tiles.
   - Available Admin/global + restaurant-specific promos appear.
   - Invalid minimum-order promos are disabled.
   - Selecting a promo shows its description/details below.
   - Order Summary shows Promo Discount and reduced Total.
4. Place an order and verify redemption.
5. Re-open Checkout with the **same customer** and confirm the redeemed promo is no longer available. A server-side duplicate-use attempt must also be rejected.
6. Only after user confirms success should this be marked PASSED.

### STEP 1 — Checkout EDIT 2: Delivery validation + real delivery-fee computation
Do this **after Step 0 passes**.
- Preserve the existing Pick-up / Delivery selector.
- Delivery must require a saved address with valid latitude/longitude.
- Validate that the delivery location is within the restaurant's allowed maximum distance.
- Keep the existing real delivery-fee calculation; do not replace it with hardcoded pricing.
- Show a clear customer-facing validation message when the location is missing, invalid, or out of range.
- Do not allow an invalid Delivery order to reach successful order creation.
- Pick-up must not require a delivery address or delivery fee.
- Re-test Pickup and Delivery after the change.

### STEP 2 — Checkout EDIT 3: Payment method + payment-state rules
- Customer chooses fulfillment before payment.
- **Pick-up:** initial policy target is minimum **50% prepayment** before restaurant preparation; remaining balance can be settled at pickup according to restaurant configuration.
- **Delivery:** initial policy target is online payment before preparation/rider pickup.
- Do not globally enable COD yet.
- If COD is added later, it must be explicitly enabled per restaurant and protected by eligibility/order/area controls.
- Payment states to support: `pending`, `processing`, `paid`, `failed`, `cancelled`, `refunded`, `partially_paid`.
- Never mark an order `paid` merely because the customer pressed a button.
- Prefer platform-controlled payment/confirmation and settlement; do not build around customers manually paying restaurant personal GCash/Maya/bank accounts.
- Backend must be authoritative for payment status.

### STEP 3 — C8.5 / C8.6 edge-case testing
After payment/fulfillment implementation:
- **C8.5 Invalid Delivery Location:** test missing GPS, invalid coordinates, and out-of-range location. Order must be blocked.
- **C8.6 Failed Order/Payment:** test failure/rollback. No false `paid` state, no orphaned order/payment, and promo redemption must not be consumed when the order/payment fails.
- Re-test the normal Customer → Owner order flow after these changes.

### STEP 4 — Remaining Admin audit
- Continue the broader Admin audit after the immediate Checkout work, unless a blocking Admin issue appears first.
- KYC Admin flow is already implemented: Pending/Approved/Rejected, signed image review, zoom/pan, Approve/Reject with reason, immediate list update and rejected-history cleanup.
- Developer KYC is view-only; Developer must not approve/reject.
- Do not mark Admin 100% complete until remaining Admin modules/checks are actually tested.

### STEP 5 — Backend / Security Hardening
Known remaining security-audit items:
- SECURITY DEFINER functions needing review: `calculate_delivery_fee`, `expire_restaurant_subscriptions`, `handle_new_user`, `is_admin`.
- Mutable search_path findings: `set_promo_codes_updated_at`, `update_updated_at`, `update_updated_at_column`, `set_app_settings_updated_at`, `set_payments_updated_at`, `set_subscription_updated_at`.
- Missing FK indexes.
- Duplicate/redundant indexes.
- Auth leaked-password protection.
- `delivery_pricing_settings` RLS is deliberate and should be reviewed, not changed blindly.
- Developer restaurant deletion still has an open **external Storage cleanup** concern.
- Do not mix unrelated security changes into a feature test unless necessary to unblock it.

### STEP 6 — Driver / Delivery operational implementation
Current Driver dashboard is still placeholder/UI-only:
- online/offline toggle is UI-only
- Today/Earnings/Completed are placeholders
- Current Delivery/My Deliveries/Earnings/Delivery Map/My Profile are placeholders
- no real assignment/location/earnings persistence yet
This remains future work after the current Customer/Admin/payment sequence.

## CURRENT STATE SNAPSHOT FOR NEXT GPT

### Customer
- C0 KYC routing/verification: previously PASSED.
- C1 Profile & Account: PASSED.
- C2 Addresses + GPS: PASSED.
- C3 Restaurant Discovery/filter/menu: PASSED.
- C4 Cart: PASSED.
- C5 Checkout/place order: previously PASSED, but **must be revalidated after current Promo/Coupon + fulfillment/payment changes**.
- C6 Orders: PASSED.
- C7 Realtime: PASSED.
- C8.1 Empty Cart: PASSED.
- C8.2 No Address: PASSED.
- C8.3 Restaurant Unavailable: PASSED.
- C8.4 Expired Subscription: PASSED.
- C8.5 Invalid Delivery Location: NOT IMPLEMENTED / NOT TESTED.
- C8.6 Failed Order/Payment: NOT IMPLEMENTED / NOT TESTED.
- In-restaurant menu search is NOT currently a feature; do not treat that as a bug unless intentionally added later.

### Checkout
- Real Customer Checkout file: `lib/features/checkout/screens/checkout_screen.dart`.
- Fulfillment choice exists: Pick-up / Delivery; neither is preselected initially.
- Delivery address section appears only for Delivery.
- Pickup hides Delivery Fee in Order Summary.
- Existing DistanceUtils delivery computation is preserved.
- Promo/Coupon dropdown is the latest UI.
- Order Summary supports Promo Discount and reduced Total.
- OrderRepository claims the promo server-side after creating order/order_items and rolls back the new order if promo claim fails.

### Promo/Coupon backend
- `public.promo_codes` already existed.
- `public.orders` has `promo_code_id` and `promo_discount`.
- `public.promo_redemptions` enforces unique `(promo_code_id, customer_id)`.
- `claim_promo_code(p_order_id, p_code)` is SECURITY DEFINER with pinned search_path and validates restaurant scope, active dates, minimum order, usage limit, one-use-per-customer, discount rules.
- `sync_promo_usage_count()` keeps usage_count synchronized.
- Customer available promos exclude already redeemed promo IDs.
- Relevant migration docs: `supabase/customer_checkout_promo_codes.sql`.

### KYC
- Private bucket: `identity-verifications`.
- Customer/Driver/Owner submit government ID + selfie with ID.
- Admin approves/rejects; rejection requires reason.
- Developer can view but not approve/reject.
- Signed URLs are used for review; bucket remains private.
- Rejected submissions are cleaned when resubmitted.
- Older rejected history is cleaned after approval.
- Developer can permanently delete verification row + files.
- Real government IDs/selfies must never be committed to GitHub/public storage.

### Owner
- Core Tests 1–4 PASSED:
  1. Owner subscription.
  2. Admin receives/approves request.
  3. Owner after approval.
  4. Customer order received by Owner and lifecycle Pending → Preparing → Ready.

### Roles / routing
- Roles: customer, restaurant_owner, admin, developer, driver.
- No verifier role.
- Startup routing goes through Splash.
- Developer → Developer Dashboard.
- Admin → Admin Dashboard.
- Owner → Owner Restaurant Selection.
- Driver → Driver Dashboard.
- Customer/unknown → Customer Home after KYC gate where applicable.
- Login now routes through Splash so KYC gating is centralized.

### Project / environment
- GitHub: `royalguard14/HalalFood`
- Local: `D:\FlutterApps\HALAL\halalfood`
- Flutter stable: 3.47.0
- Flutter binary: `D:\src\flutter\bin\flutter.bat`
- Android emulator: Pixel_8 / `emulator-5554` / Android API 37
- Supabase project: `taltqnxhivpfwjqlvxnt`
- `.env` exists; never commit secrets/service-role keys.
- User prefers direct code/repo edits and one-test-at-a-time progression.

## STOPPING POINT
The user is ending this session. **Do not start the next feature in this session.** The only remaining immediate action is to finish documenting the handoff in `chat-gpt.md`.

**When the next ChatGPT session starts, first read `chat-gpt.md`, then continue from STEP 0. Do not ask the user to repeat the project history.**

### 2026-09-18 — Changed Checkout Promo/Coupon UI from tiles to dropdown

- **User request:** The previous Promo/Coupon section used one large tile/card per promo. Since a restaurant may have many promos, the user requested a compact dropdown instead, with the selected promo's description shown below it.
- **File changed:** `lib/features/checkout/screens/checkout_screen.dart`
- **UI change:** Replaced the multi-tile promo list with a single **Select Promo / Coupon** dropdown. Each available promo appears as a compact option showing its title, code and discount label.
- **Selected promo details:** After a promo is selected, a separate card appears directly below the dropdown showing the promo title, code, discount label, description (when provided), minimum-order requirement and calculated discount.
- **Validation:** Promos whose minimum-order requirement is not met are disabled in the dropdown. Existing refresh/no-promos behavior remains.
- **Backend/Supabase:** No changes. Existing one-use-per-customer redemption and server-side promo claim logic remains intact.
- **Order Summary:** Existing Promo Discount row and discounted Total remain unchanged.
- **Testing:** Code change committed; Flutter analyzer/runtime retest is still pending.
- **Commit:** `492df41356468913c774a2f9316676d09f506f20`
- **Current stopping point:** Checkout Promo/Coupon is now compact and scalable for many promo codes.
- **Next immediate test:** `git pull` → `flutter analyze` → open Checkout → verify the dropdown lists promos, select one, confirm its description appears below, and confirm Order Summary still shows the discount and reduced total.

### 2026-09-18 — Fixed remaining My Cart Total-panel 4px overflow

- **User test result:** The My Cart footer still overflowed by 4px on the **Total** side. Flutter reported the inner Total Column constrained to 44px high inside the fixed 64px panel with 10px top/bottom padding.
- **File changed:** `lib/features/cart/screens/cart_screen.dart`
- **Root cause:** Even with `mainAxisSize: MainAxisSize.min`, the Total panel's vertical padding left too little content height for the two text rows plus spacing.
- **Fix:** Reduced the Total panel's vertical padding from 10px to 6px while retaining the 64px footer height. This gives the content more vertical room without changing the overall footer size.
- **Supabase changes:** None.
- **Testing:** User reproduced the 4px overflow; runtime verification of this new fix is still pending.
- **Commit:** `3b971082ab8dfa499c1ce72792271a7bce541424`
- **Current stopping point:** Cart Total-panel sizing has been adjusted again. Do not mark it runtime-fixed until the user retests.
- **Next immediate test:** `git pull` → run/restart the app → open **My Cart** → confirm there is no yellow/black overflow warning. If clean, test **Proceed to Checkout**.

### 2026-09-18 — Fixed My Cart Total footer 4px overflow

- **User-reported runtime issue:** My Cart now opens, but the Total panel produced a 4px bottom RenderFlex overflow and the Android emulator connection was lost when the emulator closed.
- **Root cause:** The Total panel had a fixed 64px height with 10px vertical padding, leaving only 44px for a Column whose natural content height was slightly larger than the available space.
- **File changed:** `lib/features/cart/screens/cart_screen.dart`
- **Fix:** Set the inner Total-panel Column to `mainAxisSize: MainAxisSize.min` so it sizes to its content instead of requesting the full available 44px content area. The outer 64px footer height is retained.
- **Supabase changes:** None.
- **Testing:** User reproduced the 4px overflow. Emulator then closed/lost connection; emulator stability itself is not treated as a code failure.
- **Current stopping point:** The remaining Cart layout overflow is fixed in code; runtime retest is required after restarting the emulator.
- **Next task:** Restart the Pixel_8 emulator, run the app, open My Cart, and verify there is no yellow/black overflow warning. Then test Proceed to Checkout.

### 2026-09-18 — Fixed My Cart footer RenderFlex crash

- **User-reported runtime issue:** Opening **My Cart** caused the screen to disappear and Flutter threw RenderFlex / RenderBox layout assertions.
- **Root cause:** The new bottom two-column Cart footer used `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` inside a vertically unbounded `Column` child. Flutter attempted to stretch the Row's children against an unbounded height, leaving the RenderFlex without a finite layout size.
- **File changed:** `lib/features/cart/screens/cart_screen.dart`
- **Fix:** Changed the footer Row to `mainAxisSize: MainAxisSize.min` and `crossAxisAlignment: CrossAxisAlignment.center`. The two footer columns retain their explicit 64px heights, while the Row no longer requests an unbounded vertical stretch.
- **Supabase changes:** None.
- **Testing:** User reproduced the crash immediately after opening My Cart. Fix is committed; runtime retest is required.
- **Current stopping point:** My Cart footer layout crash is fixed in code, but the user must pull and retest before we proceed.
- **Next task:** git pull, hot restart/run the app, open My Cart, and confirm the cart renders with the Total column and Proceed to Checkout column. If it renders, then run flutter analyze again.

### 2026-09-18 — Fixed final 3 analyzer issues

- **User test:** `flutter analyze` reported 3 remaining issues: stale Cart `onQuantityChanged` reference, Checkout `RadioGroup` callback type mismatch, and unused `_NoAddressView`.
- **Files changed:** `lib/features/cart/screens/cart_screen.dart`; `lib/features/checkout/screens/checkout_screen.dart`.
- **Fixes:** Removed the stale Cart callback reference; made Checkout `RadioGroup` use an explicit nullable `String?` callback; removed `_NoAddressView`.
- **Supabase changes:** None.
- **Testing:** GitHub fixes pushed; local `flutter analyze` is pending.
- **Commits:** Cart `e44aa447a1d045840ddd2809c06f58a9695ab2bb`; Checkout `4bd3a9fa6e5705e5c93b507c3a79164530741f16`.
- **Current stopping point:** All 3 issues from the latest analyzer run have been addressed.
- **Next immediate test:** `git pull` → `flutter analyze`. If clean, continue with the planned Checkout delivery validation/payment work.

### 2026-09-18 — Cleared remaining 3 analyzer issues from user test

- **User test result:** `flutter analyze` reported 3 issues after the previous cleanup.
- **Files changed:**
  - `lib/features/cart/screens/cart_screen.dart`
  - `lib/features/checkout/screens/checkout_screen.dart`
- **Fixes:** Removed the leftover `onQuantityChanged()` call from Cart quantity increment; changed Checkout `_selectFulfillment` to accept nullable `String?` for `RadioGroup<String>.onChanged`; removed the now-unused `_NoAddressView`.
- **Supabase changes:** None.
- **Testing:** GitHub code updated directly. Local `flutter analyze` after this fix is pending user verification.
- **Commits:** Cart `e3a4edb6b37a981734d702559cf6ccdc894c1364`; Checkout `5655beb8add7679a0132d2436b062f5651d613c3`.
- **Current stopping point:** All 3 analyzer issues reported by the user have been addressed.
- **Next immediate test:** `git pull` then `flutter analyze`. If 0 issues, proceed to the next planned Checkout validation/payment step.

### 2026-09-18 — Cleaned current analyzer issues and removed Checkout debug logging

- **User request:** Fix all current `flutter analyze` issues in one push and remove the temporary `debugPrint` diagnostics.
- **Files changed:**
  - `lib/features/cart/screens/cart_screen.dart`
  - `lib/features/auth/screens/login_screen.dart`
  - `lib/features/admin/screens/identity_verification_management_screen.dart`
  - `lib/features/checkout/screens/checkout_screen.dart`
  - `lib/features/developer/screens/developer_dashboard_screen.dart`
- **Fixes:** Removed unused imports from Login and Cart; removed the obsolete Cart `onQuantityChanged` callback requirement; changed Cart total string to interpolation; changed the KYC rejection result to interpolation; removed unused Developer dashboard `_open` and `_ModuleCard`; removed the unused Checkout `_NoAddressView`; replaced deprecated Checkout `RadioListTile.groupValue/onChanged` usage with `RadioGroup`; removed Checkout `debugPrint` diagnostics.
- **Supabase changes:** None.
- **Testing:** User reported the analyzer output before this push; code was updated directly on GitHub. Local `flutter analyze` after these changes is **pending user verification**.
- **Commits:** Cart `85387699bb6086615e7fc672af2f72c6d63fb7f5`; Login `9727888e3f2d5e1586a62754d0525e70e8024ea9`; Admin KYC `e2a4f536aeca88fb867cce85c8767a0e6786499b`; Developer dashboard `c6ca50d010cdb573d2284d8f9ece5e97487401be`; Checkout cleanup `f881325ccefef0ca52e8064ed385372bb0c926ca`.
- **Current stopping point:** Analyzer issues listed by the user have been addressed in the affected files; no runtime/analyzer success is claimed yet.
- **Next immediate test:** `git pull` then run `flutter analyze`. If it reports any remaining issue, send the exact output and we will clear the remaining one before continuing Checkout/payment work.

### 2026-09-18 — Simplified My Cart footer and removed redundant delivery fee UI

- **User request:** Remove the Delivery Fee tiles/cards from **My Cart** because fulfillment is now chosen later in Checkout. Replace the redundant lower summary/button layout with a simple two-column footer.
- **File changed:** `lib/features/cart/screens/cart_screen.dart`
- **UI result:** My Cart no longer calculates or displays delivery distance/delivery fee. The bottom area now has two columns: **Total** (all cart items' current subtotal) and **Proceed to Checkout**.
- **Architecture:** Delivery fee remains a Checkout concern, where the customer explicitly chooses Delivery or Pick-up.
- **Supabase changes:** None.
- **Commit:** `acfdde7da5f01c151e1b30eea02ae609c3673929`
- **Testing:** Code pushed directly to GitHub; runtime test pending.
- **Next immediate test:** `git pull` → Customer → add food → My Cart. Confirm there is no Delivery Fee tile and the bottom has exactly two columns: Total + Proceed to Checkout. Then open Checkout and confirm the fulfillment selector still works.

### 2026-09-18 — Pickup summary cleanup + removed unused duplicate checkout screen

- **User finding:** Customer Checkout is now visible and the Pick-up/Delivery selector works. User requested that when **Pick-up** is selected, the **Delivery Fee** row should no longer appear in the Order Summary.
- **File changed:** `lib/features/checkout/screens/checkout_screen.dart`
- **Fix:** Order Summary now receives `showDeliveryFee` based on the selected fulfillment type. The Delivery Fee row is rendered only for **Delivery**. Pick-up still calculates a zero delivery fee internally for order persistence, but the UI no longer displays a Delivery Fee line.
- **Unused-file cleanup:** Confirmed `lib/features/order/screens/checkout_screen.dart` was a duplicate checkout implementation and was not the Customer Cart checkout route. It has been deleted.
- **Important:** `lib/features/order/data/order_repository.dart` was **not** deleted because the existing order screens still import/use it for order history/details. `lib/features/order/data/order_model.dart` is also retained for those screens.
- **Supabase changes:** None.
- **Commits:** Pickup summary fix `12c3871f40f33611ab27372317279c9aaf642405`; duplicate checkout deletion `5e4a32f6b8f395a6fb5a2d63fec72df465a2191a`.
- **Testing:** Code pushed directly to GitHub. Runtime retest is pending.
- **Current stopping point:** Actual Customer Checkout is the single checkout UI source; Pick-up should not show Delivery Fee.
- **Next immediate test:** `git pull` → Customer → Restaurant → Add Food → Cart → Checkout → select **Pick-up**. Confirm the Order Summary has **Subtotal** and **Total**, but **no Delivery Fee**. Then select Delivery and confirm the Delivery Fee appears again.
 
### 2026-09-18 — Fixed actual Customer Checkout route for EDIT 1

- **User finding:** Customer flow **Cart → Proceed to Checkout** still showed the old delivery-only checkout: **Delivery Address → Your Order → Delivery → Order Summary → Place Order**. The Pick-up/Delivery selector was not visible even after the latest pull.
- **Root cause:** The Cart screen imports lib/features/checkout/screens/checkout_screen.dart, not lib/features/order/screens/checkout_screen.dart. EDIT 1 had previously been implemented in the latter file, so the actual Customer route never used that selector.
- **Files changed:** lib/features/checkout/screens/checkout_screen.dart; lib/features/checkout/data/order_repository.dart.
- **Fix:** The actual Customer Checkout now starts with **How would you like to receive your order?** and requires an explicit **Pick-up** or **Delivery** selection. _fulfillmentType starts as null, so Delivery is no longer assumed.
- **Delivery behavior:** Delivery Address and Delivery fee/distance sections are shown only after the customer selects **Delivery**. Existing delivery-distance/fee calculation via DistanceUtils was preserved; no new hardcoded delivery-fee logic was introduced.
- **Pick-up behavior:** Pick-up does not require a delivery address and uses a zero delivery fee for the current order calculation. Final pickup payment rules are intentionally still pending EDIT 3.
- **Order persistence:** The actual Checkout OrderRepository now accepts nullable address, validates delivery/pickup, requires an address for Delivery, and persists the selected fulfillment_type to the existing orders.fulfillment_type column.
- **Supabase changes:** None; existing orders.fulfillment_type and nullable delivery_address_id are reused.
- **Testing:** Code pushed directly to GitHub. Runtime testing is **pending**; user should pull and verify the actual Customer Checkout screen. Do not claim C5 is revalidated until the user tests it.
- **Commits:** Checkout UI 68cc98e08215b9fd026b9600b4dfc3c9fd6bb902; actual Checkout OrderRepository 49fef38409949fd9f38db7a6d92b1451a319f896.
- **Current stopping point:** EDIT 1 is now implemented in the **actual Customer Checkout screen used by Cart**.
- **Next immediate test:** git pull → Customer → Restaurant → Add Food → Cart → Checkout. Confirm the first section is the Pick-up/Delivery choice, neither option is preselected, and **Delivery Address is absent until Delivery is selected**.
- **Important:** The separate lib/features/order/screens/checkout_screen.dart is not the route used by Cart. Do not continue editing that duplicate screen for Customer Checkout unless its role is deliberately changed later.

### 2026-09-18 — Started Payment/Fulfillment redesign: Checkout Pick-up vs Delivery

- **Reason:** After Customer C0–C7 and C8.1–C8.4 passed, C8.5/C8.6 were paused because payment and fulfillment rules need to be explicit before testing invalid delivery locations or failed payments.
- **Files changed:** `lib/features/order/screens/checkout_screen.dart`, `lib/features/order/data/order_repository.dart`.
- **EDIT 1 implemented:** Checkout now asks **How would you like to receive your order?** with **Pick-up** and **Delivery** choices.
- **Delivery behavior:** Delivery remains the current path and shows the saved delivery-address section. A delivery address is required before order creation.
- **Pick-up behavior:** Pick-up no longer requires a delivery address and persists `fulfillment_type = 'pickup'`. Payment is intentionally **not yet finalized**; the next edit will add the pickup prepayment/payment-method rules before pickup orders are allowed to complete the final payment workflow.
- **Repository hardening:** `OrderRepository.createOrder()` now accepts nullable `deliveryAddressId`, accepts `fulfillmentType` (delivery/pickup), validates the fulfillment value, requires an address for delivery, and persists `fulfillment_type` to the existing `orders` column.
- **Supabase inspection:** Existing `orders.fulfillment_type` is NOT NULL with default `delivery`; `delivery_address_id` is nullable. No migration was required for this edit.
- **Important sequencing:** Do not treat Pick-up as fully payment-ready yet. The next edit must implement payment-method/payment-state rules so the restaurant is not exposed to unpaid orders.
- **Testing:** Code pushed to GitHub. User should `git pull` and run the checkout flow to verify the new selector and ensure the existing Delivery checkout still behaves correctly. Do not claim C5 remains fully validated for the modified UI until this retest is performed.
- **Commits:** Checkout UI `f34e5866f19356a9be2db197f009b6f2496a8bb2`; OrderRepository `9ad5fcfd907a2b2c70ab29fd3b5d79aaf0dba033`.
- **Current stopping point:** EDIT 1 — fulfillment selection is implemented.
- **Next immediate task:** User test EDIT 1. If good, proceed to **EDIT 2 — Delivery validation + real delivery-fee computation**, then payment rules.

### 2026-09-18 — Customer audit C0–C7 and C8.1–C8.4 PASSED; payment/fulfillment redesign queued

- **Customer runtime results reported by user:** C0 KYC routing/one-time approval **GOODS**; C1 Profile & Account **GOODS**; C2 Addresses + GPS **GOODS**; C3 Restaurant Discovery/filter/menu **GOODS**; C4 Cart **GOODS**; C5 Checkout/place-order/computation and Owner receipt/processing **GOODS**; C6 Orders **GOODS**; C7 realtime Owner → Customer status updates **GOODS**.
- **C8 edge-case results:** C8.1 Empty Cart **GOODS**; C8.2 No Address **GOODS** (checkout cannot proceed without a usable address/GPS needed for delivery-fee computation); C8.3 Restaurant Unavailable **GOODS** (inactive restaurant is not shown); C8.4 Expired Subscription **GOODS** (past due/grace/suspended restaurants do not appear; active restaurants appear).
- **Not implemented yet:** C8.5 Invalid/Out-of-range Delivery Location and C8.6 Failed Order/Payment. Do not mark these as failed; they depend on the payment/fulfillment architecture below.
- **Important clarification:** Menu search inside an individual restaurant is **not currently a feature**. Restaurant search works; restaurant/category filtering, restaurant opening, and menu/category display were tested successfully. Do not treat missing in-restaurant menu search as a bug unless this feature is intentionally added later.
- **Current stopping point:** Customer normal browsing/order flow is working through realtime status. The next development work is to redesign Checkout around explicit **Pick-up vs Delivery** fulfillment and controlled payment states before continuing C8.5/C8.6.
- **Next immediate build task:** Add a clear fulfillment selection to Checkout first, then implement payment-method/payment-state handling without falsely marking an order paid before a real payment confirmation exists.

### 2026-09-18 — Payment + fulfillment architecture agreed before C8.5/C8.6

- **User requirement/concern:** Customer should be asked how they will receive the order before payment. Delivery introduces restaurant risk if food leaves the restaurant before payment is secured.
- **Agreed fulfillment choices:**
  1. **Pick-up** — customer collects from the restaurant. Initial policy target: require a **minimum 50% prepayment** before the restaurant prepares the order; remaining balance can be settled at pickup according to the restaurant's configured policy.
  2. **Delivery** — customer selects a valid address with GPS, delivery fee is calculated, and the initial recommended policy is **online payment before preparation/rider pickup**.
- **COD policy:** Do **not** enable Cash on Delivery globally at this stage. If COD is introduced later, it should be explicitly enabled by the restaurant and protected by eligibility/order/area controls.
- **Payment architecture principle:** Keep **payment status** separate from **order status**. Proposed payment states include `pending`, `processing`, `paid`, `failed`, `cancelled`, `refunded`, and `partially_paid`. Existing database already has separate `orders.payment_status` and `payments.status`; inspect and reuse these instead of inventing duplicate fields.
- **Order flow target:**
```text
Customer → Cart
  → Pick-up or Delivery
  → Address/GPS only when Delivery
  → Compute applicable delivery fee
  → Select allowed payment method
  → Payment confirmation / required prepayment
  → Order confirmed
  → Restaurant prepares
  → Ready
  → Pick-up OR Rider pickup → Customer
```
- **Delivery safety target:** Prefer platform-controlled online payment for Delivery. Do not rely on a rider to collect an uncertain restaurant payment.
- **Restaurant payment-account concern:** Do not make the long-term architecture depend on customers manually paying each restaurant's personal GCash/Maya/bank account. That makes automatic payment confirmation, disputes, refunds and settlement difficult. Prefer a platform payment flow with recorded transaction/payment state, then restaurant settlement.
- **Database observation:** Current `orders` already contains `fulfillment_type`, `payment_status`, `delivery_address_id`, `delivery_fee`, `delivery_distance_km`; current `payments` contains `order_id`, `customer_id`, `amount`, `payment_method`, `status`, and transaction reference. These existing fields should be reused where possible.
- **Current implementation gap:** Existing Flutter `CheckoutScreen` still behaves as delivery-only, uses a hardcoded `_deliveryFee = 0.0`, does not ask Pick-up vs Delivery, and `OrderRepository.createOrder()` currently creates an order without an explicit fulfillment/payment choice. This must be redesigned before claiming payment/edge-case coverage.
- **Important:** Do not claim online payment is implemented merely by adding a button. A real payment integration/confirmation mechanism is required before an order can safely transition to `paid`.
- **Next implementation sequence:**
  1. Checkout fulfillment selector and UI state.
  2. Delivery-only address/GPS and delivery-fee calculation.
  3. Pickup payment requirement/configuration model.
  4. Payment method selection based on fulfillment.
  5. Payment transaction/state persistence.
  6. Backend enforcement so order creation/payment states cannot be bypassed by modified clients.
  7. Then implement/test C8.5 invalid location and C8.6 failed payment/order paths.
- **Supabase/database changes in this documentation step:** None.

### 2026-09-18 — Admin KYC verdict actions restricted to Pending only

- **User finding/requirement:** Once an identity verification already has a verdict (**Approved** or **Rejected**), the Admin review screen must no longer show **Approve** or **Reject** actions. Those actions are only valid while the record is **Pending**.
- **File changed:** `lib/features/admin/screens/identity_verification_management_screen.dart`
- **Fix:** Admin Approve/Reject buttons are now rendered only when `row['status'] == 'pending'`. Approved and Rejected records instead show a clear read-only verdict message.
- **Behavior:** Pending → Admin can Approve or Reject. Approved → no decision buttons. Rejected → no decision buttons. Existing Developer read-only behavior and permanent-delete control remain unchanged.
- **Supabase/database changes:** None.
- **Testing:** Code change pushed to GitHub. Runtime verification is pending.
- **Commit:** `c9a65d02af8dd694f97de5c0cf0cae7b72577925`
- **Current stopping point:** Admin KYC decision controls are now logically limited to Pending records.
- **Next test:** `git pull`, run the app, open Admin → Identity Verification → check Pending has Approve/Reject, then open Approved and Rejected records and confirm neither has Approve nor Reject.

### 2026-09-18 — KYC rejection lifecycle fix VERIFIED by user

- **Runtime test result:** User confirmed the latest KYC rejection fix is **OK / working**.
- **Verified flow:** Admin → Identity Verification → Pending → open verification → Reject → enter rejection reason → Reject.
- **Confirmed:** Rejection reason/remark is saved successfully, the verification is rejected, the Flutter red-screen assertion no longer occurs, and the rejection flow completes normally.
- **Bug status:** The Flutter `'_dependents.isEmpty': is not true` / `Tried to build dirty widget in the wrong build scope` issue is considered **FIXED** for this tested flow.
- **Code commit:** `708e7675c33ee2b5a1fd1663d97c94f2f397f2cf`
- **Documentation update:** This entry records the successful runtime verification.
- **Current stopping point:** Admin KYC rejection is working. KYC approval/rejection UI lifecycle issue is no longer the immediate blocker.
- **Next task:** Continue the remaining Admin/KYC audit one test at a time. Next verify **Admin KYC approval flow**, then **Developer KYC view-only/image access**, then resume the broader Admin audit before moving to Customer C1/C2 testing.

### 2026-09-18 — KYC rejection red-screen lifecycle fix (second attempt)

- **User runtime finding:** The rejection reason is saved successfully and the record is counted as rejected, but Flutter still shows `'_dependents.isEmpty': is not true` and `Tried to build dirty widget in the wrong build scope.` This confirms the backend rejection is successful; the remaining bug is Flutter widget/route lifecycle only.
- **File changed:** `lib/features/admin/screens/identity_verification_management_screen.dart`
- **Fix:** Replaced the inline TextEditingController/dialog lifecycle inside `_ReviewSheet` with a dedicated stateful `_RejectReasonDialog`. The dialog now owns and disposes its controller in its own `dispose()`.
- **Route sequencing fix:** After the rejection reason dialog returns, the review BottomSheet is no longer popped synchronously. Its result is returned through `WidgetsBinding.instance.addPostFrameCallback`, allowing the AlertDialog route to finish its frame before the BottomSheet is dismissed.
- **Expected behavior:** Reason dialog closes cleanly → review BottomSheet closes on the next frame → parent receives `reject:<reason>` → existing Supabase update saves the rejection → parent updates Pending list.
- **Supabase/database changes:** None. The previous runtime result already confirmed the database update succeeds.
- **Commit:** `708e7675c33ee2b5a1fd1663d97c94f2f397f2cf`
- **Testing:** Not yet runtime-tested after this second lifecycle fix.
- **Next test:** `git pull`, run `flutter analyze`, then perform exactly one test: Admin → Identity Verification → Pending → open a record → Reject → enter reason → Reject. Confirm no red screen, reason still saves, and Pending item disappears immediately.

### 2026-09-18 — Reworked Admin KYC rejection dialog to avoid Flutter route lifecycle assertion

- **User runtime finding:** After typing the rejection reason and pressing Reject, the rejection is saved/counts as rejected, but Flutter shows a red-screen assertion: `'_dependents.isEmpty': is not true` followed by `Tried to build dirty widget in the wrong build scope.`
- **Root cause:** The previous fix still opened a second AlertDialog from the parent screen after the review BottomSheet had returned. The route/widget tree was still transitioning, so the second route could trigger Flutter's element/dependent lifecycle assertion.
- **Fix:** Rejection reason input is now opened **inside the existing review BottomSheet**. The reason dialog completes first, then the review sheet returns a single `reject:<reason>` result to the parent. The parent directly saves the rejection. This removes the nested route transition between the BottomSheet and a parent-level dialog.
- **Controller lifecycle:** The rejection TextEditingController is disposed in a `finally` block after the reason dialog finishes.
- **File changed:** `lib/features/admin/screens/identity_verification_management_screen.dart`
- **Supabase/database changes:** None.
- **Commit:** `0678f4166e52b65624b22a444103a3d57eb79380`
- **Testing:** User confirmed the previous implementation still produced the red screen even though the rejection was successfully counted. This new implementation has **not yet been runtime-tested**.
- **Next test:** `git pull`, run `flutter analyze`, then Admin → Identity Verification → Pending → open record → Reject → type reason → Reject. Confirm: (1) no red screen/assertion, (2) rejection saves, and (3) record disappears from Pending immediately.

### 2026-09-18 — Fixed Flutter analyzer errors before two-device testing

- **User reported:** `flutter analyze` returned 8 issues after the Admin/Developer KYC preparation.
- **Fixed:** Admin Action Center subscription query was missing `.from('subscription_payments')`; restored the correct Supabase table query.
- **Fixed:** Admin Action Center string composition now uses interpolation.
- **Fixed:** KYC image `errorBuilder` no longer uses unnecessary multiple underscores.
- **Fixed:** Removed obsolete `_openHomeForRole` from Login because Login now routes through Splash.
- **Fixed:** Removed obsolete Developer dashboard helper methods `_groupHeader` and `_moduleGrid` left from the previous navigation architecture.
- **Fixed:** Identity verification `_idType` is now final because it is not mutated.
- **Git commits:** Admin Action Center `104794adfb86634070baf8d978ecb78327bcd869`; KYC image lint `ebe95abe662b4b49de30bad990b959d9bc31e55d`; Login cleanup `37c6dc0d01923ed513e5d14df599d23ff80b2e6c`; Developer cleanup `fafe7a98aa693f4818de01900c705bf522a101fc`; Identity screen lint `c796d3e9b7f0784c0174edb145cf3be8c716cf15`.
- **Testing:** Fixes were made directly in GitHub. User must rerun `flutter analyze` locally; assistant has not claimed a clean analyzer result.
- **Stopping point:** Code is ready for analyzer re-check before APK installation/two-device testing.
- **Next:** `git pull`, run `flutter analyze`, report the result. Do not install/test APK until analyzer is clean.
 
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

### 2026-09-18 — Fixed Admin KYC rejection dialog assertion

- **User-reported runtime error:** Rejecting an identity verification triggered Flutter assertion `'_dependents.isEmpty': is not true` from `framework.dart`.
- **Cause addressed:** The rejection reason AlertDialog was being opened immediately while the review BottomSheet route was still completing its dismissal transition.
- **Fix:** Added a short route-settlement delay before opening the rejection dialog and delayed controller disposal until the dialog route has fully returned.
- **File:** `lib/features/admin/screens/identity_verification_management_screen.dart`
- **Commit:** `cd9229d2e0f6f92cc135201ab33958849a512cdc`
- **Testing:** Not yet runtime-tested by user after this fix.
- **Next test:** `git pull`, run `flutter analyze`, then open a Pending KYC record and press Reject. Confirm the reason dialog opens without the Flutter assertion and that submitting the rejection removes the record from Pending immediately.


### 2026-09-18 — Added Promo Discount to Checkout Order Summary

- Updated `lib/features/checkout/screens/checkout_screen.dart`.
- **Order Summary** now explicitly shows a **Promo Discount** row whenever a promo is applied.
- The discount is displayed as a negative amount (for example, `-₱50.00`) and is reflected in the final **Total**.
- No Supabase/database changes.
- GitHub commit: `3baf90b4180007f59d1ae94177d5cb288f4c98d6`.
- **Testing:** Flutter runtime/analyzer testing still pending after this UI change.
- **Next test:** `git pull`, run `flutter analyze`, then open Checkout and verify the Order Summary shows Subtotal, Delivery Fee when applicable, Promo Discount when a promo is selected, and the correctly reduced Total.

### 2026-09-18 — Implemented Customer Checkout Promo/Coupon System

- **User requirement:** Promo/Coupon belongs in Checkout, not My Cart. Customers should see available promos from Admin (global) and from the specific restaurant owner, and once a customer has used a promo code, that same customer must not be able to use it again.
- **Existing DB inspected:** public.promo_codes already existed. Its existing model supports global promos with restaurant_id IS NULL and restaurant-specific promos with restaurant_id = restaurant UUID. Existing Admin and Restaurant Owner CRUD RLS policies were preserved.
- **Supabase changes applied:** Added orders.promo_code_id and orders.promo_discount; created public.promo_redemptions with a unique (promo_code_id, customer_id) constraint, making each promo code one-time per customer. Added indexes and RLS for redemption visibility.
- **Customer promo visibility:** Added a customer SELECT policy on promo_codes for active global promos and active promos belonging to the current restaurant. The Customer Checkout repository also filters out promos the current customer already redeemed and promos whose global usage limit has been reached.
- **Atomic redemption protection:** Added public.claim_promo_code(order_id, code) as a restricted SECURITY DEFINER function with search_path = ''. It revalidates restaurant scope, active dates, minimum order, usage limit, one-use-per-customer, discount type/value and maximum discount before creating the redemption and updating the order total.
- **Usage count:** Added a trigger to keep promo_codes.usage_count synchronized with actual redemption rows.
- **Flutter:** Added lib/features/checkout/data/promo_code_repository.dart. Checkout now loads available global + restaurant-specific promos, lets the customer select one, shows the discount in Order Summary, and passes the selected promo code into order creation. The promo cannot be selected when the cart subtotal is below its minimum order.
- **Order creation:** lib/features/checkout/data/order_repository.dart now claims the selected promo after order/order-items creation. If promo claiming fails, the newly created order is deleted as part of the existing rollback path.
- **Important behavior:** A promo is only consumed when the order is successfully created and the server-side claim succeeds. The unique customer/promo constraint prevents reuse even if the customer tries again later.
- **Supabase migration:** Applied directly to project taltqnxhivpfwjqlvxnt and documented in supabase/customer_checkout_promo_codes.sql.
- **GitHub commits:** Promo repository 535e7ceed7ccb6198d6e60fb46a42ac66c553642; order repository 00720bd7cdb261ce5a091a89524c53856fbd37de; Checkout UI ba037fe2e3d09f89628b5e8c06d14f4c70cd5572; minimum-order selection guard 0f695616f5f5ba5041b1633222fb836d9ac350d5; SQL documentation 7f0d8c46963bb705de16ccc1323d9cbfb7c1b99a.
- **Testing:** Supabase migrations executed successfully. Flutter runtime/analyzer testing has not yet been run after the promo implementation.
- **Current stopping point:** Promo/Coupon is implemented in Checkout. My Cart remains unchanged. The customer should see Admin/global promos plus promos for the restaurant in the cart. Each customer can use each promo code only once.
- **Next test:** git pull, run flutter analyze, then open a restaurant, add items, and Checkout. Confirm Promo/Coupon appears, global + restaurant-specific promos are listed, selecting a valid promo reduces the Order Summary total, and placing the order records the redemption. Then attempt the same promo again with the same customer and confirm it is no longer available / is rejected server-side.

### 2026-09-18 — KYC review UX, image zoom, retention cleanup and Developer deletion

- **User-reported issue #1:** Admin approval moved a record from Pending to Approved immediately, but rejection could remain visible in Pending until a manual refresh.
- **Fix:** lib/features/admin/screens/identity_verification_management_screen.dart now updates the local filtered list immediately after Approve/Reject. Approved records remain in Approved when that filter is active; rejected records are removed from Pending immediately. The screen also performs rejected-history cleanup after approval.
- **User-reported issue #2:** Admin and Developer need to zoom KYC images for proper inspection.
- **Fix:** ID and selfie previews are now tappable and open a full-screen-style dialog with InteractiveViewer, supporting pan and zoom up to 6x for both Admin and Developer view-only mode.
- **User-reported issue #3:** Developer must be able to permanently delete an identity-verification record and its photos.
- **Fix:** Developer view-only mode now includes Delete Verification Permanently. It requires confirmation, removes the ID/selfie through the Supabase Storage API, then deletes the identity_verifications row. This can also delete an approved record, which intentionally makes the account unverified again.
- **Rejected-file retention:** Rejected submissions are kept while rejected so Admin/Developer can inspect them. When the user resubmits, previous rejected files are removed from Storage and the old rejected DB records are deleted before the new submission is uploaded.
- **Approved cleanup:** When Admin approves a verification, all older rejected submissions for the same user/role are removed from Storage and the database. The approved submission remains.
- **Upload failure cleanup:** If a new submission uploads files but the DB insert fails, the newly uploaded files are removed on a best-effort basis to avoid orphaned Storage objects.
- **One-time approval hardening:** Added a unique partial index for one approved verification per user/role and changed the INSERT policy so an already-approved user/role cannot submit another verification. Rejected users can still resubmit.
- **Delete authorization:** Added RLS so authenticated Admin/Developer accounts may delete verification rows and identity files. Users may delete only their own rejected verification rows; existing own-file Storage delete access remains.
- **Storage safety:** File deletion uses the Supabase Storage API rather than direct SQL deletion of storage.objects, because direct SQL deletion can orphan physical files.
- **Supabase changes:** Applied SQL directly to project taltqnxhivpfwjqlvxnt; documented the same SQL in supabase/identity_verification_retention_and_developer_delete.sql.
- **GitHub commits:** Admin KYC UX/zoom/cleanup e0797b542a9a0c51fc84c8152e58ec4fc02b55cb; Customer/Owner/Driver resubmission cleanup a848dc9de8833c308011ce01a9323ebd16ed55a3; migration documentation 7e36c98f45068b4f9d7e4544867a339a9407d984.
- **Testing:** Supabase SQL executed successfully. Flutter analyzer/runtime verification has **not** yet been run after these code changes.
- **Current stopping point:** KYC Admin/Developer behavior has been updated for immediate Pending-list removal, image zoom, Developer deletion, rejected-history cleanup, and one-time approval protection.
- **Next task:** User should git pull, run flutter analyze, then test one KYC flow at a time: Admin reject → Pending disappears without refresh; Admin/Developer tap image → zoom/pan; Customer resubmit after rejection → old files are gone; Admin approve → rejected history is cleaned; Developer delete → DB row and files are removed.


### 2026-09-18 — Prepared Admin + Developer sides for physical-phone KYC testing

- **User request:** Before testing Customer/Owner on the Android emulator and Admin/Developer on a physical Android phone at the same time, fix and connect the Admin + Developer KYC surfaces first.
- **Admin changes:** Dashboard now counts pending personal identity-verification submissions separately from restaurant halal verification and subscription payments. Identity KYC is included in dashboard alerts and refreshes through Supabase Realtime. Admin Action Center now includes pending identity-verification actions.
- **Admin KYC authority:** `IdentityVerificationManagementScreen` remains the approval/rejection screen. Admin can view ID/selfie images through short-lived signed URLs and can Approve or Reject with a reason.
- **Developer changes:** Added `Identity Verification` under Developer → Overview & Access. It reuses the Admin KYC viewer in explicit `readOnly` mode, so Developer can view submitted KYC records/images but has no Approve/Reject controls.
- **Supabase authorization:** Added a SELECT RLS policy allowing authenticated Admin or Developer accounts to read `public.identity_verifications`. Existing private Storage policy already allows Admin/Developer image viewing. The `identity-verifications` bucket remains private.
- **Repository migration documentation:** Added `supabase/developer_identity_verification_view_access.sql` matching the applied RLS policy.
- **Security verification:** Confirmed the identity-verification table policy is `(is_admin() OR is_developer())`. Supabase security advisors still report the previously known SECURITY DEFINER/search_path/auth findings; no unrelated security hardening was mixed into this testing-preparation change.
- **Testing:** Code/database changes are implemented. No local Flutter runtime test has been run by the assistant; physical-phone/emulator test is the next step.
- **Commits:** Admin KYC dashboard `d8e439d52d477f3be8a41b3159617364536ea2b7`; Admin Action Center `88f996c0a412bf3e021c353512814865f8625e18`; Developer KYC view-only `110b4ae3ece4e721fee4d286d9a53eeb0655cafb`; KYC read-only mode `2a785ac239e86761181619c2a9b0cdca9ab75befb`; RLS documentation `6895cbe4236e41589104e900fb88f8cf44d14b76`.
- **Current stopping point:** Admin and Developer KYC surfaces are connected for the upcoming two-device test. Admin is the operational approver; Developer is view-only.
- **Next task:** User should `git pull`, install/run the same build on the Android emulator (Customer/Owner) and physical phone (Admin/Developer), then test one flow at a time starting with Admin → Identity Verification list/view and Developer → Identity Verification view-only access.

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
**KYC management is now connected for testing:** dashboard count/alerts, Action Center, Pending/Approved/Rejected viewer, signed image review, Approve/Reject with reason. Admin is still not marked 100% complete until the broader Admin audit is tested.

## Developer
KYC identity-verification records/images are now available through a dedicated **view-only** module. Developer must not approve/reject.

## Customer
Customer audit remains queued while Admin + Developer KYC is tested on the physical phone.

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
