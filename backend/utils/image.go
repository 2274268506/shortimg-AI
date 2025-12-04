package utils

import (
	"fmt"
	"image"
	"image/gif"
	"image/jpeg"
	"image/png"
	"os"
	"path/filepath"
	"strings"

	"github.com/chai2010/webp"
	"github.com/disintegration/imaging"
	"golang.org/x/image/bmp"
	"golang.org/x/image/tiff"
)

// SupportedFormats 支持的图片格式
var SupportedFormats = map[string]bool{
	".jpg":  true,
	".jpeg": true,
	".png":  true,
	".gif":  true,
	".webp": true,
	".bmp":  true,
	".tiff": true,
	".tif":  true,
}

// AnimatedFormats 动态图片格式(不生成缩略图)
var AnimatedFormats = map[string]bool{
	".gif": true,
}

// GenerateThumbnail 生成缩略图
func GenerateThumbnail(sourcePath string, thumbnailPath string, maxWidth int) error {
	// 打开原图
	img, err := imaging.Open(sourcePath)
	if err != nil {
		return err
	}

	// 生成缩略图（保持宽高比）
	thumbnail := imaging.Resize(img, maxWidth, 0, imaging.Lanczos)

	// 确保目录存在
	thumbnailDir := filepath.Dir(thumbnailPath)
	os.MkdirAll(thumbnailDir, 0755)

	// 保存缩略图（自动识别格式）
	return imaging.Save(thumbnail, thumbnailPath, imaging.JPEGQuality(80))
}

// ConvertImageFormat 转换图片格式
func ConvertImageFormat(sourcePath string, targetPath string, targetFormat string, quality int) error {
	// 打开原图
	img, err := imaging.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	// 确保目标目录存在
	targetDir := filepath.Dir(targetPath)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("创建目录失败: %w", err)
	}

	// 设置默认质量
	if quality <= 0 || quality > 100 {
		quality = 90
	}

	// 创建输出文件
	outFile, err := os.Create(targetPath)
	if err != nil {
		return fmt.Errorf("创建输出文件失败: %w", err)
	}
	defer outFile.Close()

	// 根据目标格式保存
	targetFormat = strings.ToLower(strings.TrimPrefix(targetFormat, "."))

	switch targetFormat {
	case "jpg", "jpeg":
		return jpeg.Encode(outFile, img, &jpeg.Options{Quality: quality})
	case "png":
		return png.Encode(outFile, img)
	case "gif":
		return gif.Encode(outFile, img, nil)
	case "bmp":
		return bmp.Encode(outFile, img)
	case "tiff", "tif":
		return tiff.Encode(outFile, img, nil)
	case "webp":
		// WebP 支持，质量范围 0-100
		return webp.Encode(outFile, img, &webp.Options{
			Lossless: false,
			Quality:  float32(quality),
		})
	default:
		return fmt.Errorf("不支持的目标格式: %s", targetFormat)
	}
}

// GetImageDimensions 获取图片尺寸
func GetImageDimensions(imagePath string) (int, int, error) {
	img, err := imaging.Open(imagePath)
	if err != nil {
		return 0, 0, err
	}

	bounds := img.Bounds()
	return bounds.Dx(), bounds.Dy(), nil
}

// IsAnimatedFormat 判断是否为动态图片格式
func IsAnimatedFormat(ext string) bool {
	return AnimatedFormats[strings.ToLower(ext)]
}

// IsSupportedFormat 判断是否为支持的格式
func IsSupportedFormat(ext string) bool {
	return SupportedFormats[strings.ToLower(ext)]
}

// GetFormatList 获取支持的格式列表（返回支持的格式和动图格式）
func GetFormatList() ([]string, []string) {
	// 支持的格式
	supported := make([]string, 0, len(SupportedFormats))
	for format := range SupportedFormats {
		supported = append(supported, strings.TrimPrefix(format, "."))
	}

	// 动图格式
	animated := make([]string, 0, len(AnimatedFormats))
	for format := range AnimatedFormats {
		animated = append(animated, strings.TrimPrefix(format, "."))
	}

	return supported, animated
}

// OptimizeImage 优化图片(压缩质量)
func OptimizeImage(sourcePath string, targetPath string, quality int) error {
	img, err := imaging.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	// 确保目标目录存在
	targetDir := filepath.Dir(targetPath)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("创建目录失败: %w", err)
	}

	// 根据文件扩展名选择保存格式
	ext := strings.ToLower(filepath.Ext(targetPath))

	switch ext {
	case ".jpg", ".jpeg":
		return imaging.Save(img, targetPath, imaging.JPEGQuality(quality))
	case ".png":
		// PNG使用默认压缩
		return imaging.Save(img, targetPath)
	default:
		return imaging.Save(img, targetPath)
	}
}

// ResizeImage 调整图片大小
func ResizeImage(sourcePath string, targetPath string, width, height int) error {
	img, err := imaging.Open(sourcePath)
	if err != nil {
		return fmt.Errorf("打开图片失败: %w", err)
	}

	// 调整大小(保持宽高比)
	var resized image.Image
	if width > 0 && height > 0 {
		resized = imaging.Resize(img, width, height, imaging.Lanczos)
	} else if width > 0 {
		resized = imaging.Resize(img, width, 0, imaging.Lanczos)
	} else if height > 0 {
		resized = imaging.Resize(img, 0, height, imaging.Lanczos)
	} else {
		return fmt.Errorf("宽度和高度至少需要指定一个")
	}

	// 确保目标目录存在
	targetDir := filepath.Dir(targetPath)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("创建目录失败: %w", err)
	}

	return imaging.Save(resized, targetPath)
}
