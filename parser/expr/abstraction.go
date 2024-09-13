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
