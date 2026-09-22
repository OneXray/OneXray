package cli

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
)

type credentials struct {
	Endpoint string `json:"endpoint"`
	Token    string `json:"token"`
}

func credentialPath() (string, error) {
	directory, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(directory, "OneXrayCLI", "credentials.json"), nil
}

func rejectSymlink(path string, directory bool) error {
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if info.Mode()&os.ModeSymlink != 0 || info.IsDir() != directory || (!directory && !info.Mode().IsRegular()) {
		return errors.New("credential storage must use a regular file in a non-symlink directory")
	}
	return nil
}

func loadCredentials(path string) (credentials, error) {
	if err := rejectSymlink(filepath.Dir(path), true); err != nil {
		return credentials{}, err
	}
	if err := rejectSymlink(path, false); err != nil {
		return credentials{}, err
	}
	if err := protectPath(filepath.Dir(path), true); err != nil {
		return credentials{}, err
	}
	if err := protectPath(path, false); err != nil {
		return credentials{}, err
	}
	file, err := os.Open(path)
	if err != nil {
		return credentials{}, err
	}
	defer file.Close()
	data, err := readLimited(file, 4096)
	if err != nil {
		return credentials{}, err
	}
	var value credentials
	if json.Unmarshal(data, &value) != nil || !validToken(value.Token) {
		return credentials{}, errors.New("invalid credential file")
	}
	value.Endpoint, err = normalizeEndpoint(value.Endpoint)
	return value, err
}

func saveCredentials(path string, value credentials) error {
	directory := filepath.Dir(path)
	if err := os.MkdirAll(directory, 0700); err != nil {
		return err
	}
	if err := rejectSymlink(directory, true); err != nil {
		return err
	}
	if err := protectPath(directory, true); err != nil {
		return err
	}
	if err := rejectSymlink(path, false); err != nil && !os.IsNotExist(err) {
		return err
	}
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	file, err := os.CreateTemp(directory, ".credentials-*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
	defer file.Close()
	if err = protectPath(file.Name(), false); err != nil {
		return err
	}
	if _, err = file.Write(data); err != nil {
		return err
	}
	if err = file.Sync(); err != nil {
		return err
	}
	if err = file.Close(); err != nil {
		return err
	}
	return os.Rename(file.Name(), path)
}

func removeCredentials(path string) error {
	if err := rejectSymlink(filepath.Dir(path), true); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	if err := rejectSymlink(path, false); err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	return os.Remove(path)
}
