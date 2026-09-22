package cli

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The Dart test owns a real LocalApiServer and a test-only kernel adapter.
// The normal Go suite skips this test; no user credentials or HOME changes.
func TestDartAPIIntegration(t *testing.T) {
	endpoint := os.Getenv("ONEXRAY_DART_API_ENDPOINT")
	if endpoint == "" {
		t.Skip("started by the opt-in Dart local API integration test")
	}
	directory := os.Getenv("ONEXRAY_DART_TEST_DIRECTORY")
	if !filepath.IsAbs(directory) || !strings.Contains(filepath.Clean(directory), string(filepath.Separator)+"references"+string(filepath.Separator)) {
		t.Fatal("Dart integration requires an absolute isolated references directory")
	}
	const token = "dart-cli-integration-012345678901234567890123456789"
	credentialFile := filepath.Join(directory, "auth", "credentials.json")
	run := func(want int, source, loginToken string, args ...string) string {
		t.Helper()
		var stdout, stderr bytes.Buffer
		app := App{In: strings.NewReader(source), Out: &stdout, Err: &stderr,
			CredentialsPath: credentialFile, ReadToken: func() (string, error) { return loginToken, nil }}
		if code := app.Run(args); code != want {
			t.Fatalf("%v: exit %d, want %d; stdout=%s stderr=%s", args, code, want, &stdout, &stderr)
		}
		if strings.Contains(stdout.String()+stderr.String(), token) {
			t.Fatal("test credentials appeared in command output")
		}
		return stdout.String()
	}
	run(ExitOK, "", token, "auth", "login", "--endpoint", endpoint, "--json")
	var info Info
	if err := json.Unmarshal([]byte(run(ExitOK, "", "", "info", "--json")), &info); err != nil || info.APIVersion != 1 {
		t.Fatalf("App info did not round-trip: %v", err)
	}
	var valid Result
	if err := json.Unmarshal([]byte(run(ExitOK, `{"tag":"CLI node","protocol":"freedom"}`, "",
		"config", "validate", "--kind", "outbound", "--file", "-", "--json")), &valid); err != nil || valid.Stage != "kernel" || valid.ValidationConfig == "" {
		t.Fatalf("App validation did not pass: %v", err)
	}
	const invalid = `{"outbounds":[{}],"routing":{"rules":[{"sourceIP":["10.0.0.1"]}]}}`
	var rejected Result
	if err := json.Unmarshal([]byte(run(ExitValidation, invalid, "", "config", "validate", "--kind", "routing", "--file", "-", "--json")), &rejected); err != nil || len(rejected.Diagnostics) != 1 {
		t.Fatalf("App field diagnostic did not round-trip: %v", err)
	}
	path, _ := json.Marshal(rejected.Diagnostics[0].Path)
	if string(path) != `["routing","rules",0,"sourceIP"]` || rejected.Diagnostics[0].Offset == nil || *rejected.Diagnostics[0].Offset != 50 {
		t.Fatalf("incorrect App source location: %s", path)
	}
	options, err := json.Marshal(map[string]any{"platform": "macos", "sessionDirectory": filepath.Join(directory, "preview-run"), "metricsPort": 19021, "socksPort": 19022, "ipv6": true})
	if err != nil {
		t.Fatal(err)
	}
	optionsFile := filepath.Join(directory, "options.json")
	if err := os.WriteFile(optionsFile, options, 0600); err != nil {
		t.Fatal(err)
	}
	previewFile := filepath.Join(directory, "preview.json")
	var compiled Result
	if err := json.Unmarshal([]byte(run(ExitOK, `{"name":"CLI integration","outbounds":[{"tag":"direct","protocol":"freedom"}]}`, "",
		"config", "compile", "--kind", "raw", "--file", "-", "--options", optionsFile, "--output", previewFile, "--json")), &compiled); err != nil || compiled.Stage != "compile" || compiled.CompiledConfig == "" {
		t.Fatalf("App compile preview did not round-trip: %v", err)
	}
	preview, err := os.ReadFile(previewFile)
	if err != nil || string(preview) != compiled.CompiledConfig {
		t.Fatalf("compiled preview differs from API response: %v", err)
	}
	run(ExitAuth, "", strings.Repeat("B", 48), "auth", "login", "--endpoint", endpoint, "--json")
	saved, err := loadCredentials(credentialFile)
	if err != nil || saved.Token != token {
		t.Fatal("failed reauthentication replaced valid credentials")
	}
	run(ExitOK, "", "", "auth", "logout", "--json")
	if _, err := os.Stat(credentialFile); !os.IsNotExist(err) {
		t.Fatal("logout did not delete test credentials")
	}
}
