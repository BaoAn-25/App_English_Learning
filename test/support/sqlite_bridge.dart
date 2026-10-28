import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

/// Runs production sqflite SQL against real SQLite, without downloading an FFI package.
/// Only the platform transport is replaced; schema, transactions and queries are real.
class SqliteBridge {
  static const _channel = MethodChannel('com.tekartik.sqflite');
  final Process _process;
  final _pending = <int, Completer<Object?>>{};
  int _nextId = 0;

  SqliteBridge._(this._process) {
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final response = jsonDecode(line) as Map<String, dynamic>;
            final pending = _pending.remove(response['id']);
            if (response.containsKey('error')) {
              pending?.completeError(
                PlatformException(
                  code: 'sqlite_error',
                  message: response['error'] as String,
                ),
              );
            } else {
              pending?.complete(response['result']);
            }
          },
          onDone: () {
            for (final pending in _pending.values) {
              pending.completeError(
                StateError('SQLite test process exited before replying'),
              );
            }
            _pending.clear();
          },
        );
  }

  static Future<SqliteBridge> start({
    String? databaseDirectory,
    Future<void> Function(MethodCall)? beforeCall,
  }) async {
    final bridge = SqliteBridge._(
      await Process.start('python3', [
        'test/support/sqlite_bridge.py',
        ?databaseDirectory,
      ]),
    );
    databaseFactory = databaseFactorySqflitePlugin;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (beforeCall != null) await beforeCall(call);
          final id = bridge._nextId++;
          final result = Completer<Object?>();
          bridge._pending[id] = result;
          bridge._process.stdin.writeln(
            jsonEncode({
              'id': id,
              'method': call.method,
              'args': call.arguments,
            }),
          );
          return result.future;
        });
    return bridge;
  }

  Future<void> close() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    await _process.stdin.close();
    await _process.exitCode;
  }
}
