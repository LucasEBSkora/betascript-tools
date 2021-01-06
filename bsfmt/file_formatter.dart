import 'dart:collection' show Queue;

import '../../betascript/source/interpreter/token.dart';

//represents what we are currently "parsing"
//(but only for things that will change the behavior)
enum Parsing { setExpr, blockStmt, forclause, nothing }

class FileFormatter {
  final List<Token> _tokens;
  final String _indent;
  int _indentLevel = 0;
  int _index = 0;
  final int _maxLineLength;
  List<String> result = <String>[];
  String _retStr = "";
  String _currentLine = "";
  Queue<Parsing> _stack = Queue();
  //represents last thing we finished parsing. Used to check if a '-' after a '}' is binary or unary
  Parsing _lastParsed = Parsing.nothing;
  int _unclosedParenthesesInForClause;

  FileFormatter(this._tokens, this._indent, this._maxLineLength) {
    _stack.add(Parsing.nothing);
  }

  String format() {
    for (; _index < _tokens.length; ++_index) {
      Token token = _tokens[_index];
      if (token.type == TokenType.lineBreak) {
        _processLinebreak();
        continue;
      }
      if (token.type == TokenType.EOF) break;
      _currentLine += _formattedToken(token);
      _whitespaceFollowing(token);

      if (_tokens[_index].type == TokenType.leftBrace &&
          _index + 1 < _tokens.length &&
          _tokens[_index + 1].type == TokenType.rightBrace &&
          _stack.last == Parsing.blockStmt) {
        _retStr += '\n';
      }
    }

    return _retStr +
        _currentLine +
        ((_currentLine != _indent * _indentLevel) ? '\n' : '');
  }

  Token get _next =>
      (_index + 1 < _tokens.length) ? _tokens[_index + 1] : _tokens.last;

  // Token get _previous => _tokens[_index - 1];

  void _whitespaceFollowing(Token token) {
    if (_demandsLinebreak(token.type) ||
        (_allowsLinebreak(token.type) &&
            _currentLine.length + _lengthUntilNextPossibleLinebreak() >=
                _maxLineLength)) {
      _processLinebreak();
    } else if (!_doesntWantWhitespace(token)) _currentLine += ' ';
  }

  int _lengthUntilNextPossibleLinebreak() {
    var length = 1;
    final actualIndentLevel = _indentLevel;
    final actualStack = _stack;
    _stack = Queue.from(_stack);
    final actualIndex = _index;
    final actualunclosedParenthesesInForClause =
        _unclosedParenthesesInForClause;
    for (int i = _index + 1; i < _tokens.length; ++i) {
      final token = _tokens[i];

      if (token.type == TokenType.lineBreak) break;

      length += _formattedToken(token).length;

      if (_allowsLinebreak(token.type) || _demandsLinebreak(token.type)) break;
    }
    _indentLevel = actualIndentLevel;
    _index = actualIndex;
    _stack = actualStack;
    _unclosedParenthesesInForClause = actualunclosedParenthesesInForClause;

    return length;
  }

