// Exportación: TXT, CSV y M3U (Mixxx / Rekordbox / VirtualDJ).
import 'generator.dart';

class Exporter {
  static String _q(String s) => '"${s.replaceAll('"', '""')}"';

  static String txt(List<SetBlock> blocks) {
    final s = StringBuffer('DJ Setlist Architect\n');
    var n = 1;
    for (final b in blocks) {
      s.writeln('\n== ${b.name} (${b.startMin}-${b.endMin} min | ${b.bpmFrom}-${b.bpmTo} BPM | E${b.energy} | Key ${b.key}) ==');
      for (final e in b.entries) {
        final t = e.track;
        s.writeln('${(n++).toString().padLeft(2, '0')}. ' +
            (t == null ? '[slot libre ~${e.targetBpm.round()} BPM]' : '${t.label} [${t.bpm} BPM, ${t.key}]'));
      }
    }
    return s.toString();
  }

  static String csv(List<SetBlock> blocks) {
    final s = StringBuffer('n,block,title,artist,bpm,key,genre,energy\n');
    var n = 1;
    for (final b in blocks) {
      for (final e in b.entries) {
        final t = e.track;
        s.writeln([n++, _q(b.name), _q(t?.title ?? ''), _q(t?.artist ?? ''),
          t?.bpm ?? '', t?.key ?? '', _q(t?.genre ?? ''), t?.energy ?? ''].join(','));
      }
    }
    return s.toString();
  }

  /// M3U extendida. Usa la ruta del archivo si existe; si no, "Artista - Título".
  static String m3u(List<SetBlock> blocks) {
    final secs = (AppState.config.avgTrack * 60).round();
    final s = StringBuffer('#EXTM3U\n');
    for (final b in blocks) {
      for (final e in b.entries) {
        final t = e.track;
        if (t == null) continue;
        s.writeln('#EXTINF:$secs,${t.label}');
        s.writeln(t.path.isEmpty ? t.label : t.path);
      }
    }
    return s.toString();
  }
}
