import 'package:flutter/material.dart';
import '../db.dart';
import '../generator.dart';
import 'performance_screen.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});
  @override
  State<ConfigScreen> createState() => _ConfigState();
}

class _ConfigState extends State<ConfigScreen> {
  final cfg = AppState.config;
  final _custom = TextEditingController(), _min = TextEditingController();
  final genres = ['80s Rock', 'New Wave', 'Synthpop', 'Darkwave', 'Post-Punk', 'Indie Rock', 'House', 'Techno'];

  Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)));

  String _dur(int m) => '${m ~/ 60}h${m % 60 == 0 ? '' : ' ${m % 60}m'}';

  @override
  Widget build(BuildContext context) {
    const curves = {
      EnergyCurve.linear: 'Warm-up / Linear Build',
      EnergyCurve.wave: 'Peak Time Wave',
      EnergyCurve.flat: 'High Energy Flat'};
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('DJ Setlist Architect', style: Theme.of(context).textTheme.headlineSmall),
      _h('Duración del set (${_dur(cfg.minutes)})'),
      Wrap(spacing: 8, children: [for (final m in [60, 90, 120, 180, 240])
        ChoiceChip(label: Text(_dur(m)), selected: cfg.minutes == m,
            onSelected: (_) => setState(() { cfg.minutes = m; _min.clear(); }))]),
      TextField(controller: _min, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Personalizada (minutos)'),
          onChanged: (v) { final n = int.tryParse(v); if (n != null && n >= 10) setState(() => cfg.minutes = n); }),
      _h('Géneros (vacío = todos)'),
      Wrap(spacing: 8, children: [for (final g in genres)
        FilterChip(label: Text(g), selected: cfg.genres.contains(g),
            onSelected: (s) => setState(() => s ? cfg.genres.add(g) : cfg.genres.remove(g)))]),
      Row(children: [
        Expanded(child: TextField(controller: _custom, decoration: const InputDecoration(labelText: 'Añadir género'))),
        IconButton(icon: const Icon(Icons.add_circle), onPressed: () {
          final g = _custom.text.trim();
          if (g.isEmpty) return;
          setState(() { if (!genres.contains(g)) genres.add(g); cfg.genres.add(g); _custom.clear(); });
        })]),
      _h('BPM: ${cfg.bpmStart} → ${cfg.bpmEnd}'),
      RangeSlider(min: 60, max: 180, divisions: 120,
          values: RangeValues(cfg.bpmStart.toDouble(), cfg.bpmEnd.toDouble()),
          labels: RangeLabels('${cfg.bpmStart}', '${cfg.bpmEnd}'),
          onChanged: (r) => setState(() { cfg.bpmStart = r.start.round(); cfg.bpmEnd = r.end.round(); })),
      _h('Curva de energía'),
      Wrap(spacing: 8, children: [for (final e in curves.entries)
        ChoiceChip(label: Text(e.value), selected: cfg.curve == e.key, onSelected: (_) => setState(() => cfg.curve = e.key))]),
      _h('Promedio por track: ${cfg.avgTrack.toStringAsFixed(2)} min  →  ~${cfg.trackCount} tracks'),
      Slider(min: 2, max: 8, divisions: 24, value: cfg.avgTrack, onChanged: (v) => setState(() => cfg.avgTrack = v)),
      const SizedBox(height: 20),
      FilledButton.icon(
          icon: const Icon(Icons.auto_awesome), label: const Padding(padding: EdgeInsets.all(14), child: Text('GENERAR SETLIST')),
          onPressed: () async {
            final lib = await Db.all();
            AppState.blocks = generateSetlist(cfg, lib);
            if (!context.mounted) return;
            if (lib.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Biblioteca vacía: se generó la estructura con slots libres.')));
            }
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PerformanceScreen()));
          }),
    ]);
  }
}
