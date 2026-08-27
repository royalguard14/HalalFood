import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _changingPassword = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  String? _error;

  User? get _user => _supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _user;
    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No authenticated admin account found.';
        });
      }
      return;
    }

    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name, phone, role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (row != null && row['role']?.toString() != 'admin') {
        setState(() {
          _loading = false;
          _error = 'This account is not an admin account.';
        });
        return;
      }

      _name.text = row?['full_name']?.toString() ??
          user.userMetadata?['full_name']?.toString() ??
          '';
      _phone.text = row?['phone']?.toString() ?? '';

      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    final user = _user;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      await _supabase.from('profiles').update({
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      }).eq('id', user.id);

      await _supabase.auth.updateUser(
        UserAttributes(data: {'full_name': _name.text.trim()}),
      );

      if (!mounted) return;
      setState(() => _saving = false);
      _message('Profile updated successfully.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Unable to update profile: $e');
      }
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPassword.text;
    final next = _newPassword.text;
    final confirm = _confirmPassword.text;

    if (current.isEmpty) {
      _message('Enter your current password.');
      return;
    }
    if (next.length < 8) {
      _message('New password must be at least 8 characters.');
      return;
    }
    if (next != confirm) {
      _message('New passwords do not match.');
      return;
    }

    final user = _user;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) {
      _message('Unable to verify the admin account email.');
      return;
    }
    if (_changingPassword) return;

    setState(() => _changingPassword = true);

    try {
      final result = await _supabase.auth.signInWithPassword(
        email: email,
        password: current,
      );

      if (result.user == null) {
        throw Exception('Current password is incorrect.');
      }

      await _supabase.auth.updateUser(UserAttributes(password: next));

      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _changingPassword = false);
      _message('Password changed successfully.');
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _changingPassword = false);
        _message('Unable to change password: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _changingPassword = false);
        _message('Unable to change password: $e');
      }
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
                    children: [
                      _header(),
                      const SizedBox(height: 18),
                      _profileSection(),
                      const SizedBox(height: 16),
                      _passwordSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _profileSection() {
    return _sectionCard(
      'Personal Information',
      Icons.person_outline_rounded,
      Column(
        children: [
          TextFormField(
            controller: _name,
            enabled: !_saving,
            textCapitalization: TextCapitalization.words,
            decoration: _decoration('Full Name', Icons.person_rounded),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Full name is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
            decoration: _decoration('Phone Number', Icons.phone_outlined),
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: _user?.email ?? '',
            readOnly: true,
            decoration: _decoration('Email Address', Icons.email_outlined)
                .copyWith(helperText: 'Login email address.'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveProfile,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving...' : 'Save Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordSection() {
    return _sectionCard(
      'Change Password',
      Icons.lock_outline_rounded,
      Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Confirm your current password before setting a new one.',
              style: TextStyle(
                fontSize: 12,
                color: HalalFoodTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _passwordField(
            _currentPassword,
            'Current Password',
            _hideCurrent,
            () => setState(() => _hideCurrent = !_hideCurrent),
            Icons.lock_person_outlined,
          ),
          const SizedBox(height: 12),
          _passwordField(
            _newPassword,
            'New Password',
            _hideNew,
            () => setState(() => _hideNew = !_hideNew),
            Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 12),
          _passwordField(
            _confirmPassword,
            'Confirm New Password',
            _hideConfirm,
            () => setState(() => _hideConfirm = !_hideConfirm),
            Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _changingPassword ? null : _changePassword,
              icon: _changingPassword
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.key_rounded),
              label: Text(
                _changingPassword ? 'Changing Password...' : 'Change Password',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    bool hidden,
    VoidCallback toggle,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      enabled: !_changingPassword,
      obscureText: hidden,
      decoration: _decoration(label, icon).copyWith(
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(
            hidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final displayName = _name.text.trim().isEmpty ? 'Admin' : _name.text.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HalalFoodTheme.primaryGreen,
            HalalFoodTheme.primaryGreen.withValues(alpha: .82),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: Colors.white.withValues(alpha: .16),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _user?.email ?? 'Admin account',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(String title, IconData icon, Widget child) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: HalalFoodTheme.primaryGreen.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: HalalFoodTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            child,
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unable to load admin profile.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
