import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/brand_config_repository.dart';
import '../providers/brand_theme_provider.dart';

class DeveloperBrandingScreen extends StatefulWidget {
  const DeveloperBrandingScreen({super.key});

  @override
  State<DeveloperBrandingScreen> createState() => _DeveloperBrandingScreenState();
}

class _DeveloperBrandingScreenState extends State<DeveloperBrandingScreen> {
  final _name = TextEditingController();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _accent = TextEditingController();
  final _background = TextEditingController();
  final _surface = TextEditingController();
  final _textPrimary = TextEditingController();
  final _textSecondary = TextEditingController();
  final _border = TextEditingController();

  bool _saving = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final config = context.read<BrandThemeProvider>().config;
    if (config != null) _fill(config);
    _loaded = true;
  }

  void _fill(BrandConfig config) {
    _name.text = config.appName;
    _primary.text = config.primaryColor;
    _secondary.text = config.secondaryColor;
    _accent.text = config.accentColor;
    _background.text = config.backgroundColor;
    _surface.text = config.surfaceColor;
    _textPrimary.text = config.textPrimaryColor;
    _textSecondary.text = config.textSecondaryColor;
    _border.text = config.borderColor;
  }

  @override
  void dispose() {
    for (final c in [
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

  Future<void> _pickColor(TextEditingController controller, String label) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (_) => _ColorPickerDialog(
        title: 'Pick $label',
        initialColor: _hex(controller.text, Theme.of(context).colorScheme.primary),
      ),
    );
    if (picked != null) {
      controller.text = _colorHex(picked);
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _message('App Name is required.', error: true);
      return;
    }

    final fields = [
      _primary,
      _secondary,
      _accent,
      _background,
      _surface,
      _textPrimary,
      _textSecondary,
      _border,
    ];
    if (fields.any((c) => !_isHex(c.text.trim()))) {
      _message('All colors must use HEX format, e.g. #0B6B3A.', error: true);
      return;
    }

    final config = BrandConfig(
      brandKey: BrandConfigRepository.globalBrandKey,
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
      await context.read<BrandThemeProvider>().save(config);
      if (mounted) _message('Global app branding saved and applied.');
    } catch (e) {
      if (mounted) _message('Unable to save branding: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BrandThemeProvider>();
    if (provider.loading && provider.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Branding & Theme', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _saving ? null : provider.load,
            tooltip: 'Reload global theme',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
        children: [
          _section(
            'General App Branding',
            Icons.palette_rounded,
            [
              const Text(
                'One global configuration for this app deployment. Changes are applied to the actual Material theme, not only this preview.',
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'App Name',
                  prefixIcon: Icon(Icons.apps_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _section(
            'Theme Colors',
            Icons.color_lens_rounded,
            [
              const Text(
                'Use HEX for exact values or Pick Color for visual selection. Both edit the same global color.',
                style: TextStyle(height: 1.4),
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
            ],
          ),
          const SizedBox(height: 14),
          _preview(theme),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving...' : 'Save Global Branding'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
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
    final secondary = _hex(_secondary.text, theme.colorScheme.primaryContainer);
    final accent = _hex(_accent.text, theme.colorScheme.secondary);
    final background = _hex(_background.text, theme.scaffoldBackgroundColor);
    final surface = _hex(_surface.text, theme.colorScheme.surface);
    final border = _hex(_border.text, theme.colorScheme.outline);

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
                Text('Live Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  Container(
                    height: 88,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [primary, secondary]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      _name.text.trim().isEmpty ? 'Your App' : _name.text.trim(),
                      style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('Global action color', style: TextStyle(fontWeight: FontWeight.w700))),
                        FilledButton(onPressed: () {}, child: const Text('Action')),
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
  const _ColorPickerDialog({required this.title, required this.initialColor});

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

  String get _hex => '#${(_color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 70,
              width: double.infinity,
              decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(14)),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_hex, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(height: 10),
            _slider('Hue', _hsv.hue, 360, (v) => setState(() => _hsv = _hsv.withHue(v))),
            _slider('Saturation', _hsv.saturation, 1, (v) => setState(() => _hsv = _hsv.withSaturation(v))),
            _slider('Brightness', _hsv.value, 1, (v) => setState(() => _hsv = _hsv.withValue(v))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _color), child: const Text('Use Color')),
      ],
    );
  }

  Widget _slider(String label, double value, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Slider(value: value, min: 0, max: max, onChanged: onChanged),
      ],
    );
  }
}
