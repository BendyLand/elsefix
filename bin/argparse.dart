import 'dart:math';

// ignore_for_file: type_literal_in_constant_pattern

/// Flags which can be registered on their own to enable certain parser behaviors.
/// This mixin can be used to customize the tokens that the parser will look for to handle them. 
mixin EmbeddedFlags {
  static const String extras = "%EXTRAS%";
}

final class Parser with EmbeddedFlags {
  final Map<String, dynamic> _parsed = {};
  final Map<String, Type?> _types = {};
  final Map<String, String> _registered = {};
  bool _extrasAllowed = false;

  /// Registers the given [name] as a valid flag along with its [description].
  /// If a [type] is specified, then the flag will expect an argument of that type.
  ///
  /// Note: Flags are registerd *as they appear* at the call site.
  ///       If you want them to start with any '-'s, you must register them as such.
  /// e.g.:
  /// ```
  /// Parser p = Parser();
  /// p.register("length", "this flag will only be accepted as it appears here");
  /// p.register("--width", "likewise; the dash(es) must be present here if you want them required later.");
  /// ```
  void register(String name, String description, {Type? type}) {
    _registered[name] = description;
    _types[name] = type;
  }

  void parse(List<String> args) {
    for (int i = 0; i < args.length; i++) {
      if (args[i] == "--" || args[i] == EmbeddedFlags.extras) {
        _extrasAllowed = true;
        continue;
      }
      String item = args[i];
      dynamic val;
      if (item.contains("=")) {
        var temp = item.split("=");
        item = temp[0];
        val = temp[1];
      }
      else if (item.contains(":")) {
        var temp = item.split(":");
        item = temp[0];
        val = temp[1];
      }
      // NOTE: This allows you to fail immediately on an unrecognized flag.
      // This may or may not be desireable for your app
      if (!_registered.containsKey(item) && !_extrasAllowed) {
        // throw ArgParseException("Unknown flag '$item'.");
      }
      // Check any flag arguments that were split from '=' or ':'
      if (val != null && _types[item] != null) {
        val = convertType(val, _types[item]!);
        if (val == null) {
          throw ArgParseException(
            "Provided argument for flag '$item' doesn't match expected type `${_types[item]}`.",
          );
        }
      }
      if (_registered.containsKey(item)) {
        if (val == null && _types[item] != null) {
          if (i >= args.length - 1 ||
              (i < args.length - 1 && _registered.containsKey(args[i + 1]))) {
            throw ArgParseException(
              "Unsupplied argument of type `${_types[item]}` for flag '$item'.",
            );
          }
          else {
            var next = args[i + 1];
            val = convertType(next, _types[item]!);
            if (val == null) {
              throw ArgParseException(
                "Provided argument for flag '$item' doesn't match expected type `${_types[item]}`.",
              );
            }
            _parsed[item] = val;
          }
          i++; // advance the idx for the consumed arg
        }
        else {
          _parsed[item] = (_types[item] == null && val == null) ? true : val;
        }
      }
    }
  }

  /// Attempts to convert the given string into the specified type.
  ///
  /// [val] is the string to convert, and [t] is the type it should be converted to.
  ///
  /// If [val] is not a valid 'shape' for the type [t], this function returns `null`.
  dynamic convertType(String val, Type? t) {
    return switch (t) {
      String => val,
      bool => bool.tryParse(val),
      num => num.tryParse(val),
      int => int.tryParse(val),
      double => double.tryParse(val),
      null => null,
      _ => throw Exception("Unknown type specified"),
    };
  }

  /// Returns a map of registered flags and their descriptions.
  Map<String, String> getRegistered() => _registered;

  /// Returns a map of registered flags and their associated argument types.
  Map<String, Type?> getTypes() => _types;

  /// Returns a map of the parsed flags and their arguments.
  Map<String, dynamic> getParsed() => _parsed;

  /// Returns a boolean of whether or not any of the registered flags were parsed.
  bool anyFlagsParsed() => _parsed.isNotEmpty;
  
  void printFlags() {
    int longest = _registered.keys.map((x) => x.length).fold(0, max);
    print("Valid flags:");
    for (final entry in _registered.entries) {
      Type? arg = _types[entry.key];
      String argMsg = "";
      if (arg != null) {
        argMsg += " (argument type: `$arg`)";
      }
      print("\t${entry.key.padRight(longest)} - ${entry.value}$argMsg");
    }
  }
}

class ArgParseException implements Exception {
  final String message;
  ArgParseException(this.message);

  @override
  String toString() => "ArgParseException: $message";
}

