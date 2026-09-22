package cli

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

const testToken = "test-only-0123456789012345678901234567890123456789"

func fixture(t *testing.T) string {
	t.Helper()
	_, source, _, _ := runtime.Caller(0)
	root := filepath.Join(filepath.Dir(source), "..", "..", "..", "..", "references", "cli-tests")
	if err := os.MkdirAll(root, 0700); err != nil {
		t.Fatal(err)
	}
	directory, err := os.MkdirTemp(root, "test-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(directory) })
	return directory
}

func infoResponse(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(Info{1, "26.9.5", "26.9.9", "macos", []string{"outbound", "routing", "advanced-routing", "raw"}})
}

func newApp(t *testing.T) (App, *bytes.Buffer, *bytes.Buffer) {
	t.Helper()
	var output, stderr bytes.Buffer
	return App{In: strings.NewReader("{}"), Out: &output, Err: &stderr, Version: "test", CredentialsPath: filepath.Join(fixture(t), "auth", "credentials.json"), ReadToken: func() (string, error) { return testToken, nil }}, &output, &stderr
}

func TestCLIUsesDistinctCommandName(t *testing.T) {
	for _, test := range []struct {
		args []string
		want string
		exit int
	}{
		{[]string{"--help"}, "onexray-cli config validate", ExitOK},
		{[]string{"--version"}, "onexray-cli test\n", ExitOK},
		{[]string{"unknown"}, "Run onexray-cli --help.", ExitUsage},
		{[]string{"info", "unexpected"}, "Usage: onexray-cli info", ExitUsage},
		{[]string{"info"}, "Run onexray-cli auth login.", ExitAuth},
		{[]string{"auth", "unknown"}, "Usage: onexray-cli auth login", ExitUsage},
		{[]string{"auth", "login", "--help"}, "Usage of onexray-cli auth login", ExitOK},
		{[]string{"config", "validate", "--help"}, "Usage of onexray-cli config validate", ExitOK},
	} {
		t.Run(strings.Join(test.args, " "), func(t *testing.T) {
			app, output, stderr := newApp(t)
			if code := app.Run(test.args); code != test.exit {
				t.Fatalf("got exit %d, want %d", code, test.exit)
			}
			text := output.String() + stderr.String()
			if !strings.Contains(text, test.want) || strings.Contains(text, "onexray ") {
				t.Fatalf("unexpected command name: %s", text)
			}
		})
	}
}

func TestLoginOnlyPersistsAfterSuccessfulAuthentication(t *testing.T) {
	app, output, stderr := newApp(t)
	status := http.StatusUnauthorized
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/info" || r.Header.Get("Authorization") != "Bearer "+testToken {
			t.Error("invalid authentication request")
		}
		if status != 200 {
			w.WriteHeader(status)
			return
		}
		infoResponse(w)
	}))
	defer server.Close()
	if code := app.Run([]string{"auth", "login", "--endpoint", server.URL, "--json"}); code != ExitAuth {
		t.Fatalf("code %d", code)
	}
	if _, err := os.Stat(app.CredentialsPath); !os.IsNotExist(err) {
		t.Fatal("failed login stored credentials")
	}
	status = 200
	if code := app.Run([]string{"auth", "login", "--endpoint", server.URL}); code != ExitOK {
		t.Fatalf("code %d: %s", code, stderr)
	}
	value, err := loadCredentials(app.CredentialsPath)
	if err != nil || value.Token != testToken || value.Endpoint != server.URL {
		t.Fatalf("bad saved credentials: %v", err)
	}
	if strings.Contains(output.String()+stderr.String(), testToken) {
		t.Fatal("token leaked into output")
	}
	status = 401
	app.Run([]string{"auth", "login", "--endpoint", server.URL})
	if _, err = loadCredentials(app.CredentialsPath); err != nil {
		t.Fatal("failed relogin deleted credentials")
	}
	if code := app.Run([]string{"auth", "logout", "--json"}); code != 0 {
		t.Fatalf("logout %d", code)
	}
	if _, err = os.Stat(app.CredentialsPath); !os.IsNotExist(err) {
		t.Fatal("logout did not remove credentials")
	}
}

func TestValidatePreservesOriginalSourceAndMachineResult(t *testing.T) {
	app, output, stderr := newApp(t)
	source := "{\n  \"protocol\": \"vless\",\n  \"settings\": {}\n}\n"
	app.In = strings.NewReader(source)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/api/v1/config/validate" || r.Method != "POST" {
			t.Error("wrong operation")
		}
		var input configRequest
		if json.NewDecoder(r.Body).Decode(&input) != nil || input.Text != source || input.Kind != "outbound" || input.Name != "Test" {
			t.Error("source was changed")
		}
		line, column := 2, 3
		json.NewEncoder(w).Encode(Result{APIVersion: 1, Status: "failed", Stage: "kernel", Diagnostics: []Diagnostic{{Code: "kernel.invalid", Message: "invalid node", Line: &line, Column: &column}}})
	}))
	defer server.Close()
	if err := saveCredentials(app.CredentialsPath, credentials{server.URL, testToken}); err != nil {
		t.Fatal(err)
	}
	if code := app.Run([]string{"config", "validate", "--kind", "outbound", "--file", "-", "--name", "Test", "--json"}); code != ExitValidation {
		t.Fatalf("code %d: %s %s", code, output, stderr)
	}
	var result Result
	if json.Unmarshal(output.Bytes(), &result) != nil || result.Status != "failed" || *result.Diagnostics[0].Line != 2 {
		t.Fatal(output.String())
	}
}

