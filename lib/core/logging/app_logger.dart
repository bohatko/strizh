import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static LogLevel minimumLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  static void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) return;

    final prefix = switch (level) {
      LogLevel.debug => '[DEBUG]',
      LogLevel.info => '[INFO]',
      LogLevel.warning => '[WARN]',
      LogLevel.error => '[ERROR]',
    };

    final fullMessage = StringBuffer('$prefix $message');
    if (error != null) {
      fullMessage.write(' | error: $error');
    }

    if (kDebugMode) {
      // In debug we keep using print-based logging for convenience.
      debugPrint(fullMessage.toString());
      if (stackTrace != null) {
        debugPrint(stackTrace.toString());
      }
    } else {
      developer.log(
        fullMessage.toString(),
        error: error,
        stackTrace: stackTrace,
        name: 'App',
      );
    }
  }
}

