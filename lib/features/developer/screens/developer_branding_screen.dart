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
    for (final c in [
      _key,
      _name,
      _primary,
      _secondary,
      _accent,
      _background,
      _surface,
      _textPrimary,
      _textSecondary,
      _border,
    ]) {
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
    final colors = [
      _primary,
      _secondary,
      _accent,
      _background,
      _surface,
      _textPrimary,
      _textSecondary,
      _border,
    ];
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

  String _colorHex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  Future<void> _pickColor(TextEditingController controller, String label) async {
    final initial = _hex(controller.text, Theme.of(context).colorScheme.primary);
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorPickerDialog(
        title: 'Pick $label',
        initialColor: initial,
      ),
    );

    if (picked != null) {
      controller.text = _colorHex(picked);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App Branding & Theme',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _saving ? null : _load,
            tooltip: 'Refresh',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.palette_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'White-label Branding',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Manage the app identity and theme colors from one place. Each client can have its own Brand Key.',
                                style: TextStyle(height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_brands.isNotEmpty) ...[
                  _section('Saved Brands', [
                    DropdownButtonFormField<String>(
                      initialValue: _selected?.brandKey,
                      decoration: const InputDecoration(
                        labelText: 'Select Client / Brand',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                      items: _brands
                          .map(
                            (b) => DropdownMenuItem(
                              value: b.brandKey,
                              child: Text('${b.appName} (${b.brandKey})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          _select(_brands.firstWhere((b) => b.brandKey == v));
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 14),
                ],
                _section('Brand Identity', [
                  TextField(
                    controller: _key,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Brand Key',
                      hintText: 'client1',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'App Name',
                      hintText: 'Client 1 Food',
                      prefixIcon: Icon(Icons.apps_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ]),
                const SizedBox(height: 14),
                _section('Theme Colors', [
                  const Text(
                    'Use HEX for exact colors or Pick Color to choose visually.',
                    style: TextStyle(height: 1.35),
                  ),
                  const SizedBox(height: 14),
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _colorField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !_saving,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: label,
                hintText: '#0B6B3A',
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
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickColor(controller, label),
              icon: const Icon(Icons.colorize_rounded, size: 19),
              label: const Text('Pick Color'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(ThemeData theme) {
    final primary = _hex(_primary.text, theme.colorScheme.primary);
    final secondary = _hex(
      _secondary.text,
      theme.colorScheme.primaryContainer,
    );
    final accent = _hex(_accent.text, theme.colorScheme.secondary);
    final background = _hex(_background.text, theme.scaffoldBackgroundColor);
    final surface = _hex(_surface.text, theme.colorScheme.surface);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.visibility_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Live Preview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _hex(_border.text, Colors.black12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 96,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primary, secondary]),
                      borderRadius: BorderRadius.circular(15),
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
                      color: surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Accent / action color preview',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        FilledButton(
                          onPressed: () {},
                          child: const Text('Action'),
                        ),
                      ],
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
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({
    required this.title,
    required this.initialColor,
  });

  final String title;
  final Color initialColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
  }

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final hex = _hexValue(_color);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                hex,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Hue'),
            Slider(
              min: 0,
              max: 360,
              value: _hsv.hue,
              onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
            ),
            const Text('Saturation'),
            Slider(
              value: _hsv.saturation,
              onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
            ),
            const Text('Brightness'),
            Slider(
              value: _hsv.value,
              onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _color),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Use Color'),
        ),
      ],
    );
  }

  String _hexValue(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
