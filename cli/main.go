package main

import (
	"fmt"
	"os"

	"github.com/OneXray/OneXray/cli/internal/cli"
	"golang.org/x/term"
)

var version = "dev"

func main() {
	app := cli.App{
		In: os.Stdin, Out: os.Stdout, Err: os.Stderr, Version: version,
		ReadToken: func() (string, error) {
			if !term.IsTerminal(int(os.Stdin.Fd())) {
				return "", fmt.Errorf("auth login requires an interactive terminal")
			}
			fmt.Fprint(os.Stderr, "Token (hidden): ")
			value, err := term.ReadPassword(int(os.Stdin.Fd()))
			fmt.Fprintln(os.Stderr)
			return string(value), err
		},
	}
	os.Exit(app.Run(os.Args[1:]))
}
