package main

import (
	"fmt"
	"os"

	"github.com/abc401/lcalc/lexer"
)

func main() {
	exitCode := 0

	s := "hello"

	fmt.Printf("%s\n", s[0:0])

	defer func() {

		fmt.Println()
		os.Exit(exitCode)
	}()

	programName := os.Args[0]
	if len(os.Args) != 2 {
		fmt.Fprintf(os.Stderr, "[Error] Incorrect usage!\n")
		fmt.Println("[Info] Correct usage:")
		fmt.Printf("  %s <filepath.lc>\n", programName)
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

	l := lexer.NewLexer(contents)
	fmt.Printf("[Info] Token: %s\n", l.PeekToken.Dump())
	for l.PeekToken.Kind != lexer.EndOfFile {
		l.Lex()
		fmt.Printf("[Info] Token: %s\n", l.PeekToken.Dump())
	}

}
