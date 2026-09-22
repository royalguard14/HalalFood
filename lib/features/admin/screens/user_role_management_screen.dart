import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../data/admin_user_repository.dart';

class UserRoleManagementScreen extends StatefulWidget {
  const UserRoleManagementScreen({super.key});

  @override
  State<UserRoleManagementScreen> createState() => _UserRoleManagementScreenState();
}

class _UserRoleManagementScreenState extends State<UserRoleManagementScreen> {
  final _repository = AdminUserRepository();
  final _searchController = TextEditingController();
  bool _loading = true;
  bool _isDeveloper = false;
  String? _error;
  String _search = '';
  String _filter = 'all';
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _searchController.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final developer = await _checkDeveloper();
      final users = await _repository.getUsers();
      if (!mounted) return;
      setState(() { _isDeveloper = developer; _users = users; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<bool> _checkDeveloper() async => await Supabase.instance.client.rpc('is_developer') == true;

  List<String> get _allowedRoles => _isDeveloper
      ? const ['customer', 'restaurant_owner', 'admin', 'developer', 'driver']
      : const ['customer', 'restaurant_owner', 'driver'];

  List<String> get _filters => _isDeveloper
      ? const ['all', 'customer', 'restaurant_owner', 'admin', 'developer', 'driver']
      : const ['all', 'customer', 'restaurant_owner', 'admin', 'driver'];

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase();
    return _users.where((u) {
      final name = u['full_name']?.toString().toLowerCase() ?? '';
      final phone = u['phone']?.toString().toLowerCase() ?? '';
      final role = u['role']?.toString().toLowerCase() ?? 'customer';
      return (q.isEmpty || name.contains(q) || phone.contains(q) || role.contains(q)) &&
          (_filter == 'all' || role == _filter);
    }).toList();
  }

  String _roleLabel(String role) => switch (role) {
    'admin' => 'Admin', 'developer' => 'Developer', 'driver' => 'Rider',
    'restaurant_owner' => 'Restaurant Owner', _ => 'Customer',
  };

  Color _roleColor(String role) => switch (role) {
    'admin' => Colors.deepPurple, 'developer' => Colors.indigo, 'driver' => Colors.orange,
    'restaurant_owner' => HalalFoodTheme.primaryGreen, _ => Colors.blue,
  };

  IconData _roleIcon(String role) => switch (role) {
    'admin' => Icons.admin_panel_settings_rounded, 'developer' => Icons.developer_mode_rounded,
    'driver' => Icons.delivery_dining_rounded, 'restaurant_owner' => Icons.storefront_rounded,
    _ => Icons.person_rounded,
  };

  bool _canChangeRole(String role) => _isDeveloper
      ? const ['customer', 'restaurant_owner', 'admin', 'developer', 'driver'].contains(role)
      : const ['customer', 'restaurant_owner', 'driver'].contains(role);

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final id = user['id']?.toString();
    final current = user['role']?.toString() ?? 'customer';
    if (id == null || id.isEmpty || !_canChangeRole(current)) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _RoleDialog(currentRole: current, allowedRoles: _allowedRoles, isDeveloper: _isDeveloper),
    );
    if (selected == null || selected == current || !mounted) return;
    try {
      await _repository.updateRole(userId: id, role: selected);
      await _load();
      if (mounted) _message('Role updated to ${_roleLabel(selected)}.');
    } catch (e) { if (mounted) _message('Unable to update role: $e'); }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
    return Scaffold(
      appBar: AppBar(title: Text(_isDeveloper ? 'Users & Roles — Developer' : 'Users & Roles', style: const TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), ElevatedButton(onPressed: _load, child: const Text('Try Again'))]))
          : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
              Card(child: ListTile(leading: const Icon(Icons.admin_panel_settings_rounded), title: Text(_isDeveloper ? 'Developer role management' : 'Admin role management', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(_isDeveloper ? 'You can assign Customer, Restaurant Owner, Admin, Developer and Rider roles.' : 'You can change Customer, Restaurant Owner and Rider roles. Developer accounts remain hidden.'))),
              const SizedBox(height: 14),
              TextField(controller: _searchController, onChanged: (v) => setState(() => _search = v.trim()), decoration: const InputDecoration(hintText: 'Search name, phone or role...', prefixIcon: Icon(Icons.search_rounded))),
              const SizedBox(height: 10),
              SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: [for (final r in _filters) Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(_filterLabel(r)), selected: _filter == r, onSelected: (_) => setState(() => _filter = r)))])),
              const SizedBox(height: 12),
              ...users.map(_userCard),
            ])),
    );
  }

  String _filterLabel(String role) => switch (role) {
    'all' => 'All', 'restaurant_owner' => 'Restaurant Owners', 'admin' => 'Admins',
    'developer' => 'Developers', 'driver' => 'Riders', _ => 'Customers',
  };

  Widget _userCard(Map<String, dynamic> user) {
    final role = user['role']?.toString() ?? 'customer';
    final color = _roleColor(role);
    final name = user['full_name']?.toString().trim();
    final canChange = _canChangeRole(role);
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: .10), child: Icon(_roleIcon(role), color: color)),
      title: Text(name == null || name.isEmpty ? 'Unnamed User' : name, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${_roleLabel(role)} • ${user['phone']?.toString().trim().isEmpty == false ? user['phone'] : 'No phone number'}'),
      trailing: canChange ? const Icon(Icons.chevron_right_rounded) : const Icon(Icons.lock_outline_rounded),
      onTap: canChange ? () => _changeRole(user) : null,
    ));
  }
}

class _RoleDialog extends StatefulWidget {
  final String currentRole;
  final List<String> allowedRoles;
  final bool isDeveloper;
  const _RoleDialog({required this.currentRole, required this.allowedRoles, required this.isDeveloper});
  @override
  State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late String _selected;
  @override
  void initState() { super.initState(); _selected = widget.allowedRoles.contains(widget.currentRole) ? widget.currentRole : widget.allowedRoles.first; }
  String _label(String role) => switch (role) { 'admin' => 'Admin', 'developer' => 'Developer', 'driver' => 'Rider', 'restaurant_owner' => 'Restaurant Owner', _ => 'Customer' };
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.isDeveloper ? 'Set User Role' : 'Change User Role', style: const TextStyle(fontWeight: FontWeight.w800)),
    content: DropdownButtonFormField<String>(
      initialValue: _selected,
      decoration: const InputDecoration(labelText: 'Role'),
      items: widget.allowedRoles.map((r) => DropdownMenuItem(value: r, child: Text(_label(r)))).toList(),
      onChanged: (v) { if (v != null) setState(() => _selected = v); },
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Save'))],
  );
}