  String _formattedToken(Token t) {
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
      case TokenType.del:
        return '∂';
      case TokenType.leftBrace:
        ++_indentLevel;
        _stack.add(_leftBraceType());
        return '{';
      case TokenType.rightBrace:
        if (_stack.last != Parsing.nothing) {
          _lastParsed = _stack.removeLast();
        }
        --_indentLevel;
        return '}';
      case TokenType.forToken:
        _stack.add(Parsing.forclause);
        _unclosedParenthesesInForClause = 0;
        return "for";
      case TokenType.leftParentheses:
        if (_stack.last == Parsing.forclause) ++_unclosedParenthesesInForClause;
        return '(';
      case TokenType.rightParentheses:
        if (_stack.last == Parsing.forclause &&
            --_unclosedParenthesesInForClause == 0) {
          _lastParsed = _stack.removeLast();
        }
        return ')';
      default:
        return t.lexeme;
    }
  }

  Parsing _leftBraceType() {
    var i = _index - 1;

    Token previous;

    //finds the previous token, ignoring comments
    while (i >= 0) {
      Token aux = _tokens[i];
      if (aux.type != TokenType.comment &&
          aux.type != TokenType.hash &&
          aux.type != TokenType.multilineComment &&
          aux.type != TokenType.wordComment) {
        previous = aux;
        break;
      }
      --i;
    }
    if (previous.type == TokenType.setToken) return Parsing.setExpr;
    //if right before the '{' we have a ')', we must be looking at a
    //for, while or if block
    if (previous.type == TokenType.rightParentheses) return Parsing.blockStmt;
    //sets can only have expressions in them, blocks can have expressions and statements
    var unclosedBraces = 1;
    for (var i = _index + 1; i < _tokens.length; ++i) {
      final token = _tokens[i];
      if (token.type == TokenType.rightBrace) --unclosedBraces;
      if (unclosedBraces < 1) break;

      if (token.type == TokenType.leftBrace) return Parsing.blockStmt;
      //break instead of return because this is just returning the assumed default, which
      //is after the for loop

      if ((token.type == TokenType.comma ||
              token.type == TokenType.verticalBar) &&
          unclosedBraces == 1) {
        return Parsing.setExpr;
      }

      if (token.type == TokenType.forToken ||
          token.type == TokenType.whileToken ||
          token.type == TokenType.ifToken ||
          token.type == TokenType.elseToken ||
          token.type == TokenType.classToken ||
          token.type == TokenType.returnToken ||
          token.type == TokenType.routine ||
          token.type == TokenType.print ||
          token.type == TokenType.let) {
        return Parsing.blockStmt;
      }
    }

    return Parsing.setExpr;
  }

  bool _demandsLinebreak(TokenType type) {
    //opening and closing scopes should always trigger a linebreak (at least for now)
    return ((type == TokenType.leftBrace ||
                _next.type == TokenType.rightBrace) &&
            (_stack.last == Parsing.blockStmt)) ||
        (type == TokenType.rightBrace &&
            _lastParsed == Parsing.blockStmt &&
            _next.type != TokenType.elseToken) ||
        //outside of for statement clauses, semicolons want linebreaks
        //except if right after it, there is an actual linebreak
        //(i want to let that token deal with it, because then it is easier to
        //diferentiate between one and two linebreaks after a semicolon-terminated
        //statement )
        (type == TokenType.semicolon &&
            _stack.last != Parsing.forclause &&
            _next.type != TokenType.lineBreak);
  }

  bool _allowsLinebreak(TokenType type) =>
      type == TokenType.leftBrace ||
      type == TokenType.leftParentheses ||
      type == TokenType.leftBrace ||
      type == TokenType.comma ||
      type == TokenType.dot ||
      type == TokenType.minus ||
      type == TokenType.plus ||
      type == TokenType.slash ||
      type == TokenType.invertedSlash ||
      type == TokenType.star ||
      type == TokenType.approx ||
      type == TokenType.exp ||
      type == TokenType.verticalBar ||
      type == TokenType.assigment ||
      type == TokenType.equals ||
      type == TokenType.identicallyEquals ||
      type == TokenType.greater ||
      type == TokenType.greaterEqual ||
      type == TokenType.lessEqual ||
      type == TokenType.less ||
      type == TokenType.and ||
      type == TokenType.belongs ||
      type == TokenType.contained ||
      type == TokenType.disjoined ||
      type == TokenType.elseToken ||
      type == TokenType.intersection ||
      type == TokenType.not ||
      type == TokenType.or;

  bool _doesntWantWhitespace(Token token) {
    final next = _next.type;

    //';', ''' and ',' shouldn't have whitespace before, only after
    if (next == TokenType.semicolon ||
        next == TokenType.comma ||
        next == TokenType.apostrophe) return true;

    //calls and derivative expressions
    if ((token.type == TokenType.identifier || token.type == TokenType.del) &&
        next == TokenType.leftParentheses) return true;

    if (token.type == TokenType.leftParentheses ||
        token.type == TokenType.leftSquare ||
        token.type == TokenType.leftBrace) return true;
    if (next == TokenType.rightBrace ||
        next == TokenType.rightParentheses ||
        next == TokenType.rightSquare) return true;

    //unary left operators shouldn't have whitespace following
    //thing is, '-' can be both unary and binary, which is a major pain in the ass
    if (token.type == TokenType.not || token.type == TokenType.approx)
      return true;

    if (token.type == TokenType.minus) return _isUnaryMinus();
    return false;
  }

  bool _isUnaryMinus() {
    var i = _index - 1;

    Token previous;

    //finds the previous token, ignoring comments
    while (i >= 0) {
      Token aux = _tokens[i];
      if (aux.type != TokenType.comment &&
          aux.type != TokenType.hash &&
          aux.type != TokenType.multilineComment &&
          aux.type != TokenType.wordComment) {
        previous = aux;
        break;
      }
      --i;
    }

    //if there is no previous non-comment token, this is necessarily unary
    if (previous == null) return true;

    //if the minus character is unary, the character that precedes it won't
    //be something that could be part of a previous expression:
    if (previous.type == TokenType.lineBreak ||
        previous.type == TokenType.leftBrace ||
        previous.type == TokenType.leftParentheses ||
        previous.type == TokenType.leftSquare ||
        previous.type == TokenType.semicolon ||
        previous.type == TokenType.lineBreak ||
        previous.type == TokenType.comma ||
        previous.type == TokenType.verticalBar ||
        previous.type == TokenType.plus ||
        previous.type == TokenType.minus ||
        previous.type == TokenType.star ||
        previous.type == TokenType.slash ||
        previous.type == TokenType.exp ||
        previous.type == TokenType.invertedSlash ||
        previous.type == TokenType.approx ||
        previous.type == TokenType.not ||
        previous.type == TokenType.and ||
        previous.type == TokenType.or ||
        previous.type == TokenType.identicallyEquals ||
        previous.type == TokenType.equals ||
        previous.type == TokenType.assigment ||
        previous.type == TokenType.less ||
        previous.type == TokenType.lessEqual ||
        previous.type == TokenType.greater ||
        previous.type == TokenType.greaterEqual ||
        previous.type == TokenType.belongs ||
        previous.type == TokenType.contained ||
        previous.type == TokenType.disjoined ||
        previous.type == TokenType.elseToken ||
        previous.type == TokenType.intersection ||
        previous.type == TokenType.print ||
        previous.type == TokenType.returnToken ||
        previous.type == TokenType.union) return true;

    //these first two guarantee binary because they apply
    //to the expression that precedes then
    if (previous.type == TokenType.apostrophe ||
        previous.type == TokenType.factorial ||
        //for now guarantees binary because it only shows up
        //on interval definitions
        previous.type == TokenType.rightSquare ||
        previous.type == TokenType.identifier ||
        previous.type == TokenType.number ||
        previous.type == TokenType.thisToken ||
        //doesn't make sense, because you can't subtract from these things,
        //but we can format it to look pretty anyway
        previous.type == TokenType.string ||
        previous.type == TokenType.falseToken ||
        previous.type == TokenType.nil ||
        previous.type == TokenType.trueToken ||
        previous.type == TokenType.unknown) return false;

    // ')' and '}' are a special kind of hell because of these things:
    // if(variable)-otherVariable; -> unary
    // BUT
    // (variable)-otherVariable; -> binary
    //and
    // if(variable){variable=variable+1}-otherVariable; -> unary
    //BUT
    // {1,2,3}-(1.5, 2.5) -> binary

    //the easy way, since the unary case for both is kinda meaningless, would be to assume binary
    //however, since it is not invalid, and i might add operator overloads sometime, we can't assume
    //no one will ever write it.

    //for this, the token right before the parentheses was opened (excluding comments)
    //will determine wheter it was unary or binary: if it is 'if', 'while' or 'for', it is unary
    //and if it is anything else, it is binary. it is also binary if the parentheses actually is closing a
    //left square bracket, because then it is an left-closed right-open interval definition
    if (previous.type == TokenType.rightParentheses) {
      var unopenedBrackets = 1;
      --i;
      while (i >= 0) {
        final type = _tokens[i].type;
        if (type == TokenType.rightParentheses ||
            type == TokenType.rightSquare) {
          ++unopenedBrackets;
        } else if (type == TokenType.leftParentheses ||
            type == TokenType.leftSquare) --unopenedBrackets;
        //found start of group/parenthesized clause
        if (unopenedBrackets == 0) {
          //was interval!
          if (type == TokenType.leftSquare) return false;
          break;
        }
        --i;
      }
      --i;
      //ignore comments
      while (i >= 0) {
        TokenType aux = _tokens[i].type;
        if (aux != TokenType.comment &&
            aux != TokenType.hash &&
            aux != TokenType.multilineComment &&
            aux != TokenType.wordComment) {
          break;
        }
        --i;
      }
      //parentheses is unopened/opened right at the beggining -> binary
      if (i <= 0) return false;

      TokenType typeBeforeOpening = _tokens[i].type;
      return typeBeforeOpening == TokenType.ifToken ||
          typeBeforeOpening == TokenType.whileToken ||
          typeBeforeOpening == TokenType.forToken;
      //need to make sure we're not taking a comment
    }

    //if we were parsing a block, it's unary
    //if it was a set, it's binary
    if (previous.type == TokenType.rightBrace) {
      return _lastParsed == Parsing.blockStmt;
    }

    //the token types which would reach this point are:
    //  dot ('.')
    //  classToken ('class')
    //  del ('del' or '∂')
    //  ifToken('if')
    //  forToken('for')
    //  let('let')
    //  routine('routine')
    //  setToken('set')
    //  superToken('super')
    //  whileToken('while')
    //  EOF(end of file)
    //which are all syntax errors anyway, so who cares
    return true;
  }

  void _processLinebreak() {
    //in principle, ignores linebreaks inside for clauses

    if (_stack.last == Parsing.forclause) return;
    _retStr +=
        ((_currentLine == _indent * _indentLevel) ? "" : _currentLine) + '\n';
    _currentLine = (_next.type == TokenType.rightBrace)
        ? _indent * (_indentLevel - 1)
        : _indent * _indentLevel;
  }
}
