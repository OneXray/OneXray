package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

const (
	apiVersion = "v1"
	cliVersion = "0.1.0"

	authScheme = "Bearer"

	healthPath   = "/v1/health"
	statusPath   = "/v1/status"
	importPath   = "/v1/import"
	vpnStartPath = "/v1/vpn/start"
	vpnStopPath  = "/v1/vpn/stop"

	sessionFileName = "automation-session.json"

	codeAppNotRunning   = "app_not_running"
	codeAPIUnavailable  = "api_unavailable"
	codeUnauthorized    = "unauthorized"
	codeInvalidResponse = "invalid_response"
	codeInvalidRequest  = "invalid_request"
	codeInternalError   = "internal_error"
	codeNotImplemented  = "not_implemented"
)

type globalOptions struct {
	json    bool
	api     string
	token   string
	session string
	version bool
	help    bool
}

type automationError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Detail  string `json:"detail,omitempty"`
}

func (e automationError) Error() string {
	return e.Code + ": " + e.Message
}

type envelope struct {
	OK      bool           `json:"ok"`
	Data    map[string]any `json:"data,omitempty"`
	Code    string         `json:"code,omitempty"`
	Message string         `json:"message,omitempty"`
}

type session struct {
	APIVersion string `json:"apiVersion"`
	Host       string `json:"host"`
	Port       int    `json:"port"`
	Token      string `json:"token"`
	PID        int    `json:"pid"`
	AppVersion string `json:"appVersion"`
	CreatedAt  string `json:"createdAt"`
}

func (s session) baseURL() string {
	return fmt.Sprintf("http://%s:%d", s.Host, s.Port)
}

type sessionDebug struct {
	Candidates   []string `json:"candidates"`
	SelectedPath string   `json:"selectedPath,omitempty"`
	Exists       bool     `json:"exists"`
	Session      *session `json:"session,omitempty"`
}

type client struct {
	baseURL string
	token   string
	http    *http.Client
}

func main() {
	opts, args, err := parseGlobal(os.Args[1:])
	if err != nil {
		printError(false, automationError{Code: codeInvalidRequest, Message: err.Error()})
		os.Exit(64)
	}

	if opts.version {
		printResult(opts.json, map[string]any{"cliVersion": cliVersion}, fmt.Sprintf("onexray %s", cliVersion))
		return
	}
	if opts.help || len(args) == 0 {
		fmt.Println(usage())
		return
	}

	if err := run(opts, args); err != nil {
		printError(opts.json, toAutomationError(err))
		os.Exit(1)
	}
}

func run(opts globalOptions, args []string) error {
	switch args[0] {
	case "health":
		c, err := discoverClient(opts)
		if err != nil {
			return err
		}
		data, err := c.get(healthPath)
		if err != nil {
			return err
		}
		printResult(opts.json, data, fmt.Sprintf("OneXray is running. app=%v api=%v", data["appVersion"], data["apiVersion"]))
	case "status":
		c, err := discoverClient(opts)
		if err != nil {
			return err
		}
		data, err := c.get(statusPath)
		if err != nil {
			return err
		}
		printResult(opts.json, data, statusText(data))
	case "debug":
		return runDebug(opts, args[1:])
	case "import":
		return runImport(opts, args[1:])
	case "vpn":
		return runVPN(opts, args[1:])
	default:
		return automationError{Code: codeNotImplemented, Message: "Unsupported command: " + args[0]}
	}
	return nil
}

func runImport(opts globalOptions, args []string) error {
	fs := newFlagSet("import")
	filePath := fs.String("file", "", "Import text file path, or '-' to read stdin.")
	text := fs.String("text", "", "Import text.")
	if err := fs.Parse(args); err != nil {
		return automationError{Code: codeInvalidRequest, Message: err.Error()}
	}

	importText, err := importTextFromFlags(*filePath, *text, "import")
	if err != nil {
		return err
	}

	c, err := discoverClient(opts)
	if err != nil {
		return err
	}
	data, err := c.post(importPath, map[string]any{"text": importText})
	if err != nil {
		return err
	}
	printResult(opts.json, data, importSummary(data))
	return nil
}

