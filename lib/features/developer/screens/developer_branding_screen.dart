import 'package:flutter/material.dart';

import '../data/brand_config_repository.dart';

class DeveloperBrandingScreen extends StatefulWidget {
  const DeveloperBrandingScreen({super.key});

  @override
  State<DeveloperBrandingScreen> createState() => _DeveloperBrandingScreenState();
}

class _DeveloperBrandingScreenState extends State<DeveloperBrandingScreen> {
  final _repository = BrandConfigRepository();
  final _key = TextEditingController();
  final _name = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _accent = TextEditingController();
  final _background = TextEditingController();
  final _surface = TextEditingController();
  final _textPrimary = TextEditingController();
  final _textSecondary = TextEditingController();
  final _border = TextEditingController();

  List<BrandConfig> _brands = [];
  BrandConfig? _selected;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_key, _name, _primary, _secondary, _accent, _background, _surface, _textPrimary, _textSecondary, _border]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final brands = await _repository.getAllBrands();
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _loading = false;
      });
      if (_selected == null && brands.isNotEmpty) _select(brands.first);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Unable to load branding: $e', error: true);
    }
  }

  void _select(BrandConfig b) {
    _selected = b;
    _key.text = b.brandKey;
    _name.text = b.appName;
    _primary.text = b.primaryColor;
    _secondary.text = b.secondaryColor;
    _accent.text = b.accentColor;
    _background.text = b.backgroundColor;
    _surface.text = b.surfaceColor;
    _textPrimary.text = b.textPrimaryColor;
    _textSecondary.text = b.textSecondaryColor;
    _border.text = b.borderColor;
    setState(() {});
  }

  Future<void> _save() async {
    final key = _key.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(key)) {
      _message('Brand Key: use letters, numbers, hyphen or underscore.', error: true);
      return;
    }
    if (_name.text.trim().isEmpty) {
      _message('App Name is required.', error: true);
      return;
    }
    final colors = [_primary, _secondary, _accent, _background, _surface, _textPrimary, _textSecondary, _border];
    if (colors.any((c) => !_isHex(c.text.trim()))) {
      _message('All colors must use HEX format, e.g. #0B6B3A.', error: true);
      return;
    }

    final config = BrandConfig(
      brandKey: key,
      appName: _name.text.trim(),
      primaryColor: _primary.text.trim().toUpperCase(),
      secondaryColor: _secondary.text.trim().toUpperCase(),
      accentColor: _accent.text.trim().toUpperCase(),
      backgroundColor: _background.text.trim().toUpperCase(),
      surfaceColor: _surface.text.trim().toUpperCase(),
      textPrimaryColor: _textPrimary.text.trim().toUpperCase(),
      textSecondaryColor: _textSecondary.text.trim().toUpperCase(),
      borderColor: _border.text.trim().toUpperCase(),
    );

    setState(() => _saving = true);
    try {
      await _repository.saveBrand(config);
      if (!mounted) return;
      _selected = config;
      await _load();
      _select(config);
      _message('Branding saved successfully.');
    } catch (e) {
      if (mounted) _message('Unable to save branding: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _isHex(String value) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value);

  Color _hex(String value, Color fallback) {
    final v = value.replaceFirst('#', '');
    if (v.length != 6) return fallback;
    final n = int.tryParse(v, radix: 16);
    return n == null ? fallback : Color(0xFF000000 | n);
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Branding & Theme', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.palette_rounded, color: theme.colorScheme.primary, size: 34),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Centralized white-label branding. Edit one configuration and all screens using the app theme can follow it. Each client can have a separate Brand Key.',
                            style: TextStyle(height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_brands.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selected?.brandKey,
                    decoration: const InputDecoration(labelText: 'Saved Client / Brand'),
                    items: _brands
                        .map((b) => DropdownMenuItem(
                              value: b.brandKey,
                              child: Text('${b.appName} (${b.brandKey})'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) _select(_brands.firstWhere((b) => b.brandKey == v));
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                _section('Brand Identity', [
                  TextField(
                    controller: _key,
                    decoration: const InputDecoration(labelText: 'Brand Key', hintText: 'client1'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'App Name', hintText: 'Client 1 Food'),
                    onChanged: (_) => setState(() {}),
                  ),
                ]),
                const SizedBox(height: 14),
                _section('Theme Colors', [
                  _colorField(_primary, 'Primary Color'),
                  _colorField(_secondary, 'Secondary Color'),
                  _colorField(_accent, 'Accent Color'),
                  _colorField(_background, 'Background Color'),
                  _colorField(_surface, 'Surface Color'),
                  _colorField(_textPrimary, 'Text Primary Color'),
                  _colorField(_textSecondary, 'Text Secondary Color'),
                  _colorField(_border, 'Border Color'),
                ]),
                const SizedBox(height: 14),
                _preview(theme),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Saving...' : 'Save Branding'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _colorField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: !_saving,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => Padding(
              padding: const EdgeInsets.all(11),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _hex(value.text, Colors.grey),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _preview(ThemeData theme) {
    final primary = _hex(_primary.text, theme.colorScheme.primary);
    final secondary = _hex(_secondary.text, theme.colorScheme.primaryContainer);
    final accent = _hex(_accent.text, theme.colorScheme.secondary);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              height: 105,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primary, secondary]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  _name.text.trim().isEmpty ? 'Your App' : _name.text.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Accent / action color',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 10),
            const Text('The Flutter app reads these values through the centralized ThemeData.'),
          ],
        ),
      ),
    );
  }
}
