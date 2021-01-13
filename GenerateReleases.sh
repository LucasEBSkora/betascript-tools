dart2native -o releases/CLI/bsfmt format.dart
dart2js -o releases/web/tojs.js tojs.dart
cd releases/web
cp -v *  ../../../bs/formatter
