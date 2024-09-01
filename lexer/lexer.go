package lexer

import (
	"bytes"
	"fmt"
	"log"
	"unicode"

	"github.com/abc401/lcalc/predicates"
)

type TokenKind string

var SpecialChars = []byte{'.', '\\', '\n', ')', '('}

const (
	EndOfFile   TokenKind = "EndOfFile"
	StartOfFile TokenKind = "StartOfFile"

	Slash   TokenKind = "Slash"
	Dot     TokenKind = "Dot"
	Ident   TokenKind = "Ident"
	NewLine TokenKind = "NewLine"
	LBrace  TokenKind = "LBrace"
	RBrace  TokenKind = "RBrace"
)

type Token struct {
	Kind   TokenKind
	Lexeme *string
}

func (token *Token) Dump() string {
	if token.Kind == Ident {
		return fmt.Sprintf("Ident(%s)", *token.Lexeme)
	}
	return string(token.Kind)

}

type Lexer struct {
	Source    string
	loc       int
	PeekToken *Token
}

func NewLexer(source string) Lexer {
	return Lexer{
		Source: source,
		PeekToken: &Token{
			Kind:   StartOfFile,
			Lexeme: nil,
		},
		loc: 0,
	}
}

func (lexer *Lexer) advance() {
	if lexer.loc >= len(lexer.Source) {
		return
	}
	lexer.loc++
}

func (lexer *Lexer) PeekCh() rune {
	if lexer.loc >= len(lexer.Source) {
		return '\x00'
	}
	return rune(lexer.Source[lexer.loc])
}

func (lexer *Lexer) SkipSpace() {
	for predicates.IsSpace(lexer.PeekCh()) {
		lexer.advance()
	}
}

func (lexer *Lexer) Lex() {
	if lexer.PeekToken.Kind == EndOfFile {
		return
	}

	lexer.SkipSpace()
	newPeekToken := Token{}
	peekCh := lexer.PeekCh()

	if peekCh == '\x00' {
		newPeekToken.Kind = EndOfFile
	} else if peekCh == '\n' {
		newPeekToken.Kind = NewLine
		lexer.advance()
	} else if peekCh == '\\' {
		newPeekToken.Kind = Slash
		lexer.advance()
	} else if peekCh == '.' {
		newPeekToken.Kind = Dot
		lexer.advance()
	} else if peekCh == '(' {
		newPeekToken.Kind = LBrace
		lexer.advance()
	} else if peekCh == ')' {
		newPeekToken.Kind = RBrace
		lexer.advance()
	} else if unicode.IsGraphic(lexer.PeekCh()) {
		start := lexer.loc
		peekCh = lexer.PeekCh()
		for unicode.IsGraphic(peekCh) && !unicode.IsSpace(peekCh) && !bytes.ContainsRune(SpecialChars, peekCh) {
			lexer.advance()
			peekCh = lexer.PeekCh()

		}
		newPeekToken.Kind = Ident
		var b = lexer.Source[start:lexer.loc]
		newPeekToken.Lexeme = &b
	} else {
		log.Panicf("Unhandled character: %c", peekCh)
	}

	lexer.PeekToken = &newPeekToken
}
