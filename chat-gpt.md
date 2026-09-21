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