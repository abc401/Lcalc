package parser

type Scope struct {
	identUniquifiers map[string]Uniquifier
	parent           *Scope
}

func NewScope() Scope {
	return Scope{
		identUniquifiers: map[string]Uniquifier{},
		parent:           nil,
	}
}

func (scope *Scope) CreateChild() Scope {
	return Scope{
		identUniquifiers: map[string]Uniquifier{},
		parent:           scope,
	}
}

func (scope *Scope) GetUniquifier(lexeme string) Uniquifier {
	var uniquifier, ok = scope.identUniquifiers[lexeme]
	if ok {
		return uniquifier
	}
	if scope.parent == nil {
		return 0
	}
	return scope.parent.GetUniquifier(lexeme)
}

func (scope *Scope) CreateIdent(lexeme string) ExprIdent {
	var uniquifier = scope.GetUniquifier(lexeme)
	scope.identUniquifiers[lexeme] = uniquifier + 1
	return ExprIdent{
		Lexeme:     lexeme,
		Uniquifier: uniquifier + 1,
	}
}

func (scope *Scope) GetIdent(lexeme string) ExprIdent {
	var uniquifier = scope.GetUniquifier(lexeme)
	return ExprIdent{
		Lexeme:     lexeme,
		Uniquifier: uniquifier,
	}
}
