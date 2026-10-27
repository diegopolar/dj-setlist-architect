import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../db.dart';
import '../models.dart';

List<String> _split(String line) { // split CSV con soporte de comillas
  final out = <String>[];
  var cur = StringBuffer();
  var q = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (q && i + 1 < line.length && line[i + 1] == '"') { cur.write('"'); i++; } else { q = !q; }
    } else if (c == ',' && !q) { out.add(cur.toString()); cur = StringBuffer(); } else { cur.write(c); }
  }
  out.add(cur.toString());
  return out;
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibState();
}

class _LibState extends State<LibraryScreen> {
  List<Track> tracks = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { final l = await Db.all(); if (mounted) setState(() => tracks = l); }

  // Importa CSV (cabecera: title,artist,bpm,key,genre,energy,path) o JSON (lista de objetos).
  Future<void> _import() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'json'], withData: true);
    final f = r?.files.single;
    if (f == null || f.bytes == null) return;
    final txt = utf8.decode(f.bytes!, allowMalformed: true);
    List<Map<String, dynamic>> rows = [];
    try {
      if (f.extension?.toLowerCase() == 'json') {
        rows = (jsonDecode(txt) as List).cast<Map<String, dynamic>>();
      } else {
        final lines = txt.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
        final head = _split(lines.first).map((h) => h.trim().toLowerCase()).toList();
        for (final l in lines.skip(1)) {
          final v = _split(l);
          rows.add({for (var i = 0; i < head.length && i < v.length; i++) head[i]: v[i]});
        }
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archivo inválido')));
      return;
    }
    var n = 0;
    for (final m in rows) { final t = Track.fromImport(m); if (t != null) { await Db.insert(t); n++; } }
    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n pistas importadas')));
  }

  Future<void> _edit([Track? t]) async {
    final title = TextEditingController(text: t?.title), artist = TextEditingController(text: t?.artist),
        bpm = TextEditingController(text: t?.bpm.toString()), key = TextEditingController(text: t?.key),
        genre = TextEditingController(text: t?.genre), path = TextEditingController(text: t?.path);
    var energy = t?.energy ?? 3;
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
            title: Text(t == null ? 'Nueva pista' : 'Editar pista'),
            content: SingleChildScrollView(child: Column(children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
              TextField(controller: artist, decoration: const InputDecoration(labelText: 'Artista')),
              TextField(controller: bpm, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'BPM')),
              TextField(controller: key, decoration: const InputDecoration(labelText: 'Key (8A / Am)')),
              TextField(controller: genre, decoration: const InputDecoration(labelText: 'Género')),
              TextField(controller: path, decoration: const InputDecoration(labelText: 'Ruta archivo (opcional, M3U)')),
              Text('Energía: $energy'),
              Slider(min: 1, max: 5, divisions: 4, value: energy.toDouble(), onChanged: (v) => set(() => energy = v.round())),
            ])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Guardar'))])));
    final b = int.tryParse(bpm.text);
    if (ok != true || title.text.trim().isEmpty || b == null) return;
    final nt = Track(id: t?.id, title: title.text.trim(), artist: artist.text.trim(), bpm: b,
        key: normalizeKey(key.text), genre: genre.text.trim(), energy: energy, path: path.text.trim());
    t == null ? await Db.insert(nt) : await Db.update(nt);
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('Biblioteca (${tracks.length})'),
          actions: [IconButton(icon: const Icon(Icons.file_upload), tooltip: 'Importar CSV/JSON', onPressed: _import)]),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(), child: const Icon(Icons.add)),
      body: tracks.isEmpty
          ? const Center(child: Text('Sin pistas. Añade o importa CSV/JSON.'))
          : ListView.builder(itemCount: tracks.length, itemBuilder: (c, i) {
              final t = tracks[i];
              return Dismissible(
                  key: ValueKey(t.id), background: Container(color: Colors.red),
                  onDismissed: (_) { Db.delete(t.id!); tracks.removeAt(i); },
                  child: ListTile(title: Text(t.label), onTap: () => _edit(t),
                      subtitle: Text('${t.bpm} BPM · ${t.key} · E${t.energy} · ${t.genre}')));
            }));
}
