//main function for the command line version
import 'formatter.dart';

int main(List<String> args) {
  if (args.length == 0 ||
      args.firstWhere((element) => element == "-h" || element == "--help",
              orElse: () => null) !=
          null) {
    print("formats BScript code according to style guides");
    print("usage: bsfmt [options] [files and/or directories]");
    print("options:");
    print(
        "-i=[n][t] or --indent=[n][t], where [t] is t for tabs and s spaces, and ommiting it is counted as s,\n\t and [n] is the number of tabs or spaces to use. Default is 2s");
    print(
        "-l=[length] or --length=[length], where [lenght] is the max desired length for a line. default is 120 characters.");
    print(
        "-h or --help: shows this output, ignores rest of parameters completely");
  } else {
    try {
      Formatter(args).format();
    } on FormatterException catch (e) {
      print(e);
    }
  }
  return 0;
}
