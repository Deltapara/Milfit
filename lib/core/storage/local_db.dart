import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import '../security/key_manager.dart';

class LocalDb {
  static final LocalDb _instance = LocalDb._internal();
  factory LocalDb() => _instance;
  LocalDb._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final keyManager = KeyManager();
    final masterKey = await keyManager.getOrCreateMasterKey();

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'milfit_encrypted.db');

    return await openDatabase(
      path,
      password: masterKey, // La base est chiffrée avec la clé du KeyStore
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE encrypted_traces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            encrypted_payload TEXT
          )
        ''');
      },
    );
  }
}