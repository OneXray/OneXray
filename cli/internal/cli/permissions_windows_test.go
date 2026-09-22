package cli

import (
	"path/filepath"
	"strings"
	"testing"

	"golang.org/x/sys/windows"
)

func TestCredentialsHaveProtectedCurrentUserOnlyDACL(t *testing.T) {
	path := filepath.Join(fixture(t), "auth", "credentials.json")
	if err := saveCredentials(path, credentials{DefaultEndpoint, testToken}); err != nil {
		t.Fatal(err)
	}
	user, err := windows.GetCurrentProcessToken().GetTokenUser()
	if err != nil {
		t.Fatal(err)
	}
	for _, candidate := range []string{filepath.Dir(path), path} {
		descriptor, err := windows.GetNamedSecurityInfo(candidate, windows.SE_FILE_OBJECT, windows.DACL_SECURITY_INFORMATION)
		if err != nil {
			t.Fatal(err)
		}
		control, _, err := descriptor.Control()
		if err != nil || control&windows.SE_DACL_PROTECTED == 0 {
			t.Fatalf("unprotected ACL: %v", err)
		}
		text := descriptor.String()
		if strings.Count(text, "(") != 1 || !strings.Contains(text, user.User.Sid.String()) {
			t.Fatalf("ACL must contain only the current user: %s", text)
		}
	}
	// Replacing an existing credential file must preserve its private ACL.
	if err := saveCredentials(path, credentials{DefaultEndpoint, testToken}); err != nil {
		t.Fatal(err)
	}
	if _, err := loadCredentials(path); err != nil {
		t.Fatal(err)
	}
}
