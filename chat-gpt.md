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
