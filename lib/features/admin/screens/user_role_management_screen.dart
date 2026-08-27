import 'package:flutter/material.dart';

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
  String? _error;
  String _search = '';
  String _filter = 'all';
  List<Map<String, dynamic>> _users = [];

  static const _roles = <String>['admin', 'restaurant_owner', 'customer'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final users = await _repository.getUsers();
      if (!mounted) return;
      setState(() { _users = users; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase();
    return _users.where((user) {
      final name = user['full_name']?.toString().toLowerCase() ?? '';
      final phone = user['phone']?.toString().toLowerCase() ?? '';
      final role = user['role']?.toString().toLowerCase() ?? 'customer';
      final matchesSearch = q.isEmpty || name.contains(q) || phone.contains(q) || role.contains(q);
      final matchesFilter = _filter == 'all' || role == _filter;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  String _roleLabel(String role) => switch (role) {
        'admin' => 'Admin',
        'restaurant_owner' => 'Restaurant Owner',
        _ => 'Customer',
      };

  Color _roleColor(String role) => switch (role) {
        'admin' => Colors.deepPurple,
        'restaurant_owner' => HalalFoodTheme.primaryGreen,
        _ => Colors.blue,
      };

  IconData _roleIcon(String role) => switch (role) {
        'admin' => Icons.admin_panel_settings_rounded,
        'restaurant_owner' => Icons.storefront_rounded,
        _ => Icons.person_rounded,
      };

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final id = user['id']?.toString();
    final current = user['role']?.toString() ?? 'customer';
    if (id == null || id.isEmpty) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RoleDialog(currentRole: current),
    );
    if (selected == null || selected == current || !mounted) return;

    try {
      await _repository.updateRole(userId: id, role: selected);
      await _load();
      if (mounted) _message('Role updated to ${_roleLabel(selected)}.');
    } catch (e) {
      if (mounted) _message('Unable to update role: $e');
    }
  }

  void _showDetails(Map<String, dynamic> user) {
    final role = user['role']?.toString() ?? 'customer';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _roleColor(role).withValues(alpha: .10),
                  child: Icon(_roleIcon(role), color: _roleColor(role), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(
                  user['full_name']?.toString().trim().isNotEmpty == true ? user['full_name'].toString() : 'Unnamed User',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                )),
              ]),
              const SizedBox(height: 18),
              _DetailRow('Role', _roleLabel(role)),
              _DetailRow('Phone', user['phone']?.toString().trim().isNotEmpty == true ? user['phone'].toString() : 'Not provided'),
              _DetailRow('User ID', user['id']?.toString() ?? 'Unknown'),
              _DetailRow('Joined', _formatDate(user['created_at']?.toString())),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _changeRole(user);
                  },
                  icon: const Icon(Icons.manage_accounts_rounded),
                  label: const Text('Change Role'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Unknown';
    final date = DateTime.tryParse(raw)?.toLocal();
    if (date == null) return 'Unknown';
    return '${date.month}/${date.day}/${date.year}';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users & Roles', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    children: [
                      _Summary(users: _users),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _search = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search name, phone or role...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.isEmpty ? null : IconButton(onPressed: () { _searchController.clear(); setState(() => _search = ''); }, icon: const Icon(Icons.clear_rounded)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterChip('All', 'all', _filter, (v) => setState(() => _filter = v)),
                            _FilterChip('Admins', 'admin', _filter, (v) => setState(() => _filter = v)),
                            _FilterChip('Restaurant Owners', 'restaurant_owner', _filter, (v) => setState(() => _filter = v)),
                            _FilterChip('Customers', 'customer', _filter, (v) => setState(() => _filter = v)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('${users.length} user${users.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w700, color: HalalFoodTheme.textSecondary)),
                      const SizedBox(height: 8),
                      if (users.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: Text('No users found.')))
                      else
                        ...users.map(_userCard),
                    ],
                  ),
                ),
    );
  }

  Widget _userCard(Map<String, dynamic> user) {
    final role = user['role']?.toString() ?? 'customer';
    final color = _roleColor(role);
    final name = user['full_name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'Unnamed User' : name;
    final phone = user['phone']?.toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(user),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
          child: Row(children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: color.withValues(alpha: .10),
              child: Icon(_roleIcon(role), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text(phone == null || phone.isEmpty ? 'No phone number' : phone, style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary)),
              const SizedBox(height: 7),
              _Badge(_roleLabel(role), color),
            ])),
            Icon(Icons.chevron_right_rounded, color: color),
          ]),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  const _Summary({required this.users});

  @override
  Widget build(BuildContext context) {
    final admins = users.where((u) => u['role'] == 'admin').length;
    final owners = users.where((u) => u['role'] == 'restaurant_owner').length;
    final customers = users.where((u) => u['role'] == 'customer').length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(children: [
          Expanded(child: _Metric('Total', users.length, Icons.people_alt_rounded, HalalFoodTheme.primaryGreen)),
          Expanded(child: _Metric('Admins', admins, Icons.admin_panel_settings_rounded, Colors.deepPurple)),
          Expanded(child: _Metric('Owners', owners, Icons.storefront_rounded, Colors.teal)),
          Expanded(child: _Metric('Customers', customers, Icons.person_rounded, Colors.blue)),
        ]),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label; final int value; final IconData icon; final Color color;
  const _Metric(this.label, this.value, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [Icon(icon, size: 20, color: color), const SizedBox(height: 4), Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(fontSize: 9, color: HalalFoodTheme.textSecondary))]);
}

class _RoleDialog extends StatefulWidget {
  final String currentRole;
  const _RoleDialog({required this.currentRole});
  @override State<_RoleDialog> createState() => _RoleDialogState();
}

class _RoleDialogState extends State<_RoleDialog> {
  late String _selected;
  @override void initState() { super.initState(); _selected = widget.currentRole; }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Change User Role', style: TextStyle(fontWeight: FontWeight.w800)),
    content: DropdownButtonFormField<String>(
      initialValue: _selected,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Role'),
      items: const [
        DropdownMenuItem(value: 'customer', child: Text('Customer')),
        DropdownMenuItem(value: 'restaurant_owner', child: Text('Restaurant Owner')),
        DropdownMenuItem(value: 'admin', child: Text('Admin')),
      ],
      onChanged: (v) { if (v != null) setState(() => _selected = v); },
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ElevatedButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Save')),
    ],
  );
}

class _FilterChip extends StatelessWidget {
  final String label, value, selected; final ValueChanged<String> onSelected;
  const _FilterChip(this.label, this.value, this.selected, this.onSelected);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(label), selected: selected == value, onSelected: (_) => onSelected(value)));
}

class _Badge extends StatelessWidget {
  final String label; final Color color;
  const _Badge(this.label, this.color);
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)));
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary))), Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))]));
}

class _ErrorView extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent), const SizedBox(height: 12), const Text('Unable to load users', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis), const SizedBox(height: 16), ElevatedButton(onPressed: onRetry, child: const Text('Try Again'))])));
}
