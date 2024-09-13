package parser

import (
	"errors"
	"fmt"
	"os"

	"github.com/abc401/lcalc/lexer"
	"github.com/abc401/lcalc/parser/expr"
)

var (
	ErrNotFound            = errors.New("Not Found")
	ErrSyntaxError         = errors.New("Syntax Error")
	ErrParsedSomethingElse = errors.New("Parsed something other than was asked")
	ErrEOF                 = errors.New("End of file")
)

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

// func (parser *Parser) parseexpr.Ident() (*ExprIdent, error) {
// 	var _lexer = parser.Lexer
// 	var ident = _lexer.PeekToken

// 	if ident.Kind != lexer.Ident {
// 		return nil, ErrNotFound
// 	}

// 	_lexer.Lex()

// 	return &expr.Ident{
// 		Lexeme:     *ident.Lexeme,
// 		Uniquifier: 0,
// 	}, nil
// }

func (parser *Parser) parseExprAbstraction(scope Scope) (expr.Expr, error) {
	var _lexer = parser.Lexer

	if _lexer.PeekToken.Kind != lexer.Slash {
		return nil, ErrNotFound
	}

	_lexer.Lex()

	var idents = []expr.Ident{}

	for {
		var identToken, ok = _lexer.LexIdent()
		if !ok {
			break
		}
		var ident = scope.CreateIdent(*identToken.Lexeme)
		for _, val := range idents {
			if val.Lexeme == ident.Lexeme {
				fmt.Fprintf(os.Stderr, "[Error] Ident `%s` abstracted more than once at the same time.\n", ident.Lexeme)
				return nil, ErrSyntaxError
			}
		}

		idents = append(idents, ident)
	}

	if len(idents) == 0 {
		fmt.Fprintln(os.Stderr, "[Error] No identifiers found after slash")
		return nil, ErrSyntaxError
	}
	if _lexer.PeekToken.Kind != lexer.Dot {
		fmt.Fprintf(os.Stderr, "[Error] Expected a `.` but got token kind: `%s`\n", _lexer.PeekToken.Kind)
		return nil, ErrSyntaxError
	}
	_lexer.Lex()

	var abstractionOver, err = parser.parseExpr(scope)
	if err == ErrNotFound {
		fmt.Fprintf(os.Stderr, "[Error] Expected an expression but after abstracted identifiers but got `%s`", _lexer.PeekToken.Kind)
		return nil, ErrSyntaxError
	} else if err != nil {
		return nil, ErrSyntaxError
	}

	return &expr.Abstraction{
		Of:   idents,
		From: abstractionOver,
	}, nil

}

func (parser *Parser) parseAtomOrExprAbstraction(scope Scope) (expr.Expr, error) {
	var atom, err = parser.parseAtom(scope)
	if err == nil {
		return atom, nil
	}
	if err != ErrNotFound {
		return nil, err
	}

	var abstraction expr.Expr
	abstraction, err = parser.parseExprAbstraction(scope)
	if err == nil {
		return abstraction, nil
	}
	return nil, err

}

func (parser *Parser) parseExprApplication(scope Scope) (expr.Expr, error) {
	var ofExpr, err = parser.parseAtom(scope)
	if err != nil {
		return nil, err
	}

	var toExpr expr.Expr

	// toExpr, err = parser.parseAtom(scope)
	toExpr, err = parser.parseAtomOrExprAbstraction(scope)
	if err == ErrNotFound {
		return ofExpr, ErrParsedSomethingElse
	} else if err != nil {
		return nil, err
	}

	var exprApp = &expr.Application{
		Of: ofExpr,
		To: toExpr,
	}

	for {
		ofExpr = exprApp
		// toExpr, err = parser.parseAtom(scope)
		toExpr, err = parser.parseAtomOrExprAbstraction(scope)
		if err != nil {
			break
		}
		exprApp = &expr.Application{
			Of: ofExpr,
			To: toExpr,
		}
	}
	return exprApp, nil
}

func (parser *Parser) parseAtom(scope Scope) (expr.Expr, error) {
	var _lexer = parser.Lexer
	var identToken, ok = _lexer.LexIdent()
	if ok {
		var ident = scope.GetIdent(*identToken.Lexeme)
		return &ident, nil
	}

	if _lexer.PeekToken.Kind == lexer.LBrace {
		_lexer.Lex()
	} else {
		return nil, ErrNotFound
	}

	var atom, err = parser.parseExpr(scope)
	if err == ErrNotFound {
		fmt.Fprintf(os.Stderr, "[Error] Expected an expression after `(` but got: `%s`\n", _lexer.PeekToken.Kind)
		return nil, err
	} else if err != nil {
		return nil, err
	}

	if _lexer.PeekToken.Kind == lexer.RBrace {
		_lexer.Lex()
	} else {
		fmt.Fprintf(os.Stderr, "[Error] Expected `)` but got: `%s`\n", _lexer.PeekToken.Kind)
		return nil, ErrSyntaxError
	}

	return atom, nil
}

func (parser *Parser) parseExpr(scope Scope) (expr.Expr, error) {
	var newScope = scope.CreateChildScope()
	var abs, err = parser.parseExprAbstraction(newScope)
	if err == nil {
		return abs, nil
	} else if err != ErrNotFound {
		return abs, err
	}

	var app expr.Expr
	app, err = parser.parseExprApplication(scope)
	if err == nil || err == ErrParsedSomethingElse {
		return app, nil
	} else {
		return app, err
	}
}

func (parser *Parser) Parse() (expr.Expr, error) {
	var tokenKind = parser.Lexer.PeekToken.Kind
	if tokenKind == lexer.EndOfFile {
		return nil, ErrEOF
	} else if tokenKind == lexer.NewLine {
		for tokenKind == lexer.NewLine {
			parser.Lexer.Lex()
			tokenKind = parser.Lexer.PeekToken.Kind
		}
	}

	var scope = NewScope()
	var expr, err = parser.parseExpr(scope)
	if err != nil {
		return nil, err
	}

	return expr, nil
}
