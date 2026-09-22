package cli

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

const DefaultEndpoint = "http://127.0.0.1:18587"
const maxBody = 16 << 20

type Diagnostic struct {
	Code    string            `json:"code"`
	Message string            `json:"message"`
	Path    []json.RawMessage `json:"path,omitempty"`
	Offset  *int              `json:"offset,omitempty"`
	Line    *int              `json:"line,omitempty"`
	Column  *int              `json:"column,omitempty"`
}

type Result struct {
	APIVersion       int          `json:"apiVersion"`
	Status           string       `json:"status"`
	Stage            string       `json:"stage"`
	Diagnostics      []Diagnostic `json:"diagnostics"`
	ValidationConfig string       `json:"validationConfig,omitempty"`
	CompiledConfig   string       `json:"compiledConfig,omitempty"`
	Limitations      []string     `json:"limitations,omitempty"`
}

type Info struct {
	APIVersion     int      `json:"apiVersion"`
	AppVersion     string   `json:"appVersion"`
	CoreVersion    string   `json:"coreVersion"`
	Platform       string   `json:"platform"`
	SupportedKinds []string `json:"supportedKinds"`
}

type configRequest struct {
	Kind      string          `json:"kind"`
	Text      string          `json:"text"`
	Name      string          `json:"name,omitempty"`
	Outbounds json.RawMessage `json:"outbounds,omitempty"`
	Options   json.RawMessage `json:"options,omitempty"`
}

type clientFailure struct {
	code    int
	message string
}

func (e *clientFailure) Error() string { return e.message }

func normalizeEndpoint(value string) (string, error) {
	u, err := url.Parse(value)
	if err != nil || u.Scheme != "http" || u.Hostname() != "127.0.0.1" || u.User != nil ||
		(u.Path != "" && u.Path != "/") || u.RawQuery != "" || u.Fragment != "" || u.ForceQuery {
		return "", errors.New("endpoint must be http://127.0.0.1:<port> with no path or credentials")
	}
	port, err := strconv.Atoi(u.Port())
	if err != nil || port < 1 || port > 65535 || u.Host != "127.0.0.1:"+u.Port() {
		return "", errors.New("endpoint requires a port from 1 to 65535")
	}
	return "http://127.0.0.1:" + strconv.Itoa(port), nil
}

func validToken(value string) bool {
	if len(value) < 32 || len(value) > 512 {
		return false
	}
	for _, ch := range value {
		if !(ch >= 'a' && ch <= 'z' || ch >= 'A' && ch <= 'Z' || ch >= '0' && ch <= '9' || strings.ContainsRune("-._~+/=", ch)) {
			return false
		}
	}
	return true
}

func request(credentials credentials, method, path string, input any) ([]byte, int, error) {
	endpoint, err := normalizeEndpoint(credentials.Endpoint)
	if err != nil {
		return nil, 0, &clientFailure{ExitUsage, err.Error()}
	}
	if !validToken(credentials.Token) {
		return nil, 0, &clientFailure{ExitAuth, "Stored token is invalid; run onexray-cli auth login."}
	}
	var body []byte
	if input != nil {
		body, err = json.Marshal(input)
		if err != nil {
			return nil, 0, &clientFailure{ExitUsage, "Cannot encode the request."}
		}
		if len(body) > maxBody {
			return nil, 0, &clientFailure{ExitUsage, "Request exceeds the 16 MiB limit."}
		}
	}
	req, err := http.NewRequest(method, endpoint+path, bytes.NewReader(body))
	if err != nil {
		return nil, 0, err
	}
	req.Header.Set("Authorization", "Bearer "+credentials.Token)
	req.Header.Set("Accept", "application/json")
	if input != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	transport := &http.Transport{Proxy: nil, DialContext: (&net.Dialer{Timeout: 5 * time.Second}).DialContext,
		ResponseHeaderTimeout: 120 * time.Second, DisableKeepAlives: true}
	defer transport.CloseIdleConnections()
	httpClient := &http.Client{Transport: transport, Timeout: 125 * time.Second,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error { return http.ErrUseLastResponse }}
	response, err := httpClient.Do(req)
	if err != nil {
		return nil, 0, &clientFailure{ExitUnavailable, "Cannot reach OneXray. Keep the App running with Local API enabled. A timeout does not cancel an in-progress App operation."}
	}
	defer response.Body.Close()
	if response.StatusCode == http.StatusUnauthorized || response.StatusCode == http.StatusForbidden {
		return nil, response.StatusCode, &clientFailure{ExitAuth, "Authentication rejected. Copy the current token from OneXray and run onexray-cli auth login."}
	}
	if response.StatusCode >= 300 && response.StatusCode < 400 {
		return nil, response.StatusCode, &clientFailure{ExitProtocol, "Redirects are not allowed."}
	}
	data, err := io.ReadAll(io.LimitReader(response.Body, maxBody+1))
	if err != nil || len(data) > maxBody {
		return nil, response.StatusCode, &clientFailure{ExitProtocol, "Incomplete or oversized API response."}
	}
	return data, response.StatusCode, nil
}

func readInfo(credentials credentials) (Info, error) {
	data, status, err := request(credentials, http.MethodGet, "/api/v1/info", nil)
	if err != nil {
		return Info{}, err
	}
	if status != http.StatusOK {
		return Info{}, &clientFailure{ExitNotRun, fmt.Sprintf("App is not ready (HTTP %d).", status)}
	}
	var info Info
	if json.Unmarshal(data, &info) != nil || info.APIVersion != 1 || info.AppVersion == "" || info.Platform == "" || len(info.SupportedKinds) == 0 {
		return Info{}, &clientFailure{ExitProtocol, "Unsupported or malformed API info response."}
	}
	return info, nil
}

func configOperation(credentials credentials, operation string, input configRequest) (Result, int, error) {
	data, status, err := request(credentials, http.MethodPost, "/api/v1/config/"+operation, input)
	if err != nil {
		return Result{}, 0, err
	}
	var result Result
	if json.Unmarshal(data, &result) != nil || result.APIVersion != 1 || result.Diagnostics == nil ||
		(result.Stage != "input" && result.Stage != "compile" && result.Stage != "kernel") ||
		(result.Status != "passed" && result.Status != "failed" && result.Status != "notRun") ||
		(status != http.StatusOK && result.Status != "notRun") {
		return Result{}, 0, &clientFailure{ExitProtocol, "Unsupported or malformed API result."}
	}
	code := ExitOK
	if result.Status == "failed" {
		code = ExitValidation
	}
	if result.Status == "notRun" {
		code = ExitNotRun
	}
	if code == ExitOK {
		validSuccess := operation == "compile" && result.Stage == "compile" && result.CompiledConfig != "" ||
			operation == "validate" && result.Stage == "kernel" && result.ValidationConfig != ""
		if !validSuccess {
			return Result{}, 0, &clientFailure{ExitProtocol, "App result does not confirm the requested operation's stage and configuration."}
		}
	}
	return result, code, nil
}
