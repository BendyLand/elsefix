import 'dart:io';
import "argparse.dart";

void main(List<String> args) {
  final p = Parser();
  registerFlags(p);
  try {
    p.parse(args);
    final parsed = p.getParsed();
    if (parsed.containsKey("--help") ||
        parsed.containsKey("-h") ||
        (parsed.isEmpty && args.isEmpty)) {
      printUsage(p);
      return;
    }
    final filename = getFilename(args, parsed);
    if (filename.isNotEmpty) {
      File file = File(filename);
      final lines = file.readAsLinesSync();
      final spaceType = detectSpacingType(lines);
      bool includeCatch = parsed["-c"] ?? parsed["--include-catch"] ?? false;
      RegExp elsePattern = RegExp(r'}\s*\belse\b');
      RegExp catchPattern = RegExp(r'}\s*\bcatch\b');
      String result = handleLines(lines, elsePattern, catchPattern, includeCatch, spaceType);
      file.writeAsStringSync(result);
    }
    else {
      printUsage(p);
    }
  }
  catch (e) {
    print("Error: $e");
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

bool lineHasToken(String line, RegExp pattern) {
  if (!pattern.hasMatch(line)) return false;
  if (!line.contains('"') && !line.contains("'")) return true;
  int countS = "'".allMatches(line).length;
  int countD = '"'.allMatches(line).length;
  String quoteTok = countS > countD ? "'" : '"';
  int start = line.indexOf(quoteTok);
  int end = line.lastIndexOf(quoteTok);
  int target = pattern.firstMatch(line)!.start;
  if (target > start && target < end) {
    int check = pattern.allMatches(line).last.start;
    if (check == target) return false;
    while (check < end) {
      final next = pattern.allMatches(line, ++target).firstOrNull;
      if (next == null) return false;
      check = next.start;
    }
    return true;
  }
  return false;
}

void registerFlags(Parser p) {
  p.register("-", "Read from stdin (use in place of a file name)");
  p.register("--stdin", "Read from stdin");
  p.register("--include-catch", "Also fix catch blocks");
  p.register("-c", "Also fix catch blocks");
  p.register("--help", "Print this help menu.");
  p.register("-h", "Print this help menu.");
  p.register("--interactive", "Review changes one by one", type: bool);
  p.register("-i", "Review changes one by one", type: bool);
  p.register("%EXTRAS%", "");
}

int getIndentLevel(String line, SpacingType s) {
  int result = 0;
  String target = "";
  switch (s) {
    case .spaces:
      target = " ";
    case .tabs:
      target = "\t";
  }
  for (String c in line.split("")) {
    if (c != target) break;
    result++;
  }
  return result;
}

String fixLine(String line, SpacingType s, int indents) {
  String result = "";
  int brace = line.indexOf("}");
  result += "${line.substring(0, brace + 1)}\n";
  String pad = "";
  for (int i = 0; i < indents; i++) {
    switch (s) {
      case .spaces:
        pad += " ";
      case .tabs:
        pad += "\t";
    }
  }
  String remaining = line.substring(brace + 1).trimLeft();
  result += "$pad$remaining";
  return result;
}

String handleLines(
  List<String> lines,
  RegExp elsePattern,
  RegExp catchPattern,
  bool includeCatch,
  SpacingType spaceType,
) {
  String result = "";
  String newLine = "";
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    if (lineHasToken(line, elsePattern)) {
      print("Found:\n${i+1}:    ${line.trimLeft()}");
      int indentLevel = getIndentLevel(line, spaceType);
      newLine = fixLine(line, spaceType, indentLevel);
      print("Changing to:\n${i+1}:    ${newLine.split("\n")[0].trimLeft()}\n${i+2}:    ${newLine.split("\n")[1].trimLeft()}\n");
    }
    if (includeCatch) {
      if (lineHasToken(line, catchPattern)) {
        print("Found:\n${i+1}:    ${line.trimLeft()}");
        int indentLevel = getIndentLevel(line, spaceType);
        newLine = fixLine(line, spaceType, indentLevel);
        print("Changing to:\n${i+1}:    ${newLine.split("\n")[0].trimLeft()}\n${i+2}:    ${newLine.split("\n")[1].trimLeft()}\n");
      }
    }
    if (newLine.isEmpty) newLine = line;
    result += "$newLine\n";
    newLine = "";
  }
  return result;
}


