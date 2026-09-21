-- Allows a customer to replace the same pickup receipt object after rejection.
-- Storage upsert requires SELECT + UPDATE in addition to the existing INSERT policy.

drop policy if exists "Customers update own pickup receipts" on storage.objects;

create policy "Customers update own pickup receipts"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'payment-receipts'
  and exists (
    select 1
    from public.orders o
    where o.id::text = (storage.foldername(objects.name))[1]
      and o.customer_id = (select auth.uid())
      and o.fulfillment_type = 'pickup'
      and o.pickup_downpayment_status = 'receipt_rejected'
  )
)
with check (
  bucket_id = 'payment-receipts'
  and exists (
    select 1
    from public.orders o
    where o.id::text = (storage.foldername(objects.name))[1]
      and o.customer_id = (select auth.uid())
      and o.fulfillment_type = 'pickup'
      and o.pickup_downpayment_status = 'receipt_rejected'
  )
);
