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
