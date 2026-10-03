import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'dart:convert';

import '../models/flow.dart';

class FlowStore {
  static Database? _database;

  // In-memory embedding index: list of (flowId, embeddingVector)
  final List<FlowEmbedding> _embeddings = [];

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'saar.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE flows (
            flow_id TEXT PRIMARY KEY,
            app_package TEXT NOT NULL,
            trigger_intent TEXT NOT NULL,
            example_utterances TEXT NOT NULL,
            slots TEXT NOT NULL,
            steps TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE session_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            flow_id TEXT,
            session_type TEXT NOT NULL,
            status TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            details TEXT,
            FOREIGN KEY (flow_id) REFERENCES flows(flow_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE flow_embeddings (
            flow_id TEXT PRIMARY KEY,
            vector TEXT NOT NULL,
            FOREIGN KEY (flow_id) REFERENCES flows(flow_id)
          )
        ''');
      },
    );
  }

  // CRUD operations for flows
  Future<void> saveFlow(Flow flow) async {
    final db = await database;
    final map = flow.toMap();
    final now = DateTime.now().millisecondsSinceEpoch;
    map['created_at'] = now;
    map['updated_at'] = now;
    await db.insert('flows', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Flow?> getFlow(String flowId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'flows',
      where: 'flow_id = ?',
      whereArgs: [flowId],
    );
    if (maps.isNotEmpty) {
      return Flow.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Flow>> getAllFlows() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('flows');
    return List.generate(maps.length, (i) {
      return Flow.fromMap(maps[i]);
    });
  }

  Future<void> updateFlow(Flow flow) async {
    final db = await database;
    final map = flow.toMap();
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'flows',
      map,
      where: 'flow_id = ?',
      whereArgs: [flow.flowId],
    );
  }

  Future<void> deleteFlow(String flowId) async {
    final db = await database;
    await db.delete('flows', where: 'flow_id = ?', whereArgs: [flowId]);
    await db.delete(
      'flow_embeddings',
      where: 'flow_id = ?',
      whereArgs: [flowId],
    );
    _embeddings.removeWhere((e) => e.flowId == flowId);
  }

  // Embedding operations
  Future<void> saveEmbedding(String flowId, List<double> vector) async {
    final db = await database;
    await db.insert('flow_embeddings', {
      'flow_id': flowId,
      'vector': jsonEncode(vector),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _embeddings.removeWhere((e) => e.flowId == flowId);
    _embeddings.add(FlowEmbedding(flowId: flowId, vector: vector));
  }

  Future<void> loadEmbeddingsIntoMemory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('flow_embeddings');
    _embeddings.clear();
    for (var map in maps) {
      final String flowId = map['flow_id'] as String;
      final String vectorStr = map['vector'] as String;
      final List<dynamic> vectorList = jsonDecode(vectorStr) as List<dynamic>;
      final List<double> vector = vectorList
          .map((e) => (e as num).toDouble())
          .toList();
      _embeddings.add(FlowEmbedding(flowId: flowId, vector: vector));
    }
  }

  List<FlowEmbedding> get embeddings => _embeddings;

  // Session log operations
  Future<void> logSession({
    required String? flowId,
    required String sessionType,
    required String status,
    String? details,
  }) async {
    final db = await database;
    await db.insert('session_logs', {
      'flow_id': flowId,
      'session_type': sessionType,
      'status': status,
      'started_at': DateTime.now().millisecondsSinceEpoch,
      'ended_at': DateTime.now().millisecondsSinceEpoch,
      'details': details,
    });
  }

  Future<List<Map<String, dynamic>>> getSessionLogs({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'session_logs',
      orderBy: 'started_at DESC',
      limit: limit,
    );
  }
}

class FlowEmbedding {
  final String flowId;
  final List<double> vector;
  FlowEmbedding({required this.flowId, required this.vector});
}
