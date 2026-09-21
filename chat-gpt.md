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
