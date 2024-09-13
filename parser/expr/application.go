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
