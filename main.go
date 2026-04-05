package main

import (
	"fmt"
	"io"
	"os"
	"regexp"
	"slices"
	"strings"
)

func main() {
	args := os.Args
	if len(args) > 1 {
		var file []byte
		var err error
		stdout := false
		catchesToo := false
		if slices.Contains(os.Args, "--include-catch") {
			catchesToo = true
		}
		switch args[1] {
		case "-":
			file, err = io.ReadAll(os.Stdin)
			stdout = true
		default:
			file, err = os.ReadFile(args[1])
		}
		if err != nil {
			fmt.Printf("Error reading file: %v\n", err)
			return
		}
		perm, _ := os.Lstat(args[1])
		lines := strings.Split(string(file), "\n")
		fixedLines := fixElseLines(lines, stdout, catchesToo)
		newFile := strings.Join(fixedLines, "\n")
		switch stdout {
		case true:
			fmt.Println(newFile)
		default:
			err = os.WriteFile(args[1], []byte(newFile), perm.Mode().Perm())
			if err != nil {
				fmt.Printf("Error writing file: %v\n", err)
			}
		}
	} else {
		fmt.Println("Usage: elsefix [<filename>|-] [--include-catch]\n(If '-' is passed as the argument, elsefix reads from stdin.)")
	}
}

func fixElseLines(lines []string, stdout bool, catches bool) []string {
	result := shiftBraceLines(lines, stdout, catches)
	result = shiftLongLines(result, stdout)
	return result
}

func shiftBraceLines(lines []string, stdout bool, catches bool) []string {
	var pattern *regexp.Regexp
	switch catches {
	case true:
		pattern = regexp.MustCompile(`\}\s*else.*|\}\s*catch.*`)

	case false:
		pattern = regexp.MustCompile(`\}\s*else.*`)
	}
	result := make([]string, 0)
	for i, line := range lines {
		if pattern.Match([]byte(line)) {
			if !stdout {
				fmt.Println("Found:")
				fmt.Printf("%d: %s\n", i+1, line)
			}
			start := strings.Index(line, "else")
			if start < 0 {
				start = strings.Index(line, "catch")
			}
			stop := strings.Index(line, "}")
			prefixStr := ""
			prefix := ' '
			if line[0] == '\t' {
				prefix = '\t'
			}
			currentLine := line[:stop+1]
			nextLine := line[start:]
			for range stop {
				prefixStr += string(prefix)
			}
			nextLine = fmt.Sprintf("%s%s", prefixStr, nextLine)
			if !stdout {
				fmt.Println("Changing to:")
				fmt.Printf("%d: %s\n%d: %s\n\n", i+1, currentLine, i+2, nextLine)
			}
			result = append(result, currentLine, nextLine)
		} else {
			result = append(result, line)
		}
	}
	return result
}

func shiftLongLines(lines []string, stdout bool) []string {
	result := make([]string, 0)
	for i, line := range lines {
		if strings.Count(line, "else") <= 1 {
			result = append(result, line)
			continue
		}
		if !stdout {
			fmt.Println("Found:")
			fmt.Printf("%d: %s\n", i+1, line)
		}
		indent := line[:len(line)-len(strings.TrimLeft(line, " \t"))]
		pieces := []string{}
		// manually scan for each 'else'
		rest := line
		for {
			idx := strings.Index(rest, "else")
			if idx == -1 {
				break
			}
			// find where this clause ends — either at the next 'else' or end of line
			next := strings.Index(rest[idx+4:], "else")
			var clause string
			if next != -1 {
				clause = strings.TrimSpace(rest[idx : idx+4+next])
				rest = rest[idx+4+next:]
			} else {
				clause = strings.TrimSpace(rest[idx:])
				rest = ""
			}
			pieces = append(pieces, indent+clause)
		}
		if !stdout {
			for j, p := range pieces {
				fmt.Printf("  => line %d.%d: %s\n", i+1, j+1, p)
			}
		}
		result = append(result, pieces...)
	}
	return result
}

