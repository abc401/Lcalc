package predicates

func IsSpace(ch rune) bool {
	return ch == ' ' || ch == '\t' || ch == '\r'
}
