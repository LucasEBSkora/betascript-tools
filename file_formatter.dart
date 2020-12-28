import 'formatter_parser.dart' show ForStmt;
import '../betascript/source/interpreter/expr.dart';
import '../betascript/source/interpreter/stmt.dart';
import '../betascript/source/interpreter/token.dart';
import 'formatter_parser.dart';

class FileFormatter implements StmtVisitor, ExprVisitor {
  final List<Stmt> _statements;
  final String _indent;
  int _indentLevel = 0;
  final int _maxLineLength;
  List<String> result = <String>[];

  //be careful never to set this to something which is a valid character
  ///represents place where ' ' or a linebreak must be inserted
  static const String _whitespace = "\$";

  ///represents place where a linebreak must be inserted
  static const String _optionalLinebreak = "%";

  //obligatory linebreak (needs to remember to register that it went to next line)
  static const String _linebreak = "\n";

  ///represents place where a linebreak or semicolon must be inserted
  ///(the valid terminators in ΒScript)
  static const String _terminator = "\n;";
  FileFormatter(this._statements, this._indent, this._maxLineLength);

  List<String> _visitStmt(Stmt s) => s.accept(this);

  List<String> _visitExpr(Expr e) => e.accept(this);

  String format() {
    for (var stmt in _statements) result.addAll(_visitStmt(stmt));
    var retStr = "";
    var currentLine = "";
    final len = result.length;
    for (var i = 0; i < len; ++i) {
      final frag = result[i];
      final next = (i + 1 < len) ? result[i + 1] : "";
      if (frag == _whitespace) {
        if (currentLine.length + 1 + next.length >= _maxLineLength) {
          retStr += "$currentLine\n";
          currentLine = "";
        } else
          currentLine += " ";
      } else if (frag == _optionalLinebreak) {
        if (currentLine.length + next.length >= _maxLineLength) {
          retStr += "$currentLine\n";
          currentLine = "";
        } else if (frag == _linebreak) {
          retStr += "$currentLine\n";
          currentLine = "";
        }
      } else if (frag == _terminator) {
        retStr += "$currentLine\n";
        currentLine = "";
      } else
        currentLine += frag;
    }
    return retStr + currentLine;
  }

  @override
  Object visitAssignExpr(AssignExpr e) =>
      <String>[e.name.lexeme, " =", _whitespace, ..._visitExpr(e.value)];

  @override
  Object visitBinaryExpr(BinaryExpr e) => <String>[
        ..._visitExpr(e.left),
        " ${_operator(e.op)}",
        _whitespace,
        ..._visitExpr(e.right)
      ];

  String _operator(Token t) {
    switch (t.type) {
      case TokenType.identicallyEquals:
        return '≡';
      case TokenType.not:
        return '¬';
      case TokenType.contained:
        return '⊂';
      case TokenType.belongs:
        return '∈';
      case TokenType.union:
        return '∪';
      case TokenType.intersection:
        return '∩';
      case TokenType.and:
        return '∧';
      case TokenType.or:
        return '∨';
      default:
        return t.lexeme;
    }
  }

  @override
  Object visitBlockStmt(BlockStmt s) {
    if (s.statements?.length == 0 ?? false) return <String>['{}'];
    if (s.statements.length == 1) {
      return <String>['{ ', ..._visitStmt(s.statements.single), ' }'];
    }
    final retVal = <String>[
      _indent * _indentLevel++,
      '{',
      _linebreak,
      for (var stmt in s.statements) ..._visitStmt(stmt),
      _indent * --_indentLevel,
      '}'
    ];

    return retVal;
  }

  @override
  Object visitBuilderDefinitionExpr(BuilderDefinitionExpr e) => <String>[
        "{",
        _whitespace,
        if (e.parameters.isNotEmpty) e.parameters.first.lexeme,
        for (var parameter in e.parameters.sublist(1)) ...<String>[
          ',',
          _whitespace,
          parameter.lexeme
        ],
        '|',
        _whitespace,
      ];

  @override
  Object visitCallExpr(CallExpr e) => <String>[
        ..._visitExpr(e.callee),
        '(',
        _whitespace,
        for (var arg in e.arguments) ..._visitExpr(arg),
        ')'
      ];

  @override
  Object visitClassStmt(ClassStmt s) => <String>[
        _indent * _indentLevel++,
        "class ",
        s.name.lexeme,
        if (s.superclass != null) ...[" < ", ..._visitExpr(s.superclass)],
        " {",
        _whitespace,
        //Removes "routine" keyword
        for (RoutineStmt routine in s.methods)
          ...(_visitStmt(routine)..removeAt(1)),
        _indent * --_indentLevel,
        "}",
        _linebreak
      ];

  @override
  Object visitDerivativeExpr(DerivativeExpr e) => <String>[
        '∂(',
        ..._visitExpr(e.derivand),
        ') /',
        _whitespace,
        '∂(',
        ..._visitExpr(e.variables.first),
        for (var arg in e.variables.sublist(1)) ...<String>[
          ',',
          _whitespace,
          ..._visitExpr(arg)
        ],
        ')'
      ];

  @override
  Object visitDirectiveStmt(DirectiveStmt s) => <String>["#", s.directive];

  @override
  Object visitExpressionStmt(ExpressionStmt s) {
    final list = <String>[_indent * _indentLevel, ..._visitExpr(s.expression)];

    final retList = <String>[];

    var current = "";

    final _len = list.length;
    for (var i = 0; i < _len; ++i) {
      final fragment = list[i];
      if (fragment == _whitespace || fragment == _optionalLinebreak) {
        if (current.isNotEmpty) retList.add(current);
        retList.add(fragment);
        current = "";
      } else
        current += fragment;
    }
    if (current.isNotEmpty) retList.add(current);
    return retList..add(_terminator);
  }

