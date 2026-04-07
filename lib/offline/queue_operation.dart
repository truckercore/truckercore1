import 'dart:convert';
import 'package:hive/hive.dart';

@HiveType(typeId: 41)
enum OpType {
  @HiveField(0)
  createLoad,
  @HiveField(1)
  updateLocation,
  @HiveField(2)
  logRoute,
  // add more as needed
}

@HiveType(typeId: 42)
class QueueOperation extends HiveObject {
  @HiveField(0)
  String id; // local uuid

  @HiveField(1)
  OpType type;

  @HiveField(2)
  Map<String, dynamic> payload;

  @HiveField(3)
  String dedupeKey; // sha256(payload + type + serverTarget)

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  int attempts;

  @HiveField(6)
  String serverTarget; // e.g. "rpc:book_load" or "POST:/api/positions"

  QueueOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.dedupeKey,
    required this.createdAt,
    this.attempts = 0,
    required this.serverTarget,
  });

  String toStableJson() => jsonEncode(stableMap(payload));

  // Make this public so other libs (e.g., utils/hash.dart) can reuse it
  static Map<String, dynamic> stableMap(Map<String, dynamic> m) {
    final keys = m.keys.toList()..sort();
    return {for (final k in keys) k: m[k]};
  }
}

// Manual Hive TypeAdapters (avoid codegen)
class OpTypeAdapter extends TypeAdapter<OpType> {
  @override
  final int typeId = 41;

  @override
  OpType read(BinaryReader reader) {
    final index = reader.readByte();
    switch (index) {
      case 0:
        return OpType.createLoad;
      case 1:
        return OpType.updateLocation;
      case 2:
        return OpType.logRoute;
      default:
        return OpType.createLoad;
    }
  }

  @override
  void write(BinaryWriter writer, OpType obj) {
    switch (obj) {
      case OpType.createLoad:
        writer.writeByte(0);
        break;
      case OpType.updateLocation:
        writer.writeByte(1);
        break;
      case OpType.logRoute:
        writer.writeByte(2);
        break;
    }
  }
}

class QueueOperationAdapter extends TypeAdapter<QueueOperation> {
  @override
  final int typeId = 42;

  @override
  QueueOperation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return QueueOperation(
      id: fields[0] as String,
      type: fields[1] as OpType,
      payload: Map<String, dynamic>.from(fields[2] as Map),
      dedupeKey: fields[3] as String,
      createdAt: fields[4] as DateTime,
      attempts: fields[5] as int,
      serverTarget: fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, QueueOperation obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.payload)
      ..writeByte(3)
      ..write(obj.dedupeKey)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.attempts)
      ..writeByte(6)
      ..write(obj.serverTarget);
  }
}
