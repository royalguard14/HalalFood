import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../auth/screens/login_screen.dart';
import '../../admin/screens/admin_action_center_screen.dart';
import '../../admin/screens/admin_menu_management_screen.dart';
import '../../admin/screens/admin_order_management_screen.dart';
import '../../admin/screens/admin_profile_screen.dart';
import '../../admin/screens/admin_settings_screen.dart';
import '../../admin/screens/admin_saas_subscription_hub_screen.dart';
import '../../admin/screens/delivery_pricing_screen.dart';
import '../../admin/screens/food_category_management_screen.dart';
import '../../admin/screens/halal_verification_screen.dart';
import '../../admin/screens/promo_management_screen.dart';
import '../../admin/screens/user_role_management_screen.dart';
import 'developer_restaurant_management_screen.dart';

class DeveloperDashboardScreen extends StatelessWidget {
  const DeveloperDashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modules = <_DeveloperModule>[
      _DeveloperModule(Icons.people_alt_rounded, 'Users & Roles', 'View users, edit profiles and manage all supported roles.', Colors.blue, const UserRoleManagementScreen()),
      _DeveloperModule(Icons.storefront_rounded, 'Restaurants', 'Developer restaurant control, including permanent deletion of related data.', Colors.teal, const DeveloperRestaurantManagementScreen()),
      _DeveloperModule(Icons.restaurant_menu_rounded, 'Menus', 'Manage menu items for every restaurant.', Colors.deepOrange, const AdminMenuManagementScreen()),
      _DeveloperModule(Icons.category_rounded, 'Food Categories', 'Create, edit, activate and remove global food categories.', Colors.indigo, const FoodCategoryManagementScreen()),
      _DeveloperModule(Icons.receipt_long_rounded, 'Orders', 'Monitor customer orders, statuses, totals and payment status.', Colors.blueGrey, const AdminOrderManagementScreen()),
      _DeveloperModule(Icons.workspace_premium_rounded, 'Subscriptions', 'Manage plans, subscriptions and subscription payment review.', Colors.deepPurple, const AdminSaasSubscriptionHubScreen()),
      _DeveloperModule(Icons.verified_rounded, 'Halal Verification', 'Review halal verification requests and decisions.', Colors.green, const HalalVerificationScreen()),
      _DeveloperModule(Icons.local_shipping_rounded, 'Delivery Pricing', 'Configure platform-wide delivery fees and surcharges.', Colors.orange, const DeliveryPricingScreen()),
      _DeveloperModule(Icons.local_offer_rounded, 'Promos & Discounts', 'Create, edit, activate and remove promo codes.', Colors.pink, const PromoManagementScreen()),
      _DeveloperModule(Icons.settings_rounded, 'App Settings', 'Control maintenance mode, registration, orders and notifications.', Colors.grey, const AdminSettingsScreen()),
      _DeveloperModule(Icons.notifications_active_rounded, 'Action Center', 'Review pending halal verification and subscription payment actions.', Colors.redAccent, const AdminActionCenterScreen()),
      _DeveloperModule(Icons.account_circle_rounded, 'Developer Profile', 'Manage the current developer profile and password.', Colors.cyan, const AdminProfileScreen()),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.developer_mode_rounded),
            SizedBox(width: 8),
            Flexible(child: Text('Developer Control Panel', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Logout', onPressed: () => _logout(context), icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          return ListView(
            padding: EdgeInsets.fromLTRB(wide ? 32 : 18, 22, wide ? 32 : 18, 40),
            children: [
              _headerCard(),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(child: Text('Developer Control', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  Text('${modules.length} tools', style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: wide ? 2 : 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 118,
                ),
                itemBuilder: (context, index) {
                  final module = modules[index];
                  return _ModuleCard(module: module, onTap: () => _open(context, module.screen));
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [HalalFoodTheme.primaryGreen, HalalFoodTheme.darkGreen]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_rounded, color: Colors.white, size: 44),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Developer / Super Admin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                SizedBox(height: 6),
                Text('Developer-level platform control. Operational Admin functions are kept separate.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperModule {
  const _DeveloperModule(this.icon, this.title, this.subtitle, this.color, this.screen);
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget screen;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.module, required this.onTap});
  final _DeveloperModule module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: module.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
                child: Icon(module.icon, color: module.color, size: 25),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(module.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(module.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, height: 1.25, color: HalalFoodTheme.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: module.color),
            ],
          ),
        ),
      ),
    );
  }
}
