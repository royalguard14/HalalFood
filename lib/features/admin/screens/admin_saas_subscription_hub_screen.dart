import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'admin_subscription_management_screen.dart';
import 'admin_subscription_payment_review_screen.dart';
import 'admin_subscription_plan_payment_methods_screen.dart';

class AdminSaasSubscriptionHubScreen extends StatelessWidget {
  const AdminSaasSubscriptionHubScreen({super.key});

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('SaaS Subscription', style: TextStyle(fontWeight: FontWeight.w800)),
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
                Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 40),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SaaS Subscription Center', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                      SizedBox(height: 5),
                      Text('Manage plans, restaurant subscriptions, payment verification and payment availability per plan.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _item(
            context,
            Icons.subscriptions_rounded,
            'Subscriptions & Plans',
            'View restaurant subscriptions and manage SaaS plans. The Plans tab is where plan configuration belongs.',
            Colors.deepOrange,
            () => _open(context, const AdminSubscriptionManagementScreen()),
          ),
          _item(
            context,
            Icons.fact_check_rounded,
            'Payment Review',
            'Review owner payment references and screenshots before activating subscriptions.',
            Colors.orange,
            () => _open(context, const AdminSubscriptionPaymentReviewScreen()),
          ),
          _item(
            context,
            Icons.tune_rounded,
            'Payment Methods per Plan',
            'Choose exactly which configured payment methods are available for each SaaS plan.',
            Colors.teal,
            () => _open(context, const AdminSubscriptionPlanPaymentMethodsScreen()),
          ),
          const SizedBox(height: 8),
          Card(
            color: HalalFoodTheme.primaryGreen.withValues(alpha: .06),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: HalalFoodTheme.primaryGreen),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Actual GCash, bank and other payment accounts are configured under My Settings → SaaS Settings → Payment Methods.',
                      style: TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 11, height: 1.3, color: HalalFoodTheme.textSecondary)),
                ]),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 15, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
