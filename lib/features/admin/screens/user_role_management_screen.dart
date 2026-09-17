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
      final developer = await _checkDeveloper();
      final users = await _repository.getUsers();
      if (!mounted) return;
      setState(() {
        _isDeveloper = developer;
        _users = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<bool> _checkDeveloper() async {
    final result = await Supabase.instance.client.rpc('is_developer');
    return result == true;
  }

  // Developer is a real profile role now. Admin cannot assign it because
  // developer accounts are protected by developer_access and hidden from Admin.
  List<String> get _allowedRoles => _isDeveloper
      ? const ['customer', 'restaurant_owner', 'admin', 'developer', 'driver']
      : const ['customer', 'restaurant_owner'];

  List<String> get _filters => _isDeveloper
      ? const ['all', 'customer', 'restaurant_owner', 'admin', 'developer', 'driver']
      : const ['all', 'customer', 'restaurant_owner', 'admin', 'driver'];

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
        'developer' => 'Developer',
        'driver' => 'Driver',
        'restaurant_owner' => 'Restaurant Owner',
        _ => 'Customer',
      };

  Color _roleColor(String role) => switch (role) {
        'admin' => Colors.deepPurple,
        'developer' => Colors.indigo,
        'driver' => Colors.orange,
        'restaurant_owner' => HalalFoodTheme.primaryGreen,
        _ => Colors.blue,
      };

  IconData _roleIcon(String role) => switch (role) {
        'admin' => Icons.admin_panel_settings_rounded,
        'developer' => Icons.developer_mode_rounded,
        'driver' => Icons.delivery_dining_rounded,
        'restaurant_owner' => Icons.storefront_rounded,
        _ => Icons.person_rounded,
      };

  bool _canChangeRole(String role) => _isDeveloper &&
      const ['customer', 'restaurant_owner', 'admin', 'developer', 'driver'].contains(role);

  Future<void> _changeRole(Map<String, dynamic> user) async {
    final id = user['id']?.toString();
    final current = user['role']?.toString() ?? 'customer';
    if (id == null || id.isEmpty || !_canChangeRole(current)) return;

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _RoleDialog(
        currentRole: current,
        allowedRoles: _allowedRoles,
        isDeveloper: _isDeveloper,
      ),
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

  Future<void> _editProfile(Map<String, dynamic> user) async {
    final id = user['id']?.toString();
    if (id == null || id.isEmpty) return;

    final result = await showDialog<_ProfileEditResult>(
      context: context,
      builder: (_) => _EditProfileDialog(user: user),
    );
    if (result == null || !mounted) return;

    try {
      await _repository.updateProfile(
        userId: id,
        fullName: result.fullName,
        phone: result.phone,
      );
      await _load();
      if (mounted) _message('User profile updated successfully.');
    } catch (e) {
      if (mounted) _message('Unable to update profile: $e');
    }
  }

  void _showDetails(Map<String, dynamic> user) {
    final role = user['role']?.toString() ?? 'customer';
    final canChange = _canChangeRole(role);
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
                  user['full_name']?.toString().trim().isNotEmpty == true
                      ? user['full_name'].toString()
                      : 'Unnamed User',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                )),
              ]),
              const SizedBox(height: 18),
              _DetailRow('Role', _roleLabel(role)),
              _DetailRow(
                'Phone',
                user['phone']?.toString().trim().isNotEmpty == true
                    ? user['phone'].toString()
                    : 'Not provided',
              ),
              _DetailRow('User ID', user['id']?.toString() ?? 'Unknown'),
              _DetailRow('Joined', _formatDate(user['created_at']?.toString())),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _editProfile(user);
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Edit Profile'),
                  ),
                ),
                if (canChange) ...[
                  const SizedBox(width: 10),
                  Expanded(
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
              ]),
              if (!canChange && !_isDeveloper) ...[
                const SizedBox(height: 10),
                const Text(
                  'Admin can change roles only for Customer and Restaurant Owner accounts.',
                  style: TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary),
                ),
              ],
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isDeveloper ? 'Users & Roles — Developer' : 'Users & Roles',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
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
                      _PermissionBanner(isDeveloper: _isDeveloper),
                      const SizedBox(height: 14),
                      _Summary(users: _users),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _search = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search name, phone or role...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _search = '');
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 42,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final role in _filters)
                              _FilterChip(
                                _filterLabel(role),
                                role,
                                _filter,
                                (v) => setState(() => _filter = v),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${users.length} user${users.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: HalalFoodTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (users.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 80),
                          child: Center(child: Text('No users found.')),
                        )
                      else
                        ...users.map(_userCard),
                    ],
                  ),
                ),
    );
  }

  String _filterLabel(String role) => switch (role) {
        'all' => 'All',
        'restaurant_owner' => 'Restaurant Owners',
        'admin' => 'Admins',
        'developer' => 'Developers',
        'driver' => 'Drivers',
        _ => 'Customers',
      };

  Widget _userCard(Map<String, dynamic> user) {
    final role = user['role']?.toString() ?? 'customer';
    final color = _roleColor(role);
    final name = user['full_name']?.toString().trim();
    final displayName = name == null || name.isEmpty ? 'Unnamed User' : name;
    final phone = user['phone']?.toString().trim();
    final canChange = _canChangeRole(role);

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone == null || phone.isEmpty ? 'No phone number' : phone,
                    style: const TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      _Badge(_roleLabel(role), color),
                      if (!canChange && !_isDeveloper) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.lock_outline_rounded, size: 14, color: HalalFoodTheme.textSecondary),
                        const SizedBox(width: 3),
                        const Text('Role locked', style: TextStyle(fontSize: 9, color: HalalFoodTheme.textSecondary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ]),
        ),
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final bool isDeveloper;
  const _PermissionBanner({required this.isDeveloper});

  @override
  Widget build(BuildContext context) {
    final title = isDeveloper ? 'Developer role management' : 'Admin role management';
    final text = isDeveloper
        ? 'You can assign Customer, Restaurant Owner, Admin, Developer and Driver roles.'
        : 'You can change only Customer and Restaurant Owner roles. Developer accounts remain hidden.';
    return Card(
      color: (isDeveloper ? Colors.indigo : HalalFoodTheme.primaryGreen).withValues(alpha: .08),
      child: ListTile(
        leading: Icon(
          isDeveloper ? Icons.developer_mode_rounded : Icons.admin_panel_settings_rounded,
          color: isDeveloper ? Colors.indigo : HalalFoodTheme.primaryGreen,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(text),
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
    final developers = users.where((u) => u['role'] == 'developer').length;
    final drivers = users.where((u) => u['role'] == 'driver').length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          runSpacing: 12,
          children: [
            _Metric('Total', users.length, Icons.people_alt_rounded, HalalFoodTheme.primaryGreen),
            _Metric('Admins', admins, Icons.admin_panel_settings_rounded, Colors.deepPurple),
            _Metric('Owners', owners, Icons.storefront_rounded, Colors.teal),
            _Metric('Customers', customers, Icons.person_rounded, Colors.blue),
            if (developers > 0) _Metric('Developers', developers, Icons.developer_mode_rounded, Colors.indigo),
            if (drivers > 0) _Metric('Drivers', drivers, Icons.delivery_dining_rounded, Colors.orange),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _Metric(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 72,
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(fontSize: 9, color: HalalFoodTheme.textSecondary)),
          ],
        ),
      );
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
  void initState() {
    super.initState();
    _selected = widget.allowedRoles.contains(widget.currentRole)
        ? widget.currentRole
        : widget.allowedRoles.first;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
          widget.isDeveloper ? 'Set User Role' : 'Change User Role',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isDeveloper)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Developer access is protected separately. The Developer profile role is available only to a Developer.',
                  style: TextStyle(fontSize: 11, color: HalalFoodTheme.textSecondary),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Role'),
              items: widget.allowedRoles
                  .map((role) => DropdownMenuItem(value: role, child: Text(_roleLabelStatic(role))))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selected = v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Save')),
        ],
      );

  String _roleLabelStatic(String role) => switch (role) {
        'admin' => 'Admin',
        'developer' => 'Developer',
        'driver' => 'Driver',
        'restaurant_owner' => 'Restaurant Owner',
        _ => 'Customer',
      };
}

class _ProfileEditResult {
  final String fullName;
  final String phone;
  const _ProfileEditResult(this.fullName, this.phone);
}

class _EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> user;
  const _EditProfileDialog({required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user['full_name']?.toString() ?? '');
    _phone = TextEditingController(text: widget.user['phone']?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Edit User Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Full Name is required.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(context, _ProfileEditResult(_name.text.trim(), _phone.text.trim()));
            },
            child: const Text('Save Changes'),
          ),
        ],
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;
  const _FilterChip(this.label, this.value, this.selected, this.onSelected);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: selected == value,
          onSelected: (_) => onSelected(value),
        ),
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(label, style: const TextStyle(fontSize: 12, color: HalalFoodTheme.textSecondary)),
            ),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text('Unable to load users', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, maxLines: 5, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Try Again')),
            ],
          ),
        ),
      );
}