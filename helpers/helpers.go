package helpers

import (
	"encoding/json"
	"log"
)

func SPrettyPrint(val interface{}) string {
	json, err := json.MarshalIndent(val, "", "  ")
	if err != nil {
		log.Fatalf(err.Error())
	}
	return string(json)
}
