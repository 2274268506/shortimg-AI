package imageprocessor

import (
	"image"
	"image/color"
	"image/jpeg"
	"os"
	"path/filepath"
	"testing"
)

// 创建测试图片
func createTestImage(path string, width, height int) error {
	img := image.NewRGBA(image.Rect(0, 0, width, height))

	// 填充渐变色
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.Set(x, y, color.RGBA{
				R: uint8(x % 256),
				G: uint8(y % 256),
				B: uint8((x + y) % 256),
				A: 255,
			})
		}
	}

	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	return jpeg.Encode(file, img, &jpeg.Options{Quality: 90})
}

func TestNewImageProcessor(t *testing.T) {
	processor := NewImageProcessor(85)
	if processor.Quality != 85 {
		t.Errorf("期望质量为 85，得到 %d", processor.Quality)
	}

	// 测试超出范围的质量
	processor = NewImageProcessor(150)
	if processor.Quality != 85 {
		t.Errorf("质量超出范围时应使用默认值 85，得到 %d", processor.Quality)
	}
}

func TestProcessImage(t *testing.T) {
	// 创建临时目录
	tmpDir := t.TempDir()
	testImagePath := filepath.Join(tmpDir, "test.jpg")

	// 创建测试图片
	if err := createTestImage(testImagePath, 2000, 1500); err != nil {
		t.Fatalf("创建测试图片失败: %v", err)
	}

	// 处理图片
	processor := NewImageProcessor(85)
	if err := processor.ProcessImage(testImagePath); err != nil {
		t.Fatalf("处理图片失败: %v", err)
	}

	// 验证缩略图是否生成
	for _, size := range ThumbnailSizes {
		thumbPath := GetThumbnailPath(testImagePath, size.Name)
		if _, err := os.Stat(thumbPath); os.IsNotExist(err) {
			t.Errorf("缩略图 %s 未生成", size.Name)
		}
	}

	// 验证 WebP 是否生成
	webpPath := GetWebPPath(testImagePath)
	if _, err := os.Stat(webpPath); os.IsNotExist(err) {
		t.Error("WebP 文件未生成")
	}
}

func TestGetThumbnailPath(t *testing.T) {
	originalPath := filepath.Join("path", "to", "image.jpg")
	expectedPath := filepath.Join("path", "to", "image_small.jpg")

	thumbPath := GetThumbnailPath(originalPath, "small")
	if thumbPath != expectedPath {
		t.Errorf("期望缩略图路径 %s，得到 %s", expectedPath, thumbPath)
	}
}

func TestGetWebPPath(t *testing.T) {
	originalPath := filepath.Join("path", "to", "image.jpg")
	expectedPath := filepath.Join("path", "to", "image.webp")

	webpPath := GetWebPPath(originalPath)
	if webpPath != expectedPath {
		t.Errorf("期望 WebP 路径 %s，得到 %s", expectedPath, webpPath)
	}
}

func TestIsSupportedFormat(t *testing.T) {
	tests := []struct {
		ext      string
		expected bool
	}{
		{".jpg", true},
		{".jpeg", true},
		{".png", true},
		{".gif", true},
		{".webp", true},
		{".bmp", false},
		{".txt", false},
	}

	for _, tt := range tests {
		result := IsSupportedFormat(tt.ext)
		if result != tt.expected {
			t.Errorf("IsSupportedFormat(%s) = %v，期望 %v", tt.ext, result, tt.expected)
		}
	}
}

func BenchmarkProcessImage(b *testing.B) {
	tmpDir := b.TempDir()
	testImagePath := filepath.Join(tmpDir, "test.jpg")

	if err := createTestImage(testImagePath, 2000, 1500); err != nil {
		b.Fatalf("创建测试图片失败: %v", err)
	}

	processor := NewImageProcessor(85)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = processor.ProcessImage(testImagePath)
	}
}
