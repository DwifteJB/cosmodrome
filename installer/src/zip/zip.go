package zip

import (
	archzip "archive/zip"
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

func Extract(zipData []byte, destDir string) error {
	reader, err := archzip.NewReader(bytes.NewReader(zipData), int64(len(zipData)))
	if err != nil {
		return fmt.Errorf("failed to open zip: %w", err)
	}

	for _, file := range reader.File {
		destPath := filepath.Join(destDir, file.Name)

		if !IsInsideDir(destPath, destDir) {
			return fmt.Errorf("invalid file path: %s", file.Name)
		}

		if file.FileInfo().IsDir() {
			os.MkdirAll(destPath, 0755)
			continue
		}

		if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
			return err
		}

		srcFile, err := file.Open()
		if err != nil {
			return err
		}

		destFile, err := os.OpenFile(destPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, file.Mode())
		if err != nil {
			srcFile.Close()
			return err
		}

		_, err = io.Copy(destFile, srcFile)
		srcFile.Close()
		destFile.Close()

		if err != nil {
			return err
		}
	}

	return nil
}

func IsInsideDir(path, dir string) bool {
	rel, err := filepath.Rel(dir, path)
	if err != nil {
		return false
	}
	return !filepath.IsAbs(rel) && rel != ".." && !filepath.HasPrefix(rel, ".."+string(filepath.Separator))
}
