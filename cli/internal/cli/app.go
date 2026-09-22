package cli

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"unicode/utf8"
)

const (
	ExitOK          = 0
	ExitValidation  = 1
	ExitUsage       = 2
	ExitUnavailable = 3
	ExitAuth        = 4
	ExitProtocol    = 5
	ExitNotRun      = 6
)

type App struct {
	In              io.Reader
	Out             io.Writer
	Err             io.Writer
	Version         string
	ReadToken       func() (string, error)
	CredentialsPath string // Injected only by tests; the CLI uses the current-user config directory.
}

func (a App) Run(arguments []string) int {
	jsonOutput := false
	args := make([]string, 0, len(arguments))
	for _, argument := range arguments {
		if argument == "--json" {
			jsonOutput = true
		} else {
			args = append(args, argument)
		}
	}
	fail := func(code int, message string) int {
		if jsonOutput {
			a.printJSON(Result{1, "notRun", "input", []Diagnostic{{Code: errorCode(code), Message: message}}, "", "", nil})
		} else {
			fmt.Fprintln(a.Err, message)
		}
		return code
	}
	if len(args) == 0 || args[0] == "help" || args[0] == "--help" || args[0] == "-h" {
		fmt.Fprintln(a.Out, help)
		return ExitOK
	}
	if len(args) == 1 && (args[0] == "version" || args[0] == "--version") {
		if jsonOutput {
			a.printJSON(map[string]any{"version": a.Version, "apiVersion": 1})
		} else {
			fmt.Fprintln(a.Out, "onexray-cli "+a.Version)
		}
		return ExitOK
	}
	if a.CredentialsPath == "" {
		var err error
		a.CredentialsPath, err = credentialPath()
		if err != nil {
			return fail(ExitAuth, "Cannot locate the current user's configuration directory.")
		}
	}
	if len(args) >= 2 && args[0] == "auth" {
		return a.auth(args[1:], jsonOutput, fail)
	}
	if args[0] != "info" && !(len(args) >= 2 && args[0] == "config" && (args[1] == "validate" || args[1] == "compile")) {
		return fail(ExitUsage, "Unknown command. Run onexray-cli --help.")
	}
	if args[0] == "info" && len(args) != 1 {
		return fail(ExitUsage, "Usage: onexray-cli info [--json]")
	}
	var input configRequest
	var output string
	if args[0] == "config" {
		var err error
		input, output, err = a.parseConfig(args[1], args[2:])
		if errors.Is(err, flag.ErrHelp) {
			return ExitOK
		}
		if err != nil {
			return fail(ExitUsage, err.Error())
		}
	}
	credentials, err := loadCredentials(a.CredentialsPath)
	if err != nil {
		return fail(ExitAuth, "Cannot read credentials. Run onexray-cli auth login.")
	}
	if args[0] == "info" {
		info, err := readInfo(credentials)
		if err != nil {
			return reportClientError(err, fail)
		}
		if jsonOutput {
			a.printJSON(info)
		} else {
			fmt.Fprintf(a.Out, "OneXray %s (%s)\nXray-core %s\nAPI %d; kinds: %s\n", info.AppVersion, info.Platform, info.CoreVersion, info.APIVersion, strings.Join(info.SupportedKinds, ", "))
		}
		return ExitOK
	}
	result, code, err := configOperation(credentials, args[1], input)
	if err != nil {
		return reportClientError(err, fail)
	}
	if output != "" && code == ExitOK {
		if err := writeOutput(output, result.CompiledConfig); err != nil {
			return fail(ExitUsage, "Cannot create output file. Use a new path; existing files are never overwritten.")
		}
	}
	if jsonOutput {
		a.printJSON(result)
	} else {
		fmt.Fprintf(a.Out, "%s (%s)\n", result.Status, result.Stage)
		for _, diagnostic := range result.Diagnostics {
			location := ""
			if len(diagnostic.Path) > 0 {
				path, _ := json.Marshal(diagnostic.Path)
				location = string(path)
			}
			if diagnostic.Line != nil && diagnostic.Column != nil {
				location += fmt.Sprintf(" [%d:%d]", *diagnostic.Line, *diagnostic.Column)
			}
			fmt.Fprintf(a.Out, "%s %s: %s\n", diagnostic.Code, location, diagnostic.Message)
		}
		for _, limitation := range result.Limitations {
			fmt.Fprintln(a.Out, "Note: "+limitation)
		}
		if code == ExitOK && args[1] == "compile" && output == "" {
			fmt.Fprintln(a.Out, result.CompiledConfig)
		}
	}
	return code
}

