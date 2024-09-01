package main

import (
	"fmt"
	"os"

	"github.com/abc401/lcalc/lexer"
	"github.com/abc401/lcalc/parser"
)

func main() {
	exitCode := 0

	s := "hello"

	fmt.Printf("%s\n", s[0:0])

	programName := os.Args[0]
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "[Error] Incorrect usage!\n")
		fmt.Fprintf(os.Stderr, "[Info] Correct usage:\n")
		fmt.Fprintf(os.Stderr, "  %s <filepath.lc>\n", programName)
		exitCode = 1
		return
	}

	inputFilePath := os.Args[1]

	contents, err := os.ReadFile(inputFilePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "[Error] %s", err.Error())
	}
	fmt.Println("[Info] Successfully opened file.")
	fmt.Printf("[Info] Contents: \n%s\n", contents)

	var l = lexer.NewLexer(string(contents))
	var p = parser.NewParser(&l)
	for {
		expr, err := p.Parse()
		if err != nil {
			fmt.Fprintf(os.Stderr, "[Error] `%s`\n", err)
			break
		}

		fmt.Printf("\n[Info] Expression: %s\n", expr.DumpToString())
	}

	// fmt.Printf("[Info] Token: %s\n", l.PeekToken.Dump())
	// for l.PeekToken.Kind != lexer.EndOfFile {
	// 	l.Lex()
	// 	fmt.Printf("[Info] Token: %s\n", l.PeekToken.Dump())
	// }

	fmt.Println()
	os.Exit(exitCode)
}
