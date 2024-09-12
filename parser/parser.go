package parser

import (
	"errors"
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/abc401/lcalc/helpers"
	"github.com/abc401/lcalc/lexer"
)

var (
	ErrNotFound            = errors.New("Not Found")
	ErrSyntaxError         = errors.New("Syntax Error")
	ErrParsedSomethingElse = errors.New("Parsed something other than was asked")
	ErrEOF                 = errors.New("End of file")
)

type Expr struct {
	Value interface{}
}

func NilExpr() Expr {
	return Expr{
		Value: nil,
	}
}

func (expr Expr) DumpToString() string {

	if app, ok := expr.Application(); ok {
		return "(" + app.Of.DumpToString() + " " + app.To.DumpToString() + ")"
	}
	if abs, ok := expr.Abstraction(); ok {
		var str = "(\\"
		for i, ident := range abs.Of {
			if i == len(abs.Of)-1 {
				str += ident.DumpToString()
			} else {
				str += ident.DumpToString() + " "
			}
		}
		str += ". " + abs.From.DumpToString() + ")"
		return str
	}
	if ident, ok := expr.Ident(); ok {
		return ident.DumpToString()
	}
	return "[Nil]"
}

func (expr Expr) IsNil() bool {
	return expr.Value == nil
}

func NewExpr(expr interface{}) Expr {
	var _, okApp = expr.(ExprApplication)
	var _, okAbs = expr.(ExprAbstraction)
	var _, okIdent = expr.(ExprIdent)

	if !(okApp || okAbs || okIdent) {
		log.Panicf("[Panic] Tried to pass unexpected value to Expr constructor!\nvalue: %s", helpers.SPrettyPrint(expr))
	}

	return Expr{
		Value: expr,
	}
}

func (expr Expr) Application() (ExprApplication, bool) {
	var app, ok = expr.Value.(ExprApplication)
	return app, ok
}

func (expr Expr) Abstraction() (ExprAbstraction, bool) {
	var abs, ok = expr.Value.(ExprAbstraction)
	return abs, ok
}

func (expr Expr) Ident() (ExprIdent, bool) {
	var ident, ok = expr.Value.(ExprIdent)
	return ident, ok
}

type ExprApplication struct {
	Of Expr
	To Expr
}

type Uniquifier uint

type ExprIdent struct {
	Lexeme     string
	Uniquifier Uniquifier
}

func (ident ExprIdent) Equals(other ExprIdent) bool {
	return ident.Lexeme == other.Lexeme && ident.Uniquifier == other.Uniquifier
}

func (ident *ExprIdent) DumpToString() string {
	return ident.Lexeme + "_" + strconv.FormatUint(uint64(ident.Uniquifier), 10)
}

type ExprAbstraction struct {
	Of   []*ExprIdent
	From Expr
}

type Parser struct {
	Lexer *lexer.Lexer
}

func NewParser(_lexer *lexer.Lexer) *Parser {
	if _lexer.PeekToken.Kind == lexer.StartOfFile {
		_lexer.Lex()
	}
	return &Parser{
		Lexer: _lexer,
	}
}

// func (parser *Parser) parseExprIdent() (*ExprIdent, error) {
// 	var _lexer = parser.Lexer
// 	var ident = _lexer.PeekToken

// 	if ident.Kind != lexer.Ident {
// 		return nil, ErrNotFound
// 	}

// 	_lexer.Lex()

// 	return &ExprIdent{
// 		Lexeme:     *ident.Lexeme,
// 		Uniquifier: 0,
// 	}, nil
// }

