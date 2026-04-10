import 'dart:convert';
import 'dart:io';

import "argparse.dart";

void main(List<String> args) async {
  final p = Parser();
  registerFlags(p);
  try {
    runMain(args, p);
  }
  catch (e) {
    print("Error: $e");
    p.printFlags();
  }
}

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

String getFilename(List<String> args, Map<String, dynamic> parsed) {
  final p = {...parsed.keys, ...parsed.values};
  final possible = args.where((item) => !p.contains(item)).toList();
  if (possible.length == 1) return possible[0];
  return "";
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
String handleLine(String line, int i, bool toStdout, SpacingType spaceType) {
  String result = "";
  if (!toStdout) {
    print("Found:\n${i + 1}:    ${line.trimLeft()}");
  }
  int indentLevel = getIndentLevel(line, spaceType);
  result = fixLine(line, spaceType, indentLevel);
  if (!toStdout) {
    print(
      "Changing to:\n${i + 1}:    ${result.split("\n")[0].trimLeft()}\n${i + 2}:    ${result.split("\n")[1].trimLeft()}\n",
    );
  }
  return result;
}
Future<String> handleLines(
  List<String> lines,
  RegExp elsePattern,
  RegExp? catchPattern,
  bool includeCatch,
  bool toStdout,
  SpacingType spaceType,
  bool interactive,
) async {
  String result = "";
  bool acceptAll = false;
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    String newLine = "";
    bool matched =
        lineHasToken(line, elsePattern) ||
        (includeCatch && lineHasToken(line, catchPattern!));
    if (matched) {
      if (interactive && !acceptAll) {
        int indentLevel = getIndentLevel(line, spaceType);
        String fixed = fixLine(line, spaceType, indentLevel);
        showInteractiveDiff(lines, i, fixed);
        stderr.write("[y]es / [n]o / [A]ccept all / [q]uit: ");
        String response = promptUser();
        stderr.writeln("");
        switch (response) {
          case 'q':
            result += "$line\n";
            for (int j = i + 1; j < lines.length; j++) {
              result += "${lines[j]}\n";
            }
            return result;
          case 'A':
            acceptAll = true;
            newLine = fixed;
          case 'y':
            newLine = fixed;
          // default ('n' or anything else): leave newLine empty to keep original
        }
      }
      else {
        newLine = handleLine(line, i, toStdout, spaceType);
      }
    }
    if (newLine.isEmpty) newLine = line;
    result += "$newLine\n";
  }
  return result;
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

String promptUser() {
  stdin.echoMode = false;
  stdin.lineMode = false;
  int byte = stdin.readByteSync();
  stdin.echoMode = true;
  stdin.lineMode = true;
  return String.fromCharCode(byte);
}

void registerFlags(Parser p) {
  p.register("--stdin", "Read from stdin (use in place of a file name).");
  p.register("-", "Read from stdin (use in place of a file name).");
  p.register("--stdout", "Print results to stdout.");
  p.register("-s", "Print results to stdout.");
  p.register("--include-catch", "Also fix catch blocks.");
  p.register("-c", "Also fix catch blocks.");
  p.register("--help", "Print this help menu.");
  p.register("-h", "Print this help menu.");
  p.register("--interactive", "Review changes one by one.");
  p.register("-i", "Review changes one by one.");
  p.register("%EXTRAS%", "");
}

void runMain(List<String> args, Parser p) async {
  p.parse(args);
  final parsed = p.getParsed();
  if (parsed.containsKey("--help") ||
      parsed.containsKey("-h") ||
      (parsed.isEmpty && args.isEmpty)) {
    printUsage(p);
    return;
  }
  bool useStdin = parsed.containsKey("-") || parsed.containsKey("--stdin");
  bool interactive = parsed["-i"] ?? parsed["--interactive"] ?? false;
  if (interactive && useStdin) {
    print("Error: --interactive cannot be used with --stdin.");
    return;
  }
  String filename = getFilename(args, parsed);
  late List<String> lines;
  late File file;
  if (useStdin) {
    String text = await stdin.transform(utf8.decoder).join("\n");
    lines = text.split("\n");
  }
  else if (filename.isNotEmpty) {
    file = File(filename);
    lines = file.readAsLinesSync();
  }
  else {
    printUsage(p);
  }
  final spaceType = detectSpacingType(lines);
  bool includeCatch = parsed["-c"] ?? parsed["--include-catch"] ?? false;
  RegExp elsePattern = RegExp(r'}\s*\belse\b');
  RegExp? catchPattern;
  if (includeCatch) {
    catchPattern = RegExp(r'}\s*\bcatch\b');
  }
  bool toStdout = parsed["-s"] ?? parsed["--stdout"] ?? false;
  String result = await handleLines(
    lines,
    elsePattern,
    catchPattern,
    includeCatch,
    toStdout || useStdin,
    spaceType,
    interactive,
  );
  if (toStdout || useStdin) {
    print(result);
  }
  else {
    file.writeAsStringSync(result);
  }
}

const String _dim = '\x1B[2m';
const String _green = '\x1B[32m';
const String _red = '\x1B[31m';
const String _reset = '\x1B[0m';

void showInteractiveDiff(List<String> lines, int i, String fixed) {
  const int ctx = 2;
  final List<String> fixedLines = fixed.split("\n");
  final int numWidth = lines.length.toString().length;
  String pad(int n) => (n + 1).toString().padLeft(numWidth);
  int start = (i - ctx).clamp(0, lines.length);
  for (int j = start; j < i; j++) {
    print("$_dim  ${pad(j)} | ${lines[j]}$_reset");
  }
  print("$_red- ${pad(i)} | ${lines[i]}$_reset");
  print("$_green+ ${pad(i)} | ${fixedLines[0]}$_reset");
  print("$_green+ ${pad(i + 1)} | ${fixedLines[1]}$_reset");
  int end = (i + ctx + 1).clamp(0, lines.length);
  for (int j = i + 1; j < end; j++) {
    print("$_dim  ${pad(j)} | ${lines[j]}$_reset");
  }
  print("");
}

enum SpacingType { spaces, tabs }