func importSummary(data map[string]any) string {
	source := fmt.Sprint(data["source"])
	imported := fmt.Sprint(data["imported"])
	switch source {
	case "oneXrayShare":
		return fmt.Sprintf("Imported OneXray share content. imported=%s", imported)
	case "httpsSubscription":
		return "Imported subscription."
	case "xrayShare":
		return fmt.Sprintf("Imported Xray share link(s). imported=%s", imported)
	default:
		return fmt.Sprintf("Imported content. imported=%s", imported)
	}
}

func runDebug(opts globalOptions, args []string) error {
	if len(args) == 0 || args[0] != "session" {
		return automationError{Code: codeInvalidRequest, Message: "Usage: onexray debug session"}
	}
	debug := debugSession(opts.session)
	text := "No automation session found."
	if debug.Exists {
		if debug.Session == nil {
			text = "Automation session exists but cannot be parsed: " + debug.SelectedPath
		} else {
			text = fmt.Sprintf("Automation session: %s\nAPI: %s\nPID: %d", debug.SelectedPath, debug.Session.baseURL(), debug.Session.PID)
		}
	}
	data := map[string]any{
		"candidates": debug.Candidates,
		"exists":     debug.Exists,
	}
	if debug.SelectedPath != "" {
		data["selectedPath"] = debug.SelectedPath
	}
	if debug.Session != nil {
		data["session"] = debug.Session
	}
	printResult(opts.json, data, text)
	return nil
}

func importTextFromFlags(filePath string, text string, command string) (string, error) {
	hasFile := strings.TrimSpace(filePath) != ""
	hasText := strings.TrimSpace(text) != ""
	if hasFile == hasText {
		return "", automationError{Code: codeInvalidRequest, Message: command + " requires exactly one of --file or --text."}
	}

	importText := strings.TrimSpace(text)
	if hasFile {
		data, err := readImportFile(strings.TrimSpace(filePath))
		if err != nil {
			return "", automationError{Code: codeInvalidRequest, Message: err.Error()}
		}
		importText = strings.TrimSpace(data)
	}
	if importText == "" {
		return "", automationError{Code: codeInvalidRequest, Message: command + " content is empty."}
	}
	return importText, nil
}

func readImportFile(path string) (string, error) {
	if path == "-" {
		data, err := io.ReadAll(os.Stdin)
		if err != nil {
			return "", fmt.Errorf("cannot read stdin: %w", err)
		}
		return string(data), nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return "", fmt.Errorf("cannot read file %q: %w", path, err)
	}
	return string(data), nil
}

func runVPN(opts globalOptions, args []string) error {
	if len(args) == 0 {
		return automationError{Code: codeInvalidRequest, Message: "Usage: onexray vpn <start|stop>"}
	}
	switch args[0] {
	case "start":
		fs := newFlagSet("vpn start")
		idText := fs.String("id", "", "Config id to start.")
		if err := fs.Parse(args[1:]); err != nil {
			return automationError{Code: codeInvalidRequest, Message: err.Error()}
		}
		body := map[string]any{}
		if strings.TrimSpace(*idText) != "" {
			id, err := strconv.Atoi(strings.TrimSpace(*idText))
			if err != nil {
				return automationError{Code: codeInvalidRequest, Message: "vpn start --id must be an integer."}
			}
			body["configId"] = id
		}
		c, err := discoverClient(opts)
		if err != nil {
			return err
		}
		data, err := c.post(vpnStartPath, body)
		if err != nil {
			return err
		}
		printResult(opts.json, data, "VPN start requested.")
	case "stop":
		c, err := discoverClient(opts)
		if err != nil {
			return err
		}
		data, err := c.post(vpnStopPath, map[string]any{})
		if err != nil {
			return err
		}
		printResult(opts.json, data, "VPN stop requested.")
	default:
		return automationError{Code: codeInvalidRequest, Message: "Unsupported vpn command: " + args[0]}
	}
	return nil
}

func newFlagSet(name string) *flag.FlagSet {
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	return fs
}

