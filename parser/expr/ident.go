package expr

import "strconv"

type Uniquifier uint

type Ident struct {
	Lexeme     string
	Uniquifier Uniquifier
}

func (ident *Ident) DeepCopy() Expr {
	return &Ident{
		Lexeme:     ident.Lexeme,
		Uniquifier: ident.Uniquifier,
	}
}

func (ident *Ident) DumpToString() string {
	return ident.Lexeme + "_" + strconv.FormatUint(uint64(ident.Uniquifier), 10)
}

func (ident Ident) Equals(other Ident) bool {
	return ident.Lexeme == other.Lexeme && ident.Uniquifier == other.Uniquifier
}

func (ident *Ident) Replace(targetIdent Ident, with Expr) Expr {
	if ident.Equals(targetIdent) {
		return with.DeepCopy()
	}
	return ident.DeepCopy()
}
