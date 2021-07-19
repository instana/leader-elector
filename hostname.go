package main

import (
  "fmt"
  "os"
)

func main() {
  name, err := os.Hostname()
	if err != nil {
		panic(err)
	}

	fmt.Println(name)
}
