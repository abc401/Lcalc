package lexer

import (
	"bytes"
	"fmt"
	"log"
	"unicode"

	"github.com/abc401/lcalc/helpers"
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
	Source       string
	peekChIdx    int
	Tokens       []*Token
	peekTokenIdx int
}

func NewLexer(source string) Lexer {
	return Lexer{
		Source: source,
		Tokens: []*Token{
			{
				Kind:   StartOfFile,
				Lexeme: nil,
			}},
		peekTokenIdx: 0,
		peekChIdx:    0,
	}
}

func (lexer *Lexer) LexIdent() (*Token, bool) {
	var peekToken = lexer.PeekToken()
	if peekToken.Kind != Ident {
		return nil, false
	}
	var ident = peekToken
	lexer.Advance()

	return ident, true
}

func (lexer *Lexer) advanceSrc() {
	if lexer.peekChIdx >= len(lexer.Source) {
		return
	}
	lexer.peekChIdx++
}

func (lexer *Lexer) PeekCh() rune {
	if lexer.peekChIdx >= len(lexer.Source) {
		return '\x00'
	}
	return rune(lexer.Source[lexer.peekChIdx])
}

func (lexer *Lexer) SkipSpace() {
	var ch = lexer.PeekCh()
	for ch == ' ' || ch == '\t' || ch == '\r' {
		lexer.advanceSrc()
		ch = lexer.PeekCh()
	}
}

func (lexer *Lexer) PeekToken() *Token {
	return lexer.Tokens[lexer.peekTokenIdx]
}

func (lexer *Lexer) Rewind() {
	if lexer.peekTokenIdx == 0 {
		return
	}
	if lexer.peekTokenIdx < 0 {
		log.Panicf("[Lexer.Rewind] lexer.peekTokenIdx < 0\n\tLexer: %s", helpers.SPrettyPrint(lexer))
	}
	lexer.peekTokenIdx -= 1
}

func (lexer *Lexer) Advance() {
	if lexer.PeekToken().Kind == EndOfFile {
		return
	}

	if lexer.peekTokenIdx < len(lexer.Tokens)-1 {
		lexer.peekTokenIdx += 1
		return
	}

	lexer.SkipSpace()
	newPeekToken := Token{}
	peekCh := lexer.PeekCh()

	if peekCh == '\x00' {
		newPeekToken.Kind = EndOfFile
	} else if peekCh == '\n' {
		newPeekToken.Kind = NewLine
		lexer.advanceSrc()
	} else if peekCh == '\\' {
		newPeekToken.Kind = Slash
		lexer.advanceSrc()
	} else if peekCh == '.' {
		newPeekToken.Kind = Dot
		lexer.advanceSrc()
	} else if peekCh == '(' {
		newPeekToken.Kind = LBrace
		lexer.advanceSrc()
	} else if peekCh == ')' {
		newPeekToken.Kind = RBrace
		lexer.advanceSrc()
	} else if unicode.IsGraphic(lexer.PeekCh()) {
		start := lexer.peekChIdx
		peekCh = lexer.PeekCh()
		for unicode.IsGraphic(peekCh) && !unicode.IsSpace(peekCh) && !bytes.ContainsRune(SpecialChars, peekCh) {

			lexer.advanceSrc()
			peekCh = lexer.PeekCh()

		}
		newPeekToken.Kind = Ident
		var b = lexer.Source[start:lexer.peekChIdx]
		newPeekToken.Lexeme = &b
	} else {
		log.Panicf("Unhandled character: %c", peekCh)
	}

	lexer.Tokens = append(lexer.Tokens, &newPeekToken)
	lexer.peekTokenIdx += 1
}