func parseGlobal(args []string) (globalOptions, []string, error) {
	opts := globalOptions{}
	remaining := make([]string, 0, len(args))
	for i := 0; i < len(args); i++ {
		arg := args[i]
		switch {
		case arg == "--json":
			opts.json = true
		case arg == "--version" || arg == "-v":
			opts.version = true
		case arg == "--help" || arg == "-h":
			opts.help = true
		case arg == "--api" || arg == "--token" || arg == "--session":
			if i+1 >= len(args) {
				return opts, remaining, fmt.Errorf("%s requires a value", arg)
			}
			i++
			setGlobalOption(&opts, strings.TrimPrefix(arg, "--"), args[i])
		case strings.HasPrefix(arg, "--api="):
			opts.api = strings.TrimPrefix(arg, "--api=")
		case strings.HasPrefix(arg, "--token="):
			opts.token = strings.TrimPrefix(arg, "--token=")
		case strings.HasPrefix(arg, "--session="):
			opts.session = strings.TrimPrefix(arg, "--session=")
		default:
			remaining = append(remaining, arg)
		}
	}
	return opts, remaining, nil
}

func setGlobalOption(opts *globalOptions, name string, value string) {
	switch name {
	case "api":
		opts.api = value
	case "token":
		opts.token = value
	case "session":
		opts.session = value
	}
}

func discoverClient(opts globalOptions) (*client, error) {
	if strings.TrimSpace(opts.api) != "" {
		return &client{
			baseURL: strings.TrimRight(strings.TrimSpace(opts.api), "/"),
			token:   opts.token,
			http:    &http.Client{Timeout: 10 * time.Second},
		}, nil
	}
	s, err := locateSession(opts.session)
	if err != nil {
		return nil, err
	}
	token := s.Token
	if opts.token != "" {
		token = opts.token
	}
	return &client{
		baseURL: strings.TrimRight(s.baseURL(), "/"),
		token:   token,
		http:    &http.Client{Timeout: 10 * time.Second},
	}, nil
}

func (c *client) get(path string) (map[string]any, error) {
	return c.do(http.MethodGet, path, nil)
}

func (c *client) post(path string, body map[string]any) (map[string]any, error) {
	return c.do(http.MethodPost, path, body)
}

func (c *client) do(method string, path string, body map[string]any) (map[string]any, error) {
	var reader io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			return nil, automationError{Code: codeInvalidRequest, Message: err.Error()}
		}
		reader = bytes.NewReader(data)
	}
	req, err := http.NewRequest(method, c.baseURL+path, reader)
	if err != nil {
		return nil, automationError{Code: codeInvalidRequest, Message: err.Error()}
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.token != "" {
		req.Header.Set("Authorization", authScheme+" "+c.token)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return nil, automationError{Code: codeAppNotRunning, Message: "OneXray app is not running or no automation session was found."}
		}
		if isConnectionError(err) {
			return nil, automationError{Code: codeAPIUnavailable, Message: "Cannot connect to the OneXray automation API.", Detail: err.Error()}
		}
		return nil, automationError{Code: codeAPIUnavailable, Message: "Automation API request failed.", Detail: err.Error()}
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, automationError{Code: codeInvalidResponse, Message: "Cannot read automation API response.", Detail: err.Error()}
	}
	if resp.StatusCode == http.StatusUnauthorized {
		return nil, automationError{Code: codeUnauthorized, Message: "The automation token is invalid."}
	}

	var env envelope
	if err := json.Unmarshal(data, &env); err != nil {
		return nil, automationError{Code: codeInvalidResponse, Message: "Automation API returned invalid JSON.", Detail: err.Error()}
	}
	if !env.OK {
		code := env.Code
		if code == "" {
			code = codeInternalError
		}
		message := env.Message
		if message == "" {
			message = "Automation API request failed."
		}
		return nil, automationError{Code: code, Message: message}
	}
	if env.Data == nil {
		return map[string]any{}, nil
	}
	return env.Data, nil
}

func isConnectionError(err error) bool {
	var netErr net.Error
	return errors.As(err, &netErr) || strings.Contains(err.Error(), "connection refused")
}

