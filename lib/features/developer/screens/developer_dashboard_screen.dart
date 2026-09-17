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
      _DeveloperModule(Icons.palette_rounded, 'Branding & Theme', 'Global app identity, colors and appearance.', Colors.purple, const DeveloperBrandingScreen()),
      _DeveloperModule(Icons.people_alt_rounded, 'Users & Roles', 'Manage users and supported platform roles.', Colors.blue, const UserRoleManagementScreen()),
      _DeveloperModule(Icons.storefront_rounded, 'Restaurants', 'Manage restaurants and developer maintenance actions.', Colors.teal, const DeveloperRestaurantManagementScreen()),
      _DeveloperModule(Icons.restaurant_menu_rounded, 'Menus', 'Manage menu items across restaurants.', Colors.deepOrange, const AdminMenuManagementScreen()),
      _DeveloperModule(Icons.category_rounded, 'Food Categories', 'Manage global food categories.', Colors.indigo, const FoodCategoryManagementScreen()),
      _DeveloperModule(Icons.receipt_long_rounded, 'Orders', 'Monitor orders, status, totals and payments.', Colors.blueGrey, const AdminOrderManagementScreen()),
      _DeveloperModule(Icons.workspace_premium_rounded, 'Subscriptions', 'Manage plans and subscription payments.', Colors.deepPurple, const AdminSaasSubscriptionHubScreen()),
      _DeveloperModule(Icons.verified_rounded, 'Halal Verification', 'Review halal verification requests.', Colors.green, const HalalVerificationScreen()),
      _DeveloperModule(Icons.local_shipping_rounded, 'Delivery Pricing', 'Configure platform delivery pricing.', Colors.orange, const DeliveryPricingScreen()),
      _DeveloperModule(Icons.local_offer_rounded, 'Promos & Discounts', 'Manage promo codes and discounts.', Colors.pink, const PromoManagementScreen()),
      _DeveloperModule(Icons.settings_rounded, 'App Settings', 'Control platform-wide application settings.', Colors.grey, const AdminSettingsScreen()),
      _DeveloperModule(Icons.notifications_active_rounded, 'Action Center', 'Review pending platform actions.', Colors.redAccent, const AdminActionCenterScreen()),
      _DeveloperModule(Icons.account_circle_rounded, 'Developer Profile', 'Manage the current developer profile.', Colors.cyan, const AdminProfileScreen()),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 18,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.developer_mode_rounded),
            SizedBox(width: 9),
            Flexible(child: Text('Developer Control Panel', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Logout', onPressed: () => _logout(context), icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final medium = constraints.maxWidth >= 620;
          final columns = wide ? 3 : (medium ? 2 : 1);

          return ListView(
            padding: EdgeInsets.fromLTRB(wide ? 34 : 18, 22, wide ? 34 : 18, 44),
            children: [
              _heroCard(),
              const SizedBox(height: 24),
              _sectionHeader('Platform Control', '${modules.length} modules'),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 132,
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
        Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.2))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8E4))),
          child: Text(count, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: HalalFoodTheme.textSecondary)),
        ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [HalalFoodTheme.primaryGreen, HalalFoodTheme.darkGreen]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: HalalFoodTheme.primaryGreen.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          final content = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Developer Console', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                    SizedBox(height: 6),
                    Text('Platform-wide configuration and maintenance', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    SizedBox(height: 5),
                    Text('Manage the app foundation from one place. Operational Admin functions remain separate.', style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4)),
                  ],
                ),
              ),
            ],
          );

          return compact ? content : Row(children: [Expanded(child: content), const SizedBox(width: 24), _statusPill()]);
        },
      ),
    );
  }

  Widget _statusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.lock_rounded, color: Colors.white, size: 15), SizedBox(width: 7), Text('Developer access', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))]),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19), side: const BorderSide(color: Color(0xFFE4E9E6))),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 13, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 43, height: 43, decoration: BoxDecoration(color: module.color.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(module.icon, color: module.color, size: 22)),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded, color: module.color, size: 17),
                ],
              ),
              const Spacer(),
              Text(module.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(module.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, height: 1.25, color: HalalFoodTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
