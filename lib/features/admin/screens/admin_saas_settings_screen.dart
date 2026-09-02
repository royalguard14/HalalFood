import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'admin_subscription_payment_methods_screen.dart';

class AdminSaasSettingsScreen extends StatelessWidget {
  const AdminSaasSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('SaaS Settings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [HalalFoodTheme.primaryGreen, HalalFoodTheme.primaryGreen.withValues(alpha: .82)],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 38),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SaaS Configuration', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 5),
                      Text('Configure payment accounts used by restaurant owners for SaaS subscriptions.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.payments_rounded, color: Colors.teal),
              ),
              title: const Text('Payment Methods', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Add and manage GCash, bank transfer, Maya and other payment accounts.'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminSubscriptionPaymentMethodsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
