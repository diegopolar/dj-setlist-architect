// Capa de persistencia local (SQLite) - 100% offline.
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class Db {
  static Database? _d;
  static Future<Database> get _db async => _d ??= await openDatabase(
      join(await getDatabasesPath(), 'dj_setlist.db'), version: 1,
      onCreate: (d, _) => d.execute('CREATE TABLE tracks(id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'title TEXT, artist TEXT, bpm INTEGER, tkey TEXT, genre TEXT, energy INTEGER, path TEXT)'));

  static Future<List<Track>> all() async =>
      (await (await _db).query('tracks', orderBy: 'artist, title')).map(Track.fromMap).toList();
  static Future<void> insert(Track t) async => (await _db).insert('tracks', t.toMap()..remove('id'));
  static Future<void> update(Track t) async =>
      (await _db).update('tracks', t.toMap(), where: 'id=?', whereArgs: [t.id]);
  static Future<void> delete(int id) async =>
      (await _db).delete('tracks', where: 'id=?', whereArgs: [id]);
}
