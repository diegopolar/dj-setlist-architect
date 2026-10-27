// Algoritmo del setlist: fases -> BPM / energía / key -> selección de pistas.
import 'dart:math';
import 'models.dart';

enum EnergyCurve { linear, wave, flat }

class SessionConfig {
  int minutes = 120;
  Set<String> genres = {};
  int bpmStart = 105, bpmEnd = 128;
  EnergyCurve curve = EnergyCurve.linear;
  double avgTrack = 3.75; // minutos por track
  int get trackCount => max(1, (minutes / avgTrack).round());
}

class SetEntry {
  Track? track; // null = slot vacío
  double targetBpm;
  bool played = false;
  SetEntry(this.targetBpm, [this.track]);
}

class SetBlock {
  final String name, key;
  final int startMin, endMin, bpmFrom, bpmTo, energy;
  final List<SetEntry> entries = [];
  SetBlock(this.name, this.startMin, this.endMin, this.bpmFrom, this.bpmTo, this.energy, this.key);
}

/// Estado global simple (config + set generado).
class AppState {
  static final config = SessionConfig();
  static List<SetBlock> blocks = [];
}

// Plantilla de fase: fracción del tiempo, energía, nivel BPM (0..1) inicial/final, salto en la rueda Camelot.
class _Spec {
  final String name; final double frac; final int energy; final double l0, l1; final int step;
  const _Spec(this.name, this.frac, this.energy, this.l0, this.l1, this.step);
}

List<_Spec> _specs(EnergyCurve c) {
  switch (c) {
    case EnergyCurve.linear:
      return const [
        _Spec('Warm-up', .25, 2, 0, .25, 0), _Spec('Build-up', .30, 3, .25, .6, 1),
        _Spec('Peak Time', .30, 5, .6, 1, 2), _Spec('Outro / Wind-down', .15, 2, .95, .8, 1)];
    case EnergyCurve.wave:
      return const [
        _Spec('Warm-up', .15, 2, 0, .2, 0), _Spec('Build-up', .20, 3, .2, .55, 1),
        _Spec('Peak 1', .20, 5, .55, .9, 2), _Spec('Respiro', .10, 3, .9, .7, 1),
        _Spec('Peak 2', .25, 5, .75, 1, 3), _Spec('Outro / Wind-down', .10, 2, 1, .85, 2)];
    case EnergyCurve.flat:
      return const [
        _Spec('Warm-up', .10, 3, .6, .9, 0), _Spec('High Energy', .80, 5, .9, 1, 1),
        _Spec('Outro', .10, 3, 1, .9, 1)];
  }
}

List<SetBlock> generateSetlist(SessionConfig c, List<Track> lib) {
  final specs = _specs(c.curve);
  final total = c.trackCount;
  var used = 0, acc = 0.0;
  Track? prev;
  final taken = <int>{};
  final out = <SetBlock>[];
  int bpmAt(double l) => (c.bpmStart + (c.bpmEnd - c.bpmStart) * l).round();

  for (var i = 0; i < specs.length; i++) {
    final s = specs[i], last = i == specs.length - 1;
    final n = last ? max(0, total - used) : min(total - used, (total * s.frac).round());
    used += n;
    final start = (acc * c.minutes).round();
    acc += s.frac;
    final end = last ? c.minutes : (acc * c.minutes).round();
    final key = '${((7 + s.step) % 12) + 1}${s.energy >= 5 ? 'B' : 'A'}'; // key sugerida
    final b = SetBlock(s.name, start, end, bpmAt(s.l0), bpmAt(s.l1), s.energy, key);

    for (var k = 0; k < n; k++) {
      final target = b.bpmFrom + (b.bpmTo - b.bpmFrom) * (n == 1 ? 0.0 : k / (n - 1));
      Track? best;
      var bestScore = double.infinity;
      for (final t in lib) {
        if (taken.contains(t.id)) continue;
        final d = (t.bpm - target).abs();
        if (d > 10) continue; // demasiado lejos: dejar slot vacío
        if (c.genres.isNotEmpty &&
            !c.genres.any((g) => t.genre.toLowerCase().contains(g.toLowerCase()))) continue;
        final sc = d + 3 * (t.energy - s.energy).abs() + 2 * camelotDistance(prev?.key ?? key, t.key);
        if (sc < bestScore) { bestScore = sc; best = t; }
      }
      if (best != null) { taken.add(best.id!); prev = best; }
      b.entries.add(SetEntry(target, best));
    }
    out.add(b);
  }
  return out;
}
