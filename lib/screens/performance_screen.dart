import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../db.dart';
import '../export.dart';
import '../generator.dart';
import '../models.dart';

/// Setlist + modo performance: temporizador, marcar tocados, track de emergencia.
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});
  @override
  State<PerformanceScreen> createState() => _PerfState();
}

class _PerfState extends State<PerformanceScreen> {
  Timer? _t;
  int sec = 0;
  List<Track> lib = [];
  List<SetBlock> get blocks => AppState.blocks;
  int get total => AppState.config.minutes * 60;

  @override
  void initState() { super.initState(); Db.all().then((l) => lib = l); }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  void _toggle() {
    if (_t != null) { _t!.cancel(); _t = null; }
    else { _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => sec++)); }
    setState(() {});
  }

  SetBlock get cur => blocks.lastWhere((b) => sec / 60 >= b.startMin, orElse: () => blocks.first);
  String fmt(int s) { s = s < 0 ? 0 : s; return '${(s ~/ 3600).toString().padLeft(2, '0')}:${((s % 3600) ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}'; }

  Set<int> get _inSet => {for (final b in blocks) for (final e in b.entries) if (e.track != null) e.track!.id!};

  String _lastKey(SetBlock b) {
    for (final bl in blocks.reversed) { for (final e in bl.entries.reversed) { if (e.played && e.track != null) return e.track!.key; } }
    return b.key;
  }

  void _sheet(String title, List<Track> c, void Function(Track) onPick) => showModalBottomSheet(
      context: context, builder: (_) => Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Text(title, style: const TextStyle(fontSize: 18))),
        Expanded(child: c.isEmpty ? const Center(child: Text('No hay pistas disponibles'))
            : ListView(children: [for (final t in c) ListTile(title: Text(t.label),
                subtitle: Text('${t.bpm} BPM · ${t.key} · E${t.energy}'),
                onTap: () { Navigator.pop(context); setState(() => onPick(t)); })]))]));

  // Rellena / cambia un slot manualmente.
  void _pickFor(SetBlock b, SetEntry e) {
    final c = lib.where((t) => !_inSet.contains(t.id)).toList()
      ..sort((x, y) => ((x.bpm - e.targetBpm).abs() + 3 * (x.energy - b.energy).abs())
          .compareTo((y.bpm - e.targetBpm).abs() + 3 * (y.energy - b.energy).abs()));
    _sheet('Elegir pista (~${e.targetBpm.round()} BPM)', c.take(30).toList(), (t) => e.track = t);
  }

  // BANGER: alta energía, BPM del bloque y key compatible con la última tocada.
  void _banger() {
    final b = cur, mid = (b.bpmFrom + b.bpmTo) / 2, lk = _lastKey(b);
    double sc(Track t) => (t.bpm - mid).abs() - 4 * t.energy + 2 * camelotDistance(lk, t.key);
    final c = lib.where((t) => !_inSet.contains(t.id)).toList()..sort((x, y) => sc(x).compareTo(sc(y)));
    _sheet('🔥 BANGER (~${mid.round()} BPM)', c.take(15).toList(), (t) {
      var idx = b.entries.indexWhere((e) => !e.played);
      if (idx < 0) idx = b.entries.length;
      b.entries.insert(idx, SetEntry(t.bpm.toDouble(), t)); // se toca a continuación
    });
  }

  Future<void> _export(String f) async {
    final txt = f == 'csv' ? Exporter.csv(blocks) : f == 'm3u' ? Exporter.m3u(blocks) : Exporter.txt(blocks);
    final file = File('${(await getTemporaryDirectory()).path}/setlist.$f');
    await file.writeAsString(txt);
    await Share.shareXFiles([XFile(file.path)], subject: 'Setlist');
  }

  @override
  Widget build(BuildContext context) {
    final b = cur, left = total - sec;
    final items = <Widget>[];
    for (final bl in blocks) {
      items.add(Container(width: double.infinity, color: bl == b ? const Color(0xFF3A0A24) : const Color(0xFF1A1A1A),
          padding: const EdgeInsets.all(10),
          child: Text('${bl.name.toUpperCase()}  ·  ${bl.startMin}-${bl.endMin} min  ·  ${bl.bpmFrom}-${bl.bpmTo} BPM  ·  E${bl.energy}  ·  Key ${bl.key}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E5FF)))));
      for (final e in bl.entries) {
        final t = e.track;
        items.add(Dismissible( // swipe = marcar / desmarcar como tocado
            key: ObjectKey(e), background: Container(color: Colors.green.shade800),
            confirmDismiss: (_) async { setState(() => e.played = !e.played); return false; },
            child: ListTile(
                leading: Checkbox(value: e.played, onChanged: (v) => setState(() => e.played = v!)),
                title: Text(t?.label ?? '— slot libre —', style: TextStyle(fontSize: 18,
                    decoration: e.played ? TextDecoration.lineThrough : null,
                    color: e.played ? Colors.white38 : (t == null ? Colors.white54 : Colors.white))),
                subtitle: Text(t == null ? 'objetivo ~${e.targetBpm.round()} BPM (toca para elegir)'
                    : '${t.bpm} BPM · ${t.key} · E${t.energy}'),
                onTap: () => _pickFor(bl, e))));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Setlist'), actions: [
        PopupMenuButton<String>(icon: const Icon(Icons.ios_share), onSelected: _export,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'txt', child: Text('Texto plano')),
              PopupMenuItem(value: 'csv', child: Text('CSV')),
              PopupMenuItem(value: 'm3u', child: Text('M3U (Mixxx/Rekordbox/VDJ)'))])]),
      floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.redAccent, onPressed: _banger,
          icon: const Icon(Icons.local_fire_department), label: const Text('BANGER')),
      body: Column(children: [
        Container(color: const Color(0xFF111111), padding: const EdgeInsets.all(12), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            Column(children: [const Text('TRANSCURRIDO'), Text(fmt(sec), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold))]),
            Column(children: [const Text('RESTANTE'), Text(fmt(left), style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: left < 300 ? Colors.redAccent : Colors.white))]),
          ]),
          LinearProgressIndicator(value: (sec / total).clamp(0, 1).toDouble()),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${b.name} · ${b.bpmFrom}→${b.bpmTo} BPM', style: const TextStyle(fontSize: 20, color: Color(0xFFFF2D95))),
            Row(children: [
              IconButton(iconSize: 36, icon: Icon(_t == null ? Icons.play_circle : Icons.pause_circle), onPressed: _toggle),
              IconButton(icon: const Icon(Icons.replay), onPressed: () => setState(() { _t?.cancel(); _t = null; sec = 0; }))])])])),
        Expanded(child: ListView(children: items)),
      ]),
    );
  }
}
