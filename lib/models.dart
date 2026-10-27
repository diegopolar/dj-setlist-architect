// Modelo de pista + utilidades de la rueda Camelot.
class Track {
  int? id;
  String title, artist, key, genre, path;
  int bpm, energy; // energy: 1..5
  Track({this.id, required this.title, this.artist = '', required this.bpm,
      this.key = '', this.genre = '', this.energy = 3, this.path = ''});

  Map<String, Object?> toMap() => {'id': id, 'title': title, 'artist': artist,
      'bpm': bpm, 'tkey': key, 'genre': genre, 'energy': energy, 'path': path};

  factory Track.fromMap(Map<String, Object?> m) => Track(
      id: m['id'] as int?, title: m['title'] as String,
      artist: (m['artist'] ?? '') as String, bpm: m['bpm'] as int,
      key: (m['tkey'] ?? '') as String, genre: (m['genre'] ?? '') as String,
      energy: (m['energy'] ?? 3) as int, path: (m['path'] ?? '') as String);

  /// Crea una pista desde una fila CSV/JSON (claves en minúscula). Null si es inválida.
  static Track? fromImport(Map<String, dynamic> raw) {
    final m = {for (final e in raw.entries) e.key.toString().toLowerCase().trim(): e.value};
    final title = '${m['title'] ?? ''}'.trim();
    final bpm = double.tryParse('${m['bpm']}')?.round();
    if (title.isEmpty || bpm == null) return null;
    return Track(
        title: title, artist: '${m['artist'] ?? ''}'.trim(), bpm: bpm,
        key: normalizeKey('${m['key'] ?? ''}'), genre: '${m['genre'] ?? ''}'.trim(),
        energy: (int.tryParse('${m['energy']}') ?? 3).clamp(1, 5),
        path: '${m['path'] ?? ''}'.trim());
  }

  String get label => artist.isEmpty ? title : '$artist - $title';
}

// Tonalidades clásicas -> Camelot.
const _classic = {
  'Abm': '1A', 'G#m': '1A', 'B': '1B', 'Ebm': '2A', 'D#m': '2A', 'F#': '2B', 'Gb': '2B',
  'Bbm': '3A', 'A#m': '3A', 'Db': '3B', 'C#': '3B', 'Fm': '4A', 'Ab': '4B', 'G#': '4B',
  'Cm': '5A', 'Eb': '5B', 'D#': '5B', 'Gm': '6A', 'Bb': '6B', 'A#': '6B', 'Dm': '7A',
  'F': '7B', 'Am': '8A', 'C': '8B', 'Em': '9A', 'G': '9B', 'Bm': '10A', 'D': '10B',
  'F#m': '11A', 'Gbm': '11A', 'A': '11B', 'C#m': '12A', 'Dbm': '12A', 'E': '12B',
};

/// Acepta "8A" o notación clásica ("Am", "F#m") y devuelve Camelot.
String normalizeKey(String k) {
  k = k.trim();
  if (RegExp(r'^(1[0-2]|[1-9])[ABab]$').hasMatch(k)) return k.toUpperCase();
  return _classic[k] ?? k;
}

(int, String)? _parse(String k) {
  final m = RegExp(r'^(1[0-2]|[1-9])([AB])$').firstMatch(k);
  return m == null ? null : (int.parse(m[1]!), m[2]!);
}

/// 0 = misma tonalidad, 1 = compatible (±1 o relativa), 2 = desconocida, 3 = choque.
int camelotDistance(String a, String b) {
  final x = _parse(a), y = _parse(b);
  if (x == null || y == null) return 2;
  if (x.$1 == y.$1 && x.$2 == y.$2) return 0;
  if (x.$2 == y.$2) {
    final d = (x.$1 - y.$1).abs();
    if (d == 1 || d == 11) return 1;
  } else if (x.$1 == y.$1) {
    return 1;
  }
  return 3;
}