func (a App) auth(args []string, jsonOutput bool, fail func(int, string) int) int {
	if args[0] == "logout" && len(args) == 1 {
		if err := removeCredentials(a.CredentialsPath); err != nil {
			return fail(ExitAuth, "Cannot remove local credentials.")
		}
		if jsonOutput {
			a.printJSON(map[string]string{"status": "loggedOut"})
		} else {
			fmt.Fprintln(a.Out, "Local credentials removed. The App token has not been reset.")
		}
		return ExitOK
	}
	if args[0] != "login" {
		return fail(ExitUsage, "Usage: onexray-cli auth login [--endpoint URL] | logout")
	}
	flags := flag.NewFlagSet("onexray-cli auth login", flag.ContinueOnError)
	flags.SetOutput(a.Err)
	endpoint := flags.String("endpoint", DefaultEndpoint, "App's local HTTP endpoint")
	if err := flags.Parse(args[1:]); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return ExitOK
		}
		return fail(ExitUsage, "Invalid auth login options.")
	}
	if flags.NArg() != 0 {
		return fail(ExitUsage, "Tokens must be entered at the hidden prompt, not in command arguments.")
	}
	address, err := normalizeEndpoint(*endpoint)
	if err != nil {
		return fail(ExitUsage, err.Error())
	}
	if a.ReadToken == nil {
		return fail(ExitAuth, "Interactive token entry is unavailable.")
	}
	token, err := a.ReadToken()
	if err != nil {
		return fail(ExitAuth, "Cannot read the token. Use an interactive terminal.")
	}
	token = strings.TrimSpace(token)
	if !validToken(token) {
		return fail(ExitAuth, "Invalid token. Copy the token from the App's Local API settings.")
	}
	value := credentials{Endpoint: address, Token: token}
	if _, err := readInfo(value); err != nil {
		return reportClientError(err, fail)
	}
	if err := saveCredentials(a.CredentialsPath, value); err != nil {
		return fail(ExitAuth, "Cannot securely save credentials.")
	}
	if jsonOutput {
		a.printJSON(map[string]string{"status": "authenticated", "endpoint": address})
	} else {
		fmt.Fprintln(a.Out, "Authenticated. Credentials saved for the current user.")
	}
	return ExitOK
}

