# elsefix

A command-line tool that reformats `} else {` (and optionally `} catch`) constructs so that the `else`/`catch` keyword appears on its own line, separated from the closing brace.

**Before:**
```dart
if (condition) {
  doSomething();
} else {
  doOther();
}
```

**After:**
```dart
if (condition) {
  doSomething();
}
else {
  doOther();
}
```

elsefix automatically detects whether the file uses spaces or tabs and preserves the existing indentation style.

## Requirements

- [Dart SDK](https://dart.dev/get-dart) ^3.10.7

## Installation

### Run from source

```sh
dart run bin/elsefix.dart <filename> [flags]
```

### Build a native executable

```sh
dart compile exe bin/elsefix.dart
mv bin/elsefix.exe elsefix
```

Then place the resulting `elsefix` binary somewhere on your `$PATH`.

## Usage

```
elsefix [<filename>|-] [flags]
```

### Flags

| Flag               | Short | Description                                      |
|--------------------|-------|--------------------------------------------------|
| `--stdin`          | `-`   | Read from stdin instead of a file                |
| `--stdout`         | `-s`  | Print results to stdout instead of editing in place |
| `--include-catch`  | `-c`  | Also reformat `} catch` blocks                   |
| `--interactive`    | `-i`  | Review each change individually before applying  |
| `--help`           | `-h`  | Print the help menu                              |

## Examples

**Edit a file in place:**
```sh
elsefix myfile.dart
```

**Preview changes without modifying the file:**
```sh
elsefix myfile.dart --stdout
```

**Also fix `} catch` blocks:**
```sh
elsefix myfile.dart --include-catch
```

**Read from stdin and write to stdout (useful in pipelines):**
```sh
cat myfile.dart | elsefix -
```

**Interactive mode — review each change one at a time:**
```sh
elsefix myfile.dart --interactive
```

In interactive mode, a colored diff is shown for each match and you are prompted to respond:

```
  3 | if (condition) {
  4 |   doSomething();
- 5 | } else {
+ 5 | }
+ 6 | else {
  7 |   doOther();

[y]es / [n]o / [A]ccept all / [q]uit:
```

| Key | Action                              |
|-----|-------------------------------------|
| `y` | Accept this change                  |
| `n` | Skip this change                    |
| `A` | Accept this and all remaining changes |
| `q` | Quit; leave remaining lines unchanged |

> Note: `--interactive` cannot be combined with `--stdin`.

## Notes

- elsefix is smart about string literals — it will not reformat `else` or `catch` that appears inside a quoted string.
- When editing in place (default), the file is overwritten with the reformatted content.
- When using `--stdin` or `--stdout`, the result is printed to stdout.