  @override
  Object visitGetExpr(GetExpr e) =>
      <String>[..._visitExpr(e.object), '.', _optionalLinebreak, e.name.lexeme];

  @override
  Object visitGroupingExpr(GroupingExpr e) =>
      <String>['(', _whitespace, ..._visitExpr(e.expression), ' )'];

  @override
  Object visitIfStmt(IfStmt s) => <String>[
        _indent * _indentLevel,
        "if (",
        _optionalLinebreak,
        ..._visitExpr(s.condition),
        ")",
        _whitespace,
        ..._visitStmt(s.thenBranch),
        _whitespace,
        if (s.elseBranch != null) ...[
          "else",
          _whitespace,
          ..._visitStmt(s.elseBranch),
          _linebreak
        ],
      ];

  @override
  Object visitIntervalDefinitionExpr(IntervalDefinitionExpr e) => <String>[
        e.left.lexeme,
        _whitespace,
        ..._visitExpr(e.a),
        ',',
        _whitespace,
        ..._visitExpr(e.b),
        ' ${e.right.lexeme}'
      ];

  @override
  Object visitLiteralExpr(LiteralExpr e) => <String>[e.value.toString()];

  @override
  Object visitLogicBinaryExpr(LogicBinaryExpr e) => <String>[
        ..._visitExpr(e.left),
        " ${_operator(e.op)}",
        _whitespace,
        ..._visitExpr(e.right)
      ];

  @override
  Object visitPrintStmt(PrintStmt s) => <String>[
        _indent * _indentLevel,
        "print ",
        ..._visitExpr(s.expression),
        _terminator
      ];

  @override
  Object visitReturnStmt(ReturnStmt s) => <String>[
        _indent * _indentLevel,
        "return ",
        if (s.value != null) ...[..._visitExpr(s.value), _terminator],
        if (s.value == null) ...[";", _linebreak]
      ];

  @override
  Object visitRosterDefinitionExpr(RosterDefinitionExpr e) => <String>[
        '{',
        if (e.elements.length <= 1) _optionalLinebreak,
        for (var element in e.elements) ...<String>[
          ..._visitExpr(element),
          ',',
          _whitespace
        ],
        '}'
      ];

  @override
  Object visitRoutineStmt(RoutineStmt s) => <String>[
        _indent * _indentLevel++,
        "routine ",
        s.name.lexeme,
        " (",
        _optionalLinebreak,
        if (s.parameters != null && s.parameters.isNotEmpty) ...[
          s.parameters.first.lexeme,
          for (var parameter in s.parameters.sublist(1)) ...[
            parameter.lexeme,
            ",",
            _whitespace
          ]
        ],
        ") {",
        for (var stmt in s.body) ..._visitStmt(stmt),
        "}"
      ];

  @override
  Object visitSetBinaryExpr(SetBinaryExpr e) => <String>[
        ..._visitExpr(e.left),
        " ${_operator(e.operator)}",
        _whitespace,
        ..._visitExpr(e.right)
      ];

  @override
  Object visitSetExpr(SetExpr e) => <String>[
        ..._visitExpr(e.object),
        '.',
        _optionalLinebreak,
        e.name.lexeme,
        ' =',
        _whitespace,
        ..._visitExpr(e.value),
      ];

  @override
  Object visitSuperExpr(SuperExpr e) =>
      <String>["super.", _optionalLinebreak, e.method.lexeme];

  @override
  Object visitThisExpr(ThisExpr e) => <String>["this"];

  @override
  Object visitUnaryExpr(UnaryExpr e) => _isLeftUnary(e.op.type)
      ? <String>[_operator(e.op), ..._visitExpr(e.operand)]
      : <String>[..._visitExpr(e.operand), _operator(e.op)];

  bool _isLeftUnary(TokenType t) {
    switch (t) {
      case TokenType.approx:
        return true;
      case TokenType.not:
        return true;
      case TokenType.minus:
        return true;
      default:
        return false;
    }
  }

  @override
  Object visitVarStmt(VarStmt s) => <String>[
        _indent * _indentLevel,
        "let",
        _whitespace,
        s.name.lexeme,
        if (s.parameters?.isNotEmpty ?? false) ...<String>[
          '(',
          _optionalLinebreak,
          s.parameters.first.lexeme,
          for (var parameter in s.parameters.sublist(1)) ...[
            parameter.lexeme,
            ",",
            _whitespace
          ],
          ')'
        ],
        " =",
        _whitespace,
        if (s.initializer != null) ..._visitExpr(s.initializer),
        _terminator
      ];

  @override
  Object visitVariableExpr(VariableExpr e) => <String>[e.name.lexeme];

  @override
  Object visitWhileStmt(WhileStmt s) => <String>[
        _indent * _indentLevel,
        "while (",
        _optionalLinebreak,
        ..._visitExpr(s.condition),
        ")",
        ..._visitStmt(s.body),
      ];

  Object visitForStmt(ForStmt s) {
    List<String> initializer;
    if (s.initializer != null) {
      initializer = _visitStmt(s.initializer);
      if (initializer.last == _terminator) initializer.removeLast();
    }
    return <String>[
      _indent * _indentLevel,
      "for(",
      if (initializer != null) ...initializer,
      ";",
      _whitespace,
      if (s.condition != null) ..._visitExpr(s.condition),
      ";",
      _whitespace,
      if (s.increment != null) ..._visitExpr(s.increment),
      ")",
      ..._visitStmt(s.body)
    ];
  }

  visitCommentExpr(CommentExpr commentExpr) {}
}