func (a App) parseConfig(operation string, args []string) (configRequest, string, error) {
	flags := flag.NewFlagSet("onexray-cli config "+operation, flag.ContinueOnError)
	flags.SetOutput(a.Err)
	kind := flags.String("kind", "", "outbound, routing, advanced-routing, or raw")
	file := flags.String("file", "", "JSON file, or - for stdin")
	name := flags.String("name", "", "optional App configuration name")
	var outbounds, options, output string
	if operation == "compile" {
		flags.StringVar(&outbounds, "outbounds", "", "JSON array of explicit server outbounds")
		flags.StringVar(&options, "options", "", "JSON object of explicit compilation options")
		flags.StringVar(&output, "output", "", "write compiled JSON to a new file (never overwrite)")
	}
	if err := flags.Parse(args); err != nil {
		return configRequest{}, "", err
	}
	if flags.NArg() != 0 || *file == "" {
		return configRequest{}, "", errors.New("--kind and --file are required; use --file - for stdin")
	}
	switch *kind {
	case "outbound", "routing", "advanced-routing", "raw":
	default:
		return configRequest{}, "", errors.New("unsupported configuration kind")
	}
	text, err := a.readFile(*file)
	if err != nil {
		return configRequest{}, "", fmt.Errorf("cannot read configuration: %w", err)
	}
	if !utf8.Valid(text) {
		return configRequest{}, "", errors.New("configuration must use UTF-8 encoding")
	}
	input := configRequest{Kind: *kind, Text: string(text), Name: *name}
	if outbounds != "" {
		if outbounds == "-" {
			return input, "", errors.New("--outbounds requires a file path")
		}
		input.Outbounds, err = a.readFile(outbounds)
		if err != nil {
			return input, "", errors.New("cannot read outbounds file")
		}
		var rows []map[string]any
		if json.Unmarshal(input.Outbounds, &rows) != nil || rows == nil {
			return input, "", errors.New("outbounds must be a JSON array of objects")
		}
	}
	if options != "" {
		if options == "-" {
			return input, "", errors.New("--options requires a file path")
		}
		input.Options, err = a.readFile(options)
		if err != nil {
			return input, "", errors.New("cannot read options file")
		}
		var value map[string]any
		if json.Unmarshal(input.Options, &value) != nil || value == nil {
			return input, "", errors.New("options must be a JSON object")
		}
	}
	return input, output, nil
}

func (a App) readFile(path string) ([]byte, error) {
	if path == "-" {
		return readLimited(a.In, maxBody)
	}
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	return readLimited(file, maxBody)
}
func readLimited(reader io.Reader, limit int64) ([]byte, error) {
	data, err := io.ReadAll(io.LimitReader(reader, limit+1))
	if err == nil && int64(len(data)) > limit {
		err = errors.New("input exceeds size limit")
	}
	return data, err
}
func writeOutput(path, text string) error {
	file, err := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	saved := false
	defer func() {
		file.Close()
		if !saved {
			os.Remove(path)
		}
	}()
	if err = protectPath(path, false); err != nil {
		return err
	}
	if _, err = io.WriteString(file, text); err != nil {
		return err
	}
	err = file.Close()
	saved = err == nil
	return err
}
func (a App) printJSON(value any) {
	encoder := json.NewEncoder(a.Out)
	encoder.SetIndent("", "  ")
	_ = encoder.Encode(value)
}
func reportClientError(err error, fail func(int, string) int) int {
	var failure *clientFailure
	if errors.As(err, &failure) {
		return fail(failure.code, failure.message)
	}
	return fail(ExitProtocol, "Local API request failed.")
}
func errorCode(code int) string {
	switch code {
	case ExitUsage:
		return "cli.invalidInput"
	case ExitUnavailable:
		return "cli.unavailable"
	case ExitAuth:
		return "cli.authentication"
	case ExitNotRun:
		return "cli.notRun"
	default:
		return "cli.protocol"
	}
}

const help = `OneXray local configuration CLI

  onexray-cli auth login [--endpoint http://127.0.0.1:18587]
  onexray-cli auth logout
  onexray-cli info [--json]
  onexray-cli config validate --kind KIND --file PATH [--name NAME] [--json]
  onexray-cli config compile --kind KIND --file PATH [--name NAME]
      [--outbounds PATH] [--options PATH] [--output NEW_PATH] [--json]
  onexray-cli version

Kinds: outbound, routing, advanced-routing, raw. Use --file - to read stdin.
Enable Local API in the running desktop App, then log in once at the hidden
token prompt. Requests do not save configurations, download assets or start VPN.
--json writes machine-readable results. Compilation output may contain secrets.
Exit codes: 0 passed, 1 validation failed, 2 input/file error, 3 unavailable,
4 authentication, 5 incompatible/malformed protocol, 6 not run.`
