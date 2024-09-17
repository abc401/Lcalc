package main

import (
	"fmt"
	"os"

	"github.com/abc401/lcalc/lexer"
	"github.com/abc401/lcalc/parser"
)

func main() {

	programName := os.Args[0]
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "[Error] Incorrect usage!\n")
		fmt.Fprintf(os.Stderr, "[Info] Correct usage:\n")
		fmt.Fprintf(os.Stderr, "  %s <filepath.lc>\n", programName)
		os.Exit(1)
		return
	}

	inputFilePath := os.Args[1]

	contents, err := os.ReadFile(inputFilePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[Error] %s\n", err.Error())
		os.Exit(1)
	}

	fmt.Println("[Info] Successfully opened file.")

	var l = lexer.NewLexer(string(contents))
	var p = parser.NewParser(&l)

	for {
		_expr, err := p.Parse()
		if err == parser.ErrEOF {
			break
		}
		if err != nil {
			fmt.Fprintf(os.Stdout, "[Info] `%s`\n", err)
			break
		}

		fmt.Printf("[Info] Parsed: %s\n", _expr.DumpToString())
		fmt.Printf("[Info] Evaluated: %s\n", _expr.Eval().DumpToString())
	}
}