func locateSession(explicit string) (*session, error) {
	for _, path := range sessionCandidates(explicit) {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		var s session
		if err := json.Unmarshal(data, &s); err != nil {
			continue
		}
		return &s, nil
	}
	return nil, automationError{Code: codeAppNotRunning, Message: "OneXray app is not running or no automation session was found."}
}

func debugSession(explicit string) sessionDebug {
	candidates := sessionCandidates(explicit)
	for _, path := range candidates {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		var s session
		if err := json.Unmarshal(data, &s); err != nil {
			return sessionDebug{Candidates: candidates, SelectedPath: path, Exists: true}
		}
		return sessionDebug{Candidates: candidates, SelectedPath: path, Exists: true, Session: &s}
	}
	return sessionDebug{Candidates: candidates, Exists: false}
}

func sessionCandidates(explicit string) []string {
	paths := []string{}
	add := func(path string) {
		if path == "" {
			return
		}
		for _, existing := range paths {
			if existing == path {
				return
			}
		}
		paths = append(paths, path)
	}
	add(explicit)
	add(os.Getenv("ONEXRAY_SESSION"))

	switch runtime.GOOS {
	case "darwin":
		home := os.Getenv("HOME")
		if home != "" {
			add(filepath.Join(home, "Library", "Group Containers", "2CKAULFA9J.net.yuandev.onexray", "run", sessionFileName))
			add(filepath.Join(home, "Library", "Group Containers", "group.net.yuandev.onexray.se", "run", sessionFileName))
			add(filepath.Join(home, "Library", "Application Support", "OneXray", "run", sessionFileName))
		}
	case "windows":
		if appData := os.Getenv("APPDATA"); appData != "" {
			add(filepath.Join(appData, "OneXray", "run", sessionFileName))
		}
	case "linux":
		if runtimeDir := os.Getenv("XDG_RUNTIME_DIR"); runtimeDir != "" {
			add(filepath.Join(runtimeDir, "onexray", sessionFileName))
		}
		if configHome := os.Getenv("XDG_CONFIG_HOME"); configHome != "" {
			add(filepath.Join(configHome, "onexray", "run", sessionFileName))
		} else {
			home := os.Getenv("HOME")
			if home != "" {
				add(filepath.Join(home, ".config", "onexray", "run", sessionFileName))
				add(filepath.Join(home, ".local", "share", "onexray", "run", sessionFileName))
			}
		}
	}
	return paths
}

func statusText(data map[string]any) string {
	vpn, ok := data["vpn"].(map[string]any)
	if !ok {
		return "OneXray status is available."
	}
	state := "stopped"
	if running, _ := vpn["running"].(bool); running {
		state = "running"
	}
	if name := fmt.Sprint(vpn["runningName"]); name != "" && name != "<nil>" {
		return fmt.Sprintf("VPN %s. runningId=%v name=%s", state, vpn["runningId"], name)
	}
	return fmt.Sprintf("VPN %s. runningId=%v", state, vpn["runningId"])
}

func printResult(jsonOutput bool, data map[string]any, text string) {
	if jsonOutput {
		_ = json.NewEncoder(os.Stdout).Encode(envelope{OK: true, Data: data})
		return
	}
	fmt.Println(text)
}

func printError(jsonOutput bool, err automationError) {
	if jsonOutput {
		_ = json.NewEncoder(os.Stdout).Encode(envelope{OK: false, Code: err.Code, Message: err.Message})
		return
	}
	fmt.Fprintf(os.Stderr, "%s: %s\n", err.Code, err.Message)
}

func toAutomationError(err error) automationError {
	var autoErr automationError
	if errors.As(err, &autoErr) {
		return autoErr
	}
	return automationError{Code: codeInternalError, Message: err.Error()}
}

func usage() string {
	return strings.TrimSpace(`Usage: onexray [options] <command>

Options:
  --json                Print machine-readable JSON.
  --api <url>           Override local automation API base URL.
  --token <token>       Override local automation API token.
  --session <path>      Override automation session file path.
  -v, --version         Print CLI version.
  -h, --help            Print this help.

Commands:
  health
  status
  import (--file <path>|--text <text>)
  debug session
  vpn start [--id <configId>]
  vpn stop`)
}
