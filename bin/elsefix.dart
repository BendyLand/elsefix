import 'dart:io';
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
    if (results.containsKey("--help") ||
        results.containsKey("-h") ||
        (results.isEmpty && args.isEmpty)) {
      printUsage(p);
      return;
    }
    final filename = getFilename(args, results);
    if (filename.isNotEmpty) {
      final lines = File(filename).readAsLinesSync();
      final spaceType = detectSpacingType(lines);
      print(spaceType);
      for (String line in lines) {
        // TODO: Implement main logic
        if (lineHasToken(line, "} else")) {
          print(line);
        }
      }
    } else {
      printUsage(p);
    }
  } catch (e) {
    print(e);
    p.printFlags();
  }
}

enum SpacingType { spaces, tabs }

SpacingType detectSpacingType(List<String> lines) {
  int spaces = 0;
  int tabs = 0;
  for (String line in lines) {
    if (line.isNotEmpty) {
      switch (line[0]) {
        case ' ':
          spaces++;
        case '\t':
          tabs++;
      }
    }
  }
  return spaces > tabs ? .spaces : .tabs;
}

void printUsage(Parser p) {
  final int maxWidth = p
      .getRegistered()
      .keys
      .map((key) => "'$key'".length)
      .fold(0, (max, length) => length > max ? length : max);
  print("Usage: elsefix [<filename>|-] [flags]");
  print("Flags:");
  for (final entry in p.getRegistered().entries) {
    if (entry.value.isEmpty) {
      continue; // skip embedded flags, which don't have descriptions
    }
    final String flag = "'${entry.key}'".padRight(maxWidth);
    print("    $flag : ${entry.value}");
  }
}

String getFilename(List<String> args, Map<String, dynamic> parsed) {
  final p = {...parsed.keys, ...parsed.values};
  final possible = args.where((item) => !p.contains(item)).toList();
  if (possible.length == 1) return possible[0];
  return "";
}

bool lineHasToken(String line, String tok) {
  if (line.contains(tok)) {
    if (!line.contains('"') && !line.contains("'")) {
      return true;
    } else {
      int countS = line.allMatches("'").length;
      int countD = line.allMatches('"').length;
      String quoteTok = countS > countD ? "'" : '"';
      int start = line.indexOf(quoteTok);
      int end = line.lastIndexOf(quoteTok);
      int target = line.indexOf(tok);
      if (target > start && target < end) {
        int check = line.lastIndexOf(tok);
        if (check == target) return false;
        while (check < end) {
          check = line.indexOf(tok, ++target);
          if (check == -1) return false;
        }
        return true;
      }
    }
  }
  return false;
}
