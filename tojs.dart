//Entry point for the web version of the interpreter

import 'dart:html';

import 'formatter_scanner.dart';
import 'file_formatter.dart';

int main() {
  //Sets a listener for "formatButton", which gets the text in the textarea "source",
  //runs it through the formatter and writes the results back to the "source" textarea
  document.getElementById("formatButton").onClick.listen((event) {
    final TextAreaElement source = document.getElementById("source");

    bool hadError = false;

    void errorCallback(Object value, String message) => hadError = true;
    final scanner = FormatterScanner(source.value, errorCallback);
    final tokens = scanner.scanTokens();
    if (hadError) return;

    final result = FileFormatter(tokens, '  ', source.cols).format();
    if (result != null) source.value = result;
  });

  return 0;
}
