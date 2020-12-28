import 'file_formatter.dart';
import '../betascript/source/interpreter/parser.dart';
import '../betascript/source/interpreter/token.dart';
import '../betascript/source/interpreter/stmt.dart';
import '../betascript/source/interpreter/expr.dart';

class FormatterParser extends BSParser {
  FormatterParser(List<Token> tokens, Function errorCallback)
      : super(tokens, errorCallback);

  @override
  List<Stmt> parse() {
    final statements = <Stmt>[];

    //ignores linebreaks here so it doesn't have to go all the way down the recursion to do it
    while (!isAtEnd()) {
      if (match(TokenType.lineBreak)) continue;
      while (matchAny([
        TokenType.comment,
        TokenType.multilineComment,
        TokenType.wordComment
      ])) {
        print(previous().lexeme);
        continue;
      }
      final decl = declaration();
      if (decl != null) statements.add(decl);
    }

    return statements;
  }

  @override
  Stmt forStatement() {
    final token = previous();

    consume(TokenType.leftParentheses, "Expect '(' after 'for'.");

    //linebreaks after left parentheses handled by the parser

    Stmt initializer;

    //the initializer may be empty, a variable declaration or any other expression
    if (!match(TokenType.semicolon)) {
      if (match(TokenType.let)) {
        initializer = varDeclaration();
      } else {
        initializer = expressionStatement();
      }
    }

    //linebreaks after semicolons handled by the parser

    //The condition may be any expression, but may also be left empty
    var condition = (check(TokenType.semicolon)) ? null : expression();

    consume(TokenType.semicolon, "Expect ';' after loop condition.");

    //linebreaks after semicolons handled by the parser

    var increment = (check(TokenType.rightParentheses)) ? null : expression();

    //linebreaks before ) handled by scanner

    consume(TokenType.rightParentheses,
        "Expect ')' after increment in for statement");
    var body = statement();

    return ForStmt(initializer, condition, increment, body, token);
  }

  @override
  Expr primary() {
    while (matchAny([
      TokenType.comment,
      TokenType.multilineComment,
      TokenType.wordComment
    ])) {
      print(previous().lexeme);
    }
    return super.primary();
  }
}

class CommentExpr extends Expr {
  final Token token;
  final String content;

  CommentExpr(this.token, this.content);

  @override
  Object accept(ExprVisitor v) => (v is FileFormatter)
      ? v.visitCommentExpr(this)
      : throw UnimplementedError();
}

class ForStmt extends Stmt {
  final Token token;
  final Stmt initializer;
  final Expr condition;
  final Expr increment;
  final Stmt body;

  ForStmt(
      this.initializer, this.condition, this.increment, this.body, this.token);

  @override
  Object accept(StmtVisitor v) =>
      (v is FileFormatter) ? v.visitForStmt(this) : throw UnimplementedError();
}
