import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../auth/screens/login_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Control Panel'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: HalalFoodTheme.primary.withValues(alpha: 0.08),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.developer_mode, size: 34),
                  SizedBox(height: 12),
                  Text(
                    'Developer / Super Admin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Protected developer area. Control modules will be added here step-by-step.',
                    style: TextStyle(color: HalalFoodTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ModuleCard(icon: Icons.people_outline, title: 'Users & Roles'),
            _ModuleCard(icon: Icons.storefront_outlined, title: 'Restaurants'),
            _ModuleCard(icon: Icons.restaurant_menu_outlined, title: 'Menus & Categories'),
            _ModuleCard(icon: Icons.receipt_long_outlined, title: 'Orders & Payments'),
            _ModuleCard(icon: Icons.card_membership_outlined, title: 'Subscriptions'),
            _ModuleCard(icon: Icons.verified_outlined, title: 'Halal Verification'),
            _ModuleCard(icon: Icons.local_shipping_outlined, title: 'Delivery Pricing'),
            _ModuleCard(icon: Icons.palette_outlined, title: 'Branding & Theme'),
            _ModuleCard(icon: Icons.settings_outlined, title: 'App Settings'),
            _ModuleCard(icon: Icons.build_outlined, title: 'Maintenance Tools'),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title module will be added next.')),
          );
        },
      ),
    );
  }
}
