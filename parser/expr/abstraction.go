package expr

type Abstraction struct {
	Of   []Ident
	From Expr
}

func (abs *Abstraction) DumpToString() string {
	var str = "\\"
	for i, ident := range abs.Of {
		if i == len(abs.Of)-1 {
			str += ident.DumpToString()
		} else {
			str += ident.DumpToString() + " "
		}
	}
	str += ". " + abs.From.DumpToString()
	return str
}

func (abs *Abstraction) DeepCopy() Expr {
	var OfDeepCopy = []Ident{}
	OfDeepCopy = append(OfDeepCopy, abs.Of...)

	return &Abstraction{
		Of:   OfDeepCopy,
		From: abs.From.DeepCopy(),
	}
}

func (abs *Abstraction) Replace(targetIdent Ident, with Expr) Expr {
	for _, ident := range abs.Of {
		if ident.Lexeme == targetIdent.Lexeme {
			return abs.DeepCopy()
		}
	}

	var newOf = []Ident{}
	newOf = append(newOf, abs.Of...)

	return &Abstraction{
		Of:   newOf,
		From: abs.From.Replace(targetIdent, with),
	}
}

func (abs *Abstraction) BetaReduce(param Expr) Expr {
	if len(abs.Of) == 1 {
		return abs.From.Replace(abs.Of[0], param)
	}

	var newOf = []Ident{}
	newOf = append(newOf, abs.Of[1:]...)
	return &Abstraction{
		Of:   newOf,
		From: abs.From.Replace(abs.Of[0], param),
	}
}

func (abs *Abstraction) Eval() Expr {
	var newOf = []Ident{}
	newOf = append(newOf, abs.Of...)
	return &Abstraction{
		Of:   newOf,
		From: abs.From.Eval(),
	}

}
