package expr

type Expr interface {
	DeepCopy() Expr
	DumpToString() string
	Replace(targetIdent Ident, with Expr) Expr
	Eval() Expr
}