func (parser *Parser) parseExprAbstraction(scope Scope) (Expr, error) {
	var _lexer = parser.Lexer

	if _lexer.PeekToken.Kind != lexer.Slash {
		return NilExpr(), ErrNotFound
	}

	_lexer.Lex()

	var idents = []*ExprIdent{}

	for {
		var identToken, ok = _lexer.LexIdent()
		if !ok {
			break
		}
		var ident = scope.CreateIdent(*identToken.Lexeme)
		for _, val := range idents {
			if val.Lexeme == ident.Lexeme {
				fmt.Fprintf(os.Stderr, "[Error] Ident `%s` abstracted more than once at the same time.\n", ident.Lexeme)
				return NilExpr(), ErrSyntaxError
			}
		}

		idents = append(idents, &ident)
	}

	if len(idents) == 0 {
		fmt.Fprintln(os.Stderr, "[Error] No identifiers found after slash")
		return NilExpr(), ErrSyntaxError
	}
	if _lexer.PeekToken.Kind != lexer.Dot {
		fmt.Fprintf(os.Stderr, "[Error] Expected a `.` but got token kind: `%s`\n", _lexer.PeekToken.Kind)
		return NilExpr(), ErrSyntaxError
	}
	_lexer.Lex()

	var abstractionOver, err = parser.parseExpr(scope)
	if err == ErrNotFound {
		fmt.Fprintf(os.Stderr, "[Error] Expected an expression but after abstracted identifiers but got `%s`", _lexer.PeekToken.Kind)
		return NilExpr(), ErrSyntaxError
	} else if err != nil {
		return NilExpr(), ErrSyntaxError
	}

	var exprAbstraction = NewExpr(ExprAbstraction{
		Of:   idents,
		From: abstractionOver,
	})
	return exprAbstraction, nil

}

func (parser *Parser) parseAtomOrExprAbstraction(scope Scope) (Expr, error) {
	var atom, err = parser.parseAtom(scope)
	if err == nil {
		return atom, nil
	}
	if err != ErrNotFound {
		return NilExpr(), err
	}

	var abstraction Expr
	abstraction, err = parser.parseExprAbstraction(scope)
	if err == nil {
		return abstraction, nil
	}
	return NilExpr(), err

}

func (parser *Parser) parseExprApplication(scope Scope) (Expr, error) {
	var ofExpr, err = parser.parseAtom(scope)
	if err != nil {
		return NilExpr(), err
	}

	var toExpr Expr

	// toExpr, err = parser.parseAtom(scope)
	toExpr, err = parser.parseAtomOrExprAbstraction(scope)
	if err == ErrNotFound {
		return ofExpr, ErrParsedSomethingElse
	} else if err != nil {
		return NilExpr(), err
	}

	var exprApp = NewExpr(ExprApplication{
		Of: ofExpr,
		To: toExpr,
	})

	for {
		ofExpr = exprApp
		// toExpr, err = parser.parseAtom(scope)
		toExpr, err = parser.parseAtomOrExprAbstraction(scope)
		if err != nil {
			break
		}
		exprApp = NewExpr(ExprApplication{
			Of: ofExpr,
			To: toExpr,
		})
	}
	return exprApp, nil
}

func (parser *Parser) parseAtom(scope Scope) (Expr, error) {
	var _lexer = parser.Lexer
	var identToken, ok = _lexer.LexIdent()
	if ok {
		var ident = scope.GetIdent(*identToken.Lexeme)
		return NewExpr(ident), nil
	}

	if _lexer.PeekToken.Kind == lexer.LBrace {
		_lexer.Lex()
	} else {
		return NilExpr(), ErrNotFound
	}

	var atom, err = parser.parseExpr(scope)
	if err == ErrNotFound {
		fmt.Fprintf(os.Stderr, "[Error] Expected an expression after `(` but got: `%s`\n", _lexer.PeekToken.Kind)
		return NilExpr(), err
	} else if err != nil {
		return NilExpr(), err
	}

	if _lexer.PeekToken.Kind == lexer.RBrace {
		_lexer.Lex()
	} else {
		fmt.Fprintf(os.Stderr, "[Error] Expected `)` but got: `%s`\n", _lexer.PeekToken.Kind)
		return NilExpr(), ErrSyntaxError
	}

	return atom, nil
}

func (parser *Parser) parseExpr(scope Scope) (Expr, error) {
	var abs, err = parser.parseExprAbstraction(scope)
	if err == nil {
		return abs, nil
	} else if err != ErrNotFound {
		return abs, err
	}

	var app Expr
	app, err = parser.parseExprApplication(scope)
	if err == nil || err == ErrParsedSomethingElse {
		return app, nil
	} else {
		return app, err
	}
}

func (parser *Parser) Parse() (Expr, error) {
	var tokenKind = parser.Lexer.PeekToken.Kind
	if tokenKind == lexer.EndOfFile {
		return NilExpr(), ErrEOF
	} else if tokenKind == lexer.NewLine {
		for tokenKind == lexer.NewLine {
			parser.Lexer.Lex()
			tokenKind = parser.Lexer.PeekToken.Kind
		}
	}

	var scope = NewScope()
	var expr, err = parser.parseExpr(scope)
	if err != nil {
		return NilExpr(), err
	}

	return expr, nil
}
