//go:build !windows

package cli

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCredentialsHavePrivatePermissionsAndRejectSymlinks(t *testing.T) {
	directory := fixture(t)
	path := filepath.Join(directory, "auth", "credentials.json")
	if err := saveCredentials(path, credentials{DefaultEndpoint, testToken}); err != nil {
		t.Fatal(err)
	}
	for _, item := range []struct {
		path string
		mode os.FileMode
	}{{filepath.Dir(path), 0700}, {path, 0600}} {
		info, err := os.Stat(item.path)
		if err != nil || info.Mode().Perm() != item.mode {
			t.Fatalf("bad permission %v %v", info, err)
		}
	}
	linked := filepath.Join(directory, "link")
	if err := os.Symlink(filepath.Dir(path), linked); err != nil {
		t.Fatal(err)
	}
	if err := saveCredentials(filepath.Join(linked, "credentials.json"), credentials{DefaultEndpoint, testToken}); err == nil {
		t.Fatal("accepted symlink directory")
	}
	if _, err := loadCredentials(filepath.Join(linked, "credentials.json")); err == nil {
		t.Fatal("read credentials through symlink")
	}
	if err := removeCredentials(filepath.Join(linked, "credentials.json")); err == nil {
		t.Fatal("removed credentials through symlink")
	}
}