func TestDartDiagnosticPathPreservesKeysAndIndices(t *testing.T) {
	// Matches configuration_test.dart's sourceIP rejection from
	// LocalApiConfiguration.validate and JsonDiagnostic.path serialization.
	body, err := os.ReadFile("testdata/dart-routing-invalid-field.json")
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(body)
	}))
	defer server.Close()
	for _, machine := range []bool{true, false} {
		app, output, stderr := newApp(t)
		app.In = strings.NewReader(`{"outbounds":[{}],"routing":{"rules":[{"sourceIP":["10.0.0.1"]}]}}`)
		if err := saveCredentials(app.CredentialsPath, credentials{server.URL, testToken}); err != nil {
			t.Fatal(err)
		}
		args := []string{"config", "validate", "--kind", "routing", "--file", "-"}
		if machine {
			args = append(args, "--json")
		}
		if code := app.Run(args); code != ExitValidation {
			t.Fatalf("got %d: %s %s", code, output, stderr)
		}
		if machine {
			var result Result
			if err := json.Unmarshal(output.Bytes(), &result); err != nil {
				t.Fatal(err)
			}
			diagnostic := result.Diagnostics[0]
			path, err := json.Marshal(diagnostic.Path)
			if err != nil || string(path) != `["routing","rules",0,"sourceIP"]` || *diagnostic.Offset != 50 || *diagnostic.Line != 1 || *diagnostic.Column != 51 {
				t.Fatalf("Dart source position changed: %s", output)
			}
		} else if !strings.Contains(output.String(), `["routing","rules",0,"sourceIP"] [1:51]`) {
			t.Fatalf("missing readable path: %s", output)
		}
	}
}

func TestSuccessRequiresRequestedStageAndConfiguration(t *testing.T) {
	for _, test := range []struct {
		operation, stage, validation, compiled string
		exit                                   int
	}{
		{"validate", "kernel", "{}", "", ExitOK},
		{"compile", "compile", "", "{}", ExitOK},
		{"validate", "input", "{}", "", ExitProtocol},
		{"validate", "compile", "{}", "{}", ExitProtocol},
		{"validate", "kernel", "", "{}", ExitProtocol},
		{"compile", "input", "", "{}", ExitProtocol},
		{"compile", "kernel", "{}", "{}", ExitProtocol},
		{"compile", "compile", "{}", "", ExitProtocol},
	} {
		t.Run(test.operation+"-"+test.stage+"-"+test.validation+"-"+test.compiled, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				json.NewEncoder(w).Encode(Result{APIVersion: 1, Status: "passed", Stage: test.stage, Diagnostics: []Diagnostic{}, ValidationConfig: test.validation, CompiledConfig: test.compiled})
			}))
			defer server.Close()
			app, output, stderr := newApp(t)
			if err := saveCredentials(app.CredentialsPath, credentials{server.URL, testToken}); err != nil {
				t.Fatal(err)
			}
			if code := app.Run([]string{"config", test.operation, "--kind", "raw", "--file", "-", "--json"}); code != test.exit {
				t.Fatalf("got %d want %d: %s %s", code, test.exit, output, stderr)
			}
		})
	}
}

func TestCompileExplicitInputsAndExclusiveOutput(t *testing.T) {
	app, output, stderr := newApp(t)
	directory := fixture(t)
	nodesPath, optionsPath, outputPath := filepath.Join(directory, "nodes.json"), filepath.Join(directory, "options.json"), filepath.Join(directory, "compiled.json")
	os.WriteFile(nodesPath, []byte(`[{"protocol":"freedom","tag":"example"}]`), 0600)
	os.WriteFile(optionsPath, []byte(`{"platform":"macos","sessionDirectory":"/explicit/run","metricsPort":9001,"socksPort":9002,"ipv6":false}`), 0600)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var input configRequest
		json.NewDecoder(r.Body).Decode(&input)
		if r.URL.Path != "/api/v1/config/compile" || len(input.Outbounds) == 0 || len(input.Options) == 0 {
			t.Error("missing explicit inputs")
		}
		json.NewEncoder(w).Encode(Result{APIVersion: 1, Status: "passed", Stage: "compile", Diagnostics: []Diagnostic{}, CompiledConfig: `{"outbounds":[]}`})
	}))
	defer server.Close()
	saveCredentials(app.CredentialsPath, credentials{server.URL, testToken})
	args := []string{"config", "compile", "--kind", "routing", "--file", "-", "--outbounds", nodesPath, "--options", optionsPath, "--output", outputPath, "--json"}
	if code := app.Run(args); code != 0 {
		t.Fatalf("code %d: %s %s", code, output, stderr)
	}
	data, err := os.ReadFile(outputPath)
	if err != nil || string(data) != `{"outbounds":[]}` {
		t.Fatal("compiled output not saved")
	}
	app.In = strings.NewReader("{}")
	if code := app.Run(args); code != ExitUsage {
		t.Fatalf("existing output must not be overwritten: %d", code)
	}
}

