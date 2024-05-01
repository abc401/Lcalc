package lexer

import (
	"bytes"
	"fmt"
	"unicode"
)

type TokenKind string

var SpecialChars = []byte{'.', '\\', '\n'}

const (
	EndOfFile   TokenKind = "EndOfFile"
	StartOfFile TokenKind = "StartOfFile"

	Slash   TokenKind = "Slash"
	Dot     TokenKind = "Dot"
	Ident   TokenKind = "Ident"
	Space   TokenKind = "Space"
	NewLine TokenKind = "NewLine"
)

type Token struct {
	Kind   TokenKind
	Lexeme []byte
}

func (token *Token) Dump() string {
	if token.Kind == Ident {
		return fmt.Sprintf("Ident(%s)", token.Lexeme)
	}
	return string(token.Kind)

}

type Lexer struct {
	Source    []byte
	loc       int
	PeekToken *Token
}

func NewLexer(source []byte) Lexer {
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

func (lexer *Lexer) Lex() {
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
	} else if unicode.IsSpace(peekCh) {
		newPeekToken.Kind = Space

		for unicode.IsSpace(lexer.PeekCh()) {
			lexer.advance()
		}
	} else if unicode.IsGraphic(lexer.PeekCh()) {
		start := lexer.loc
		peekCh = lexer.PeekCh()
		for unicode.IsGraphic(peekCh) && !unicode.IsSpace(peekCh) && !bytes.ContainsRune(SpecialChars, peekCh) {
			lexer.advance()
			peekCh = lexer.PeekCh()

		}
		newPeekToken.Kind = Ident
		newPeekToken.Lexeme = lexer.Source[start:lexer.loc]
	}

	lexer.PeekToken = &newPeekToken
}
