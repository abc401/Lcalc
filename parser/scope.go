package parser

import "github.com/abc401/lcalc/parser/expr"

type Scope struct {
	identUniquifiers map[string]expr.Uniquifier
	parent           *Scope
}

func NewScope() Scope {
	return Scope{
		identUniquifiers: map[string]expr.Uniquifier{},
		parent:           nil,
	}
}

func (scope *Scope) CreateChildScope() Scope {
	return Scope{
		identUniquifiers: map[string]expr.Uniquifier{},
		parent:           scope,
	}
}

func (scope *Scope) GetUniquifier(lexeme string) expr.Uniquifier {
	var uniquifier, ok = scope.identUniquifiers[lexeme]
	if ok {
		return uniquifier
	}
	if scope.parent == nil {
		return 0
	}
	return scope.parent.GetUniquifier(lexeme)
}

func (scope *Scope) CreateIdent(lexeme string) expr.Ident {

	var uniquifier = scope.GetUniquifier(lexeme)
	scope.identUniquifiers[lexeme] = uniquifier + 1
	return expr.Ident{
		Lexeme:     lexeme,
		Uniquifier: uniquifier + 1,
	}
}

func (scope *Scope) GetIdent(lexeme string) expr.Ident {
	var uniquifier = scope.GetUniquifier(lexeme)
	return expr.Ident{
		Lexeme:     lexeme,
		Uniquifier: uniquifier,
	}
}
