import "argparse.dart";

void main(List<String> args) {
  final p = Parser();
  p.register("-", "Read from stdin (use in place of a file name)");
  p.register("--stdin", "Read from stdin");
  p.register("--include-catch", "Also fix catch blocks");
  p.register("-c", "Also fix catch blocks");
  p.register("--help", "Print this help menu.");
  p.register("-h", "Print this help menu.");
  p.register("--interactive", "Review changes one by one", type: bool);
  p.register("-i", "Review changes one by one", type: bool);
  p.register("%EXTRAS%", "");
  try {
    p.parse(args);
    final results = p.getParsed();
    if (results.containsKey("--help") || results.containsKey("-h") || (results.isEmpty && args.isEmpty)) {
      printUsage(p);
      return;
    }
    
  } catch (e) {
    print(e);
    p.printFlags();
  }
}

enum SpacingType { spaces, tabs }

SpacingType detectSpacingType(String file) {
  int spaces = 0;
  int tabs = 0;
  List<String> lines = file.split("\n");
  for (String line in lines) {
    if (line.isNotEmpty) {
      switch (line[0]) {
      case ' ': spaces++;
      case '\t': tabs++;
      }
    }
  }
  return spaces > tabs ? .spaces : .tabs;
}

void printUsage(Parser p) {
  final int maxWidth = p.getRegistered().keys
      .map((key) => "'$key'".length) 
      .fold(0, (max, length) => length > max ? length : max);
  print("Usage: elsefix [<filename>|-] [flags]");
  print("Flags:");
  for (final entry in p.getRegistered().entries) {
    if (entry.value.isEmpty) continue; // skip embedded flags, which don't have descriptions
    final String flag = "'${entry.key}'".padRight(maxWidth);
    print("    $flag : ${entry.value}");
  }
}