func TestEndpointAndCredentialsRestrictions(t *testing.T) {
	for _, endpoint := range []string{"https://127.0.0.1:18587", "http://localhost:18587", "http://[::1]:18587", "http://example.com:18587", "http://127.0.0.1", "http://127.0.0.1:18587/api", "http://name:token@127.0.0.1:18587", "http://127.0.0.1:18587?", "http://127.0.0.1:18587#fragment", "http://127.0.0.1:0"} {
		if _, err := normalizeEndpoint(endpoint); err == nil {
			t.Errorf("accepted %s", endpoint)
		}
	}
	app, output, _ := newApp(t)
	if code := app.Run([]string{"info", "--json"}); code != ExitAuth {
		t.Fatalf("missing credentials: %d", code)
	}
	var result Result
	if json.Unmarshal(output.Bytes(), &result) != nil || result.Status != "notRun" {
		t.Fatal("no structured local failure")
	}
	if code := app.Run([]string{"auth", "login", "--token", testToken}); code != ExitUsage {
		t.Fatal("accepted token argument")
	}
}

func TestRedirectsAreNotFollowedAndProxyIsDisabled(t *testing.T) {
	called := false
	target := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { called = true; infoResponse(w) }))
	defer target.Close()
	redirect := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, target.URL, http.StatusTemporaryRedirect)
	}))
	defer redirect.Close()
	t.Setenv("HTTP_PROXY", target.URL)
	t.Setenv("http_proxy", target.URL)
	_, err := readInfo(credentials{redirect.URL, testToken})
	var failure *clientFailure
	if !errors.As(err, &failure) || failure.code != ExitProtocol || called {
		t.Fatalf("redirect/proxy leaked token: %v", err)
	}
}

func TestProtocolAndOperationalFailures(t *testing.T) {
	for _, test := range []struct {
		name     string
		status   int
		response string
		exit     int
	}{
		{"busy", 409, `{"apiVersion":1,"status":"notRun","stage":"input","diagnostics":[{"code":"busy","message":"Retry later"}]}`, ExitNotRun},
		{"auth", 401, `{}`, ExitAuth},
		{"invalid-json", 200, `<html>oops</html>`, ExitProtocol},
		{"invalid-version", 200, `{"apiVersion":2,"status":"passed","stage":"kernel","diagnostics":[]}`, ExitProtocol},
		{"missing-diagnostics", 200, `{"apiVersion":1,"status":"passed","stage":"kernel"}`, ExitProtocol},
		{"http-error-claims-success", 500, `{"apiVersion":1,"status":"passed","stage":"kernel","diagnostics":[]}`, ExitProtocol},
	} {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(test.status)
				io.WriteString(w, test.response)
			}))
			defer server.Close()
			app, output, stderr := newApp(t)
			saveCredentials(app.CredentialsPath, credentials{server.URL, testToken})
			if code := app.Run([]string{"config", "validate", "--kind", "raw", "--file", "-", "--json"}); code != test.exit {
				t.Fatalf("got %d want %d; %s %s", code, test.exit, output, stderr)
			}
		})
	}
}

func TestUnavailableAndOversizedInputs(t *testing.T) {
	server := httptest.NewServer(http.NotFoundHandler())
	endpoint := server.URL
	server.Close()
	app, _, _ := newApp(t)
	saveCredentials(app.CredentialsPath, credentials{endpoint, testToken})
	if code := app.Run([]string{"info", "--json"}); code != ExitUnavailable {
		t.Fatalf("unavailable %d", code)
	}
	app.In = strings.NewReader(strings.Repeat("a", maxBody+1))
	if code := app.Run([]string{"config", "validate", "--kind", "raw", "--file", "-", "--json"}); code != ExitUsage {
		t.Fatalf("oversized %d", code)
	}
	app.In = bytes.NewReader([]byte{0xff, 0xfe})
	if code := app.Run([]string{"config", "validate", "--kind", "raw", "--file", "-", "--json"}); code != ExitUsage {
		t.Fatalf("invalid UTF-8 %d", code)
	}
}
