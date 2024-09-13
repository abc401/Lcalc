package expr

type Expr interface {
	DeepCopy() Expr
	DumpToString() string
}
