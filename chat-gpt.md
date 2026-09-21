### 2026-09-21 — Fixed Owner Pickup Promo and Balance Breakdown
- **User-reported issue:** Owner Pickup Order Details showed the discounted total directly as **₱700**, instead of showing the full breakdown.
- **Required display for a ₱1,400 order with ₱700 promo:**
  - Subtotal: **₱1,400**
  - Promo: **-₱700**
  - GCash Downpayment: **-₱0** until the receipt/payment is approved
  - Cash for Pickup: **-₱0** until final pickup payment is recorded
  - Balance: **₱700**
- **Fix:** Owner Order Details now reads `promo_discount` separately and displays a **Promo** row. Pickup Subtotal uses the original `subtotal` instead of the already-discounted `total_amount`.
- Pickup Balance is calculated from the final `total_amount` minus the actual paid GCash and cash payments, so unpaid promo orders correctly show the remaining discounted balance.
- Delivery summary also now shows the Promo row when a promo discount exists.
- **File changed:** `lib/features/owner/screens/owner_order_details_screen.dart`
- **GitHub commit:** a3d94badeb887e8f7b876aaceb4548fbf8d2adcb
- **Testing status:** Code change committed; runtime test not yet performed.
- **Next exact test:** `git pull origin main` → open the Owner Order Details for the ₱1,400 / ₱700 promo Pickup order → verify the summary shows **Subtotal ₱1,400 → Promo -₱700 → GCash Downpayment -₱0 → Cash for Pickup -₱0 → Balance ₱700**.

"+"
### 2026-09-21 — Fixed Customer Pickup Order Summary
- **Customer-first correction:** Pickup Order Summary now uses the original `subtotal` as **Subtotal**, instead of the discounted `total_amount`.
- When a pickup promo is applied, the summary shows **Promo** as the difference between original subtotal and discounted `total_amount`.
- **Downpayment** is shown as ₱0 until `pickup_downpayment_status` is `paid`; only the Owner-approved amount is deducted.
- When the Pickup order reaches **Ready to Pick Up** (`orders.status = ready`), the summary shows the remaining **Cash Balance**.
- Cash Balance uses the discounted order total minus the approved GCash downpayment. Once `payment_status = paid`, Cash Balance becomes ₱0.
- Delivery summary behavior remains unchanged.
- **File changed:** `lib/features/order/screens/order_details_screen.dart`
- **Testing status:** Code committed by GitHub Actions; local runtime test still pending.
- **Next:** `git pull origin main`, run the app, then test the ₱1,400 Pickup order with ₱700 promo through receipt approval and Ready to Pick Up.
