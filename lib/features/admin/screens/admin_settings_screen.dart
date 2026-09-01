import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _maintenance = false;
  bool _acceptOrders = true;
  bool _customerRegistration = true;
  bool _ownerSubmission = true;
  bool _customerNotifications = true;
  bool _ownerNotifications = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await _supabase
          .from('app_settings')
          .select()
          .eq('id', true)
          .maybeSingle();
      if (!mounted) return;
      if (row != null) {
        _maintenance = row['maintenance_mode'] == true;
        _acceptOrders = row['accept_new_orders'] != false;
        _customerRegistration = row['allow_customer_registration'] != false;
        _ownerSubmission = row['allow_owner_restaurant_submission'] != false;
        _customerNotifications = row['customer_notifications'] != false;
        _ownerNotifications = row['owner_notifications'] != false;
      }
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _supabase.from('app_settings').update({
        'maintenance_mode': _maintenance,
        'accept_new_orders': _acceptOrders,
        'allow_customer_registration': _customerRegistration,
        'allow_owner_restaurant_submission': _ownerSubmission,
        'customer_notifications': _customerNotifications,
        'owner_notifications': _ownerNotifications,
      }).eq('id', true);
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Platform settings saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message('Unable to save settings: $e');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Platform Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                  children: [
                    _introCard(),
                    const SizedBox(height: 16),
                    _section(
                      'Platform Availability',
                      Icons.public_rounded,
                      [
                        _setting(
                          'Maintenance Mode',
                          'Temporarily place the platform in maintenance mode.',
                          Icons.construction_rounded,
                          _maintenance,
                          (v) => setState(() => _maintenance = v),
                          danger: true,
                        ),
                        _setting(
                          'Accept New Orders',
                          'Allow customers to submit new orders.',
                          Icons.shopping_bag_rounded,
                          _acceptOrders,
                          (v) => setState(() => _acceptOrders = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _section(
                      'Account & Submissions',
                      Icons.manage_accounts_rounded,
                      [
                        _setting(
                          'Customer Registration',
                          'Allow new customers to create accounts.',
                          Icons.person_add_alt_1_rounded,
                          _customerRegistration,
                          (v) => setState(() => _customerRegistration = v),
                        ),
                        _setting(
                          'Owner Restaurant Submission',
                          'Allow restaurant owners to submit restaurants for review.',
                          Icons.storefront_rounded,
                          _ownerSubmission,
                          (v) => setState(() => _ownerSubmission = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _section(
                      'Notifications',
                      Icons.notifications_active_outlined,
                      [
                        _setting(
                          'Customer Notifications',
                          'Enable customer-facing order and platform notifications.',
                          Icons.notifications_outlined,
                          _customerNotifications,
                          (v) => setState(() => _customerNotifications = v),
                        ),
                        _setting(
                          'Owner Notifications',
                          'Enable restaurant-owner order and platform notifications.',
                          Icons.notifications_none_rounded,
                          _ownerNotifications,
                          (v) => setState(() => _ownerNotifications = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'Saving...' : 'Save Settings'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _introCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [HalalFoodTheme.primaryGreen, HalalFoodTheme.primaryGreen.withValues(alpha: .82)],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          children: [
            Icon(Icons.settings_rounded, color: Colors.white, size: 38),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('System Configuration', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 5),
                  Text('Control important platform-wide behavior from one place.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: HalalFoodTheme.primaryGreen, size: 21),
                const SizedBox(width: 9),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 7),
              ...children,
            ],
          ),
        ),
      );

  Widget _setting(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged, {bool danger = false}) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, color: danger && value ? Colors.redAccent : HalalFoodTheme.textSecondary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary)),
        value: value,
        onChanged: _saving ? null : onChanged,
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text('Unable to load platform settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(_error ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('Try Again')),
            ],
          ),
        ),
      );
}
