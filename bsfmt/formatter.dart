import 'dart:collection' show Queue;
import 'dart:io';

import 'file_formatter.dart';
import 'formatter_scanner.dart';
import '../../betascript/source/interpreter/token.dart';

class Formatter {
  String _indent;
  int _maxLineLength;
  Queue<FileSystemEntity> _dirAndFileStack = Queue<FileSystemEntity>();

  bool _matchOption(String arg, String option) =>
      arg.substring(0, option.length) == option;

  String _extractOptionValue(String arg, String option) =>
      arg.substring(option.length);

  void _extractIndentValue(String value) {
    final symbol = (value.substring(value.length - 1) == "t") ? "\t" : " ";
    int number;
    try {
      number = int.parse(value.substring(0, value.length - 1));
    } on FormatException catch (e) {
      throw FormatterException(e.toString());
    }
    if (number < 1)
      throw FormatterException("Indent number must be 1 or higher!");
    _indent = symbol * number;
  }

  void _extractLineLengthValue(String value) {
    try {
      _maxLineLength = int.parse(value);
    } on FormatException catch (e) {
      throw FormatterException(e.toString());
    }
    if (_maxLineLength < 60)
      print(
          "line length below recommended value! Values between 60 and 120 are more recommended.");
  }

  Formatter(List<String> args) {
    for (var arg in args) {
      if (_matchOption(arg, "-i=")) {
        _extractIndentValue(_extractOptionValue(arg, "-i=").toLowerCase());
        continue;
      } else if (_matchOption(arg, "--indent=")) {
        _extractIndentValue(
            _extractOptionValue(arg, "--indent=").toLowerCase());
        continue;
      } else if (_matchOption(arg, "-l=")) {
        _extractLineLengthValue(_extractOptionValue(arg, "-l="));
      } else if (_matchOption(arg, "--length=")) {
        _extractLineLengthValue(_extractOptionValue(arg, "--length="));
      } else {
        final type = FileSystemEntity.typeSync(arg);
        if (type == FileSystemEntityType.directory) {
          _dirAndFileStack.add(Directory(arg));
          continue;
        } else if (type == FileSystemEntityType.file) {
          if (arg.substring(arg.length - 3) == ".bs") {
            _dirAndFileStack.add(File(arg));
            continue;
          }
        }
        throw FormatterException(
            "${arg} is not an option, directory or file! run bsfmt -h for help.");
      }
    }
    _indent ??= "  ";
    _maxLineLength ??= 80;
  }

  void format() {
    while (_dirAndFileStack.isNotEmpty) {
      final entity = _dirAndFileStack.removeFirst();
      if (entity is File)
        _formatFile(entity);
      else if (entity is Directory) _openDir(entity);
    }
  }

  void _openDir(Directory dir) {
    for (FileSystemEntity entity in dir.listSync(followLinks: false)) {
      if (entity is File || entity is Directory) _dirAndFileStack.add(entity);
    }
  }

  void _formatFile(File file) {
    bool hadError = false;

    void errorCallback(Object value, String message) {
      hadError = true;
      error(value, message);
    }

    final scanner = FormatterScanner(file.readAsStringSync(), errorCallback);
    final tokens = scanner.scanTokens(); 
    if (hadError) return;
    for (Token token in tokens) print(token);
    final formattedResult =
        FileFormatter(tokens, _indent, _maxLineLength).format();
    // print(formattedResult);
    if (formattedResult != null) file.writeAsStringSync(formattedResult);
  }

  void error(Object value, String message) {
    if (value is int) {
      _errorAtLine(value, message);
    } else if (value is Token) {
      _errorAtToken(value, message);
    } else {
      _report(-1, "at unknown location: '$value'", message);
    }
  }

  void _errorAtLine(int line, String message) {
    _report(line, "", message);
  }

  void _errorAtToken(Token token, String message) {
    if (token.type == TokenType.EOF) {
      _report(token.line, " at end", message);
    } else {
      if (token.lexeme == '\n') {
        _report(token.line, " at linebreak ('\\n')", message);
      } else {
        _report(token.line, " at '${token.lexeme}'", message);
      }
    }
  }

  void _report(int line, String where, String message) {
    print("[Line $line] Error $where: $message");
  }
}

class FormatterException implements Exception {
  final String message;
  const FormatterException(this.message);
  @override
  String toString() => message;
}
