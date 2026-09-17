import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';

class DeveloperBrandingScreen extends StatefulWidget {
  const DeveloperBrandingScreen({super.key});

  @override
  State<DeveloperBrandingScreen> createState() => _DeveloperBrandingScreenState();
}

class _DeveloperBrandingScreenState extends State<DeveloperBrandingScreen> {
  final _db = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _logoUrl = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _accent = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _logoUrl.dispose();
    _primary.dispose();
    _secondary.dispose();
    _accent.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final row = await _db.from('app_branding').select().eq('id', true).maybeSingle();
      if (!mounted) return;
      _name.text = row?['app_name']?.toString() ?? 'HALAL Food';
      _logoUrl.text = row?['logo_url']?.toString() ?? '';
      _primary.text = row?['primary_color']?.toString() ?? '#0B6B3A';
      _secondary.text = row?['secondary_color']?.toString() ?? '#064B2A';
      _accent.text = row?['accent_color']?.toString() ?? '#D4A72C';
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Unable to load branding: $e');
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _db.from('app_branding').update({
        'app_name': _name.text.trim(),
        'logo_url': _logoUrl.text.trim().isEmpty ? null : _logoUrl.text.trim(),
        'primary_color': _primary.text.trim().toUpperCase(),
        'secondary_color': _secondary.text.trim().toUpperCase(),
        'accent_color': _accent.text.trim().toUpperCase(),
      }).eq('id', true);
      if (!mounted) return;
      _message('Branding settings saved.');
    } catch (e) {
      if (mounted) _message('Unable to save branding: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _colorValidator(String? value) {
    final v = value?.trim() ?? '';
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v)) return 'Use HEX format, e.g. #0B6B3A';
    return null;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Branding & Theme', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _loading || _saving ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                children: [
                  _preview(),
                  const SizedBox(height: 16),
                  _section('App Identity', Icons.badge_rounded, [
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'App Name', prefixIcon: Icon(Icons.apps_rounded)),
                      validator: (v) => v == null || v.trim().isEmpty ? 'App name is required.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _logoUrl,
                      enabled: !_saving,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: 'Logo URL', prefixIcon: Icon(Icons.image_outlined), hintText: 'https://...'),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _section('Theme Colors', Icons.palette_rounded, [
                    _colorField(_primary, 'Primary Color'),
                    _colorField(_secondary, 'Secondary Color'),
                    _colorField(_accent, 'Accent Color'),
                  ]),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Saving...' : 'Save Branding'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _colorField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.color_lens_outlined)),
        validator: _colorValidator,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: HalalFoodTheme.primaryGreen), const SizedBox(width: 9), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))]),
          const SizedBox(height: 16),
          ...children,
        ]),
      ),
    );
  }

  Widget _preview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_hex(_primary.text, HalalFoodTheme.primaryGreen), _hex(_secondary.text, HalalFoodTheme.darkGreen)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(17)),
          child: _logoUrl.text.trim().isEmpty
              ? const Icon(Icons.restaurant_rounded, color: Colors.white, size: 30)
              : ClipRRect(borderRadius: BorderRadius.circular(17), child: Image.network(_logoUrl.text.trim(), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.restaurant_rounded, color: Colors.white, size: 30))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_name.text.trim().isEmpty ? 'HALAL Food' : _name.text.trim(), style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          const Text('Brand preview', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        Container(width: 24, height: 24, decoration: BoxDecoration(color: _hex(_accent.text, HalalFoodTheme.gold), shape: BoxShape.circle)),
      ]),
    );
  }

  Color _hex(String value, Color fallback) {
    final v = value.trim().replaceFirst('#', '');
    if (v.length != 6) return fallback;
    final parsed = int.tryParse(v, radix: 16);
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }
}
