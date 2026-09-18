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
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = theme.extension<HalalFoodBrandExtension>();
    final primary = brand?.primary ?? theme.colorScheme.primary;
    final secondary = brand?.secondary ?? theme.colorScheme.primaryContainer;
    final surface = brand?.surface ?? theme.colorScheme.surface;
    final border = brand?.border ?? theme.colorScheme.outlineVariant;

    final groups = <_DeveloperGroup>[
      _DeveloperGroup(
        title: 'Overview & Access',
        subtitle: 'Identity, users and pending platform actions',
        icon: Icons.dashboard_customize_rounded,
        color: primary,
        modules: [
          _DeveloperModule(
            Icons.people_outline_rounded,
            'Users & Roles',
            'Manage platform users and roles.',
            const UserRoleManagementScreen(),
          ),
          _DeveloperModule(
            Icons.notifications_none_rounded,
            'Action Center',
            'Review pending platform actions.',
            const AdminActionCenterScreen(),
          ),
          _DeveloperModule(
            Icons.account_circle_outlined,
            'Developer Profile',
            'Manage the current developer profile.',
            const AdminProfileScreen(),
          ),
        ],
      ),
      _DeveloperGroup(
        title: 'Platform Operations',
        subtitle: 'Restaurants, orders, subscriptions and delivery',
        icon: Icons.settings_suggest_outlined,
        color: Colors.indigo,
        modules: [
          _DeveloperModule(
            Icons.storefront_outlined,
            'Restaurants',
            'Restaurant maintenance and control.',
            const DeveloperRestaurantManagementScreen(),
          ),
          _DeveloperModule(
            Icons.receipt_long_outlined,
            'Orders',
            'Monitor orders and payments.',
            const AdminOrderManagementScreen(),
          ),
          _DeveloperModule(
            Icons.workspace_premium_outlined,
            'Subscriptions',
            'Plans and subscription payments.',
            const AdminSaasSubscriptionHubScreen(),
          ),
          _DeveloperModule(
            Icons.verified_outlined,
            'Halal Verification',
            'Review halal verification requests.',
            const HalalVerificationScreen(),
          ),
          _DeveloperModule(
            Icons.local_shipping_outlined,
            'Delivery Pricing',
            'Configure delivery pricing.',
            const DeliveryPricingScreen(),
          ),
        ],
      ),
      _DeveloperGroup(
        title: 'Catalog & Growth',
        subtitle: 'Menu, categories and promotional tools',
        icon: Icons.storefront_rounded,
        color: Colors.deepOrange,
        modules: [
          _DeveloperModule(
            Icons.restaurant_menu_outlined,
            'Menus',
            'Manage menu items across restaurants.',
            const AdminMenuManagementScreen(),
          ),
          _DeveloperModule(
            Icons.category_outlined,
            'Food Categories',
            'Manage global food categories.',
            const FoodCategoryManagementScreen(),
          ),
          _DeveloperModule(
            Icons.local_offer_outlined,
            'Promos & Discounts',
            'Manage promo codes and discounts.',
            const PromoManagementScreen(),
          ),
        ],
      ),
      _DeveloperGroup(
        title: 'System',
        subtitle: 'Global branding and platform configuration',
        icon: Icons.tune_rounded,
        color: Colors.blueGrey,
        modules: [
          _DeveloperModule(
            Icons.palette_outlined,
            'Branding & Theme',
            'Global app identity and colors.',
            const DeveloperBrandingScreen(),
            featured: true,
          ),
          _DeveloperModule(
            Icons.settings_outlined,
            'App Settings',
            'Platform-wide application settings.',
            const AdminSettingsScreen(),
          ),
        ],
      ),
    ];

    final moduleCount = groups.fold<int>(
      0,
      (total, group) => total + group.modules.length,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.developer_mode_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            const Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Developer Console',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'HALAL Food platform control',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withValues(alpha: .14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: primary,
                ),
                const SizedBox(width: 5),
                Text(
                  'Developer',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
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
          final wide = constraints.maxWidth >= 1180;
          final medium = constraints.maxWidth >= 760;
          final horizontal = wide ? 42.0 : (medium ? 28.0 : 16.0);

          return ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 40),
            children: [
              _hero(
                context,
                primary: primary,
                secondary: secondary,
                surface: surface,
                border: border,
                moduleCount: moduleCount,
              ),
              const SizedBox(height: 24),
              _sectionTitle(
                context,
                'Developer Areas',
                'Choose a base category to open its management sections.',
              ),
              const SizedBox(height: 12),
              _groupGrid(
                context,
                groups,
                wide: wide,
              ),
            ],
          );
        },
      ),
    );
  }

  void _openGroup(BuildContext context, _DeveloperGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DeveloperGroupHubScreen(group: group),
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 11.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _groupGrid(
    BuildContext context,
    List<_DeveloperGroup> groups, {
    required bool wide,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groups.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 2 : 1,
        mainAxisExtent: 122,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, index) {
        final group = groups[index];
        return _DeveloperGroupCard(
          group: group,
          onTap: () => _openGroup(context, group),
        );
      },
    );
  }

  Widget _hero(
    BuildContext context, {
    required Color primary,
    required Color secondary,
    required Color surface,
    required Color border,
    required int moduleCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 600;

          final intro = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Control Center',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Manage the HALAL Food platform from one protected workspace.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final stats = Row(
            children: [
              _stat(
                context,
                Icons.apps_rounded,
                '$moduleCount',
                'Modules',
                primary,
              ),
              const SizedBox(width: 10),
              _stat(
                context,
                Icons.security_rounded,
                'Protected',
                'Access',
                primary,
              ),
              const SizedBox(width: 10),
              _stat(
                context,
                Icons.public_rounded,
                'Global',
                'Platform',
                primary,
              ),
            ],
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    intro,
                    const SizedBox(height: 18),
                    stats,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: intro),
                    const SizedBox(width: 28),
                    SizedBox(width: 360, child: stats),
                  ],
                );
        },
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color primary,
  ) {
    final surface = Theme.of(context).colorScheme.surfaceContainerLow;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupHeader(BuildContext context, _DeveloperGroup group) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: group.color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(group.icon, size: 18, color: group.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                group.subtitle,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _moduleGrid(
    BuildContext context,
    _DeveloperGroup group, {
    required bool wide,
    required bool medium,
  }) {
    final modules = group.modules;
    final columns = wide ? 3 : (medium ? 2 : 1);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 11,
        mainAxisSpacing: 11,
        mainAxisExtent: 112,
      ),
      itemBuilder: (context, index) {
        final module = modules[index];
        return _ModuleCard(
          module: module,
          groupColor: group.color,
          onTap: () => _open(context, module.screen),
        );
      },
    );
  }

}

class _DeveloperGroup {
  const _DeveloperGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.modules,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_DeveloperModule> modules;
}

class _DeveloperModule {
  const _DeveloperModule(
    this.icon,
    this.title,
    this.subtitle,
    this.screen, {
    this.featured = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget screen;
  final bool featured;
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.groupColor,
    required this.onTap,
  });

  final _DeveloperModule module;
  final Color groupColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = theme.extension<HalalFoodBrandExtension>();
    final primary = brand?.primary ?? theme.colorScheme.primary;
    final border = brand?.border ?? theme.colorScheme.outlineVariant;
    final iconColor = module.featured ? primary : groupColor;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: module.featured
                  ? primary.withValues(alpha: .35)
                  : border,
            ),
            boxShadow: module.featured
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: .07),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: module.featured
                      ? primary.withValues(alpha: .10)
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  module.icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            module.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      module.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.25,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (module.featured) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Global theme',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
