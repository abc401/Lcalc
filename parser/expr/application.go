package expr

type Application struct {
	Of Expr
	To Expr
}

func (app *Application) DeepCopy() Expr {
	return &Application{
		Of: app.Of.DeepCopy(),
		To: app.To.DeepCopy(),
	}
}

func (app *Application) DumpToString() string {
	var _, ok = app.Of.(*Abstraction)
	if ok {
		return "(" + app.Of.DumpToString() + ") " + app.To.DumpToString()
	}
	_, ok = app.To.(*Application)
	if ok {
		return app.Of.DumpToString() + " (" + app.To.DumpToString() + ")"
	}
	return app.Of.DumpToString() + " " + app.To.DumpToString()
}

func (app *Application) Replace(targetIdent Ident, with Expr) Expr {
	return &Application{
		Of: app.Of.Replace(targetIdent, with),
		To: app.To.Replace(targetIdent, with),
	}
}

func (app *Application) Eval() Expr {
	var abs, absOk = app.Of.(*Abstraction)
	if !absOk {
		return &Application{
			Of: app.Of.Eval(),
			To: app.To.Eval(),
		}
	}
	return abs.BetaReduce(app.To)
}
