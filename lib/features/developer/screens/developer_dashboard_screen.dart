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
import 'developer_branding_screen.dart';
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
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final modules = <_DeveloperModule>[
      _DeveloperModule(Icons.palette_outlined, 'Branding & Theme', 'Global app identity and colors.', Colors.purple, const DeveloperBrandingScreen()),
      _DeveloperModule(Icons.people_outline_rounded, 'Users & Roles', 'Manage platform users and roles.', Colors.blue, const UserRoleManagementScreen()),
      _DeveloperModule(Icons.storefront_outlined, 'Restaurants', 'Restaurant maintenance and control.', Colors.teal, const DeveloperRestaurantManagementScreen()),
      _DeveloperModule(Icons.restaurant_menu_outlined, 'Menus', 'Manage menu items across restaurants.', Colors.deepOrange, const AdminMenuManagementScreen()),
      _DeveloperModule(Icons.category_outlined, 'Food Categories', 'Manage global food categories.', Colors.indigo, const FoodCategoryManagementScreen()),
      _DeveloperModule(Icons.receipt_long_outlined, 'Orders', 'Monitor orders and payments.', Colors.blueGrey, const AdminOrderManagementScreen()),
      _DeveloperModule(Icons.workspace_premium_outlined, 'Subscriptions', 'Plans and subscription payments.', Colors.deepPurple, const AdminSaasSubscriptionHubScreen()),
      _DeveloperModule(Icons.verified_outlined, 'Halal Verification', 'Review halal verification requests.', Colors.green, const HalalVerificationScreen()),
      _DeveloperModule(Icons.local_shipping_outlined, 'Delivery Pricing', 'Configure delivery pricing.', Colors.orange, const DeliveryPricingScreen()),
      _DeveloperModule(Icons.local_offer_outlined, 'Promos & Discounts', 'Manage promo codes and discounts.', Colors.pink, const PromoManagementScreen()),
      _DeveloperModule(Icons.settings_outlined, 'App Settings', 'Platform-wide application settings.', Colors.grey, const AdminSettingsScreen()),
      _DeveloperModule(Icons.notifications_none_rounded, 'Action Center', 'Review pending platform actions.', Colors.redAccent, const AdminActionCenterScreen()),
      _DeveloperModule(Icons.account_circle_outlined, 'Developer Profile', 'Manage the current developer profile.', Colors.cyan, const AdminProfileScreen()),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F7),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: HalalFoodTheme.primaryGreen.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.developer_mode_rounded, size: 19, color: HalalFoodTheme.primaryGreen),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Developer Console',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: HalalFoodTheme.primaryGreen.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: HalalFoodTheme.primaryGreen),
                SizedBox(width: 5),
                Text('Developer', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: HalalFoodTheme.primaryGreen)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_rounded, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1200;
          final medium = constraints.maxWidth >= 760;
          final columns = wide ? 4 : (medium ? 3 : 2);
          final horizontalPadding = wide ? 42.0 : (medium ? 26.0 : 14.0);

          return ListView(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 18, horizontalPadding, 36),
            children: [
              _compactHeader(),
              const SizedBox(height: 22),
              _sectionHeader('Platform modules', '${modules.length} available'),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 104,
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

  Widget _sectionHeader(String title, String count) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -.1),
          ),
        ),
        Text(
          count,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HalalFoodTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _compactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E7E4)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: HalalFoodTheme.primaryGreen.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.admin_panel_settings_outlined, color: HalalFoodTheme.primaryGreen, size: 23),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Platform Control', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('Global configuration and maintenance tools', style: TextStyle(fontSize: 11.5, color: HalalFoodTheme.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFB6BDB9), size: 20),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE3E7E4)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: module.color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(module.icon, color: module.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(module.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, height: 1.2, color: HalalFoodTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded, size: 17, color: Color(0xFFB8BFBB)),
            ],
          ),
        ),
      ),
    );
  }
}
