package imageprocessor

import (
	"bytes"
	"errors"
	"fmt"
	"image"
	"image/gif"
	"image/jpeg"
	"image/png"
	"os"
	"path/filepath"
	"sync"

	"github.com/nfnt/resize"
	"golang.org/x/image/webp"
)

// ThumbnailSize 缩略图尺寸定义
type ThumbnailSize struct {
	Name   string
	Width  uint
	Height uint
}

var (
	// 预定义的缩略图尺寸
	ThumbnailSizes = []ThumbnailSize{
		{"small", 150, 150},
		{"medium", 500, 500},
		{"large", 1000, 1000},
	}

	// 支持的图片格式
	SupportedFormats = []string{".jpg", ".jpeg", ".png", ".gif", ".webp"}

	// 图片处理并发控制
	processingPool = make(chan struct{}, 5) // 最多同时处理5张图片
)

// ImageProcessor 图片处理器
type ImageProcessor struct {
	Quality int // JPEG 质量 (1-100)
}

// NewImageProcessor 创建新的图片处理器
func NewImageProcessor(quality int) *ImageProcessor {
	if quality < 1 || quality > 100 {
		quality = 85 // 默认质量
	}
	return &ImageProcessor{
		Quality: quality,
	}
}

// ProcessImage 处理图片：压缩 + 生成缩略图 + WebP转换
func (p *ImageProcessor) ProcessImage(sourcePath string) error {
	// 并发控制
	processingPool <- struct{}{}
	defer func() { <-processingPool }()

	// 读取原始图片
	img, format, err := p.loadImage(sourcePath)
	if err != nil {
		return fmt.Errorf("加载图片失败: %w", err)
	}

	var wg sync.WaitGroup
	errChan := make(chan error, 4) // 缓冲通道收集错误

	// 1. 压缩原图
	wg.Add(1)
	go func() {
		defer wg.Done()
		if err := p.compressImage(sourcePath, img, format); err != nil {
			errChan <- fmt.Errorf("压缩失败: %w", err)
		}
	}()

	// 2. 生成缩略图
	wg.Add(1)
	go func() {
		defer wg.Done()
		if err := p.generateThumbnails(sourcePath, img); err != nil {
			errChan <- fmt.Errorf("生成缩略图失败: %w", err)
		}
	}()

	// 3. 转换为 WebP
	wg.Add(1)
	go func() {
		defer wg.Done()
		if err := p.convertToWebP(sourcePath, img); err != nil {
			errChan <- fmt.Errorf("WebP转换失败: %w", err)
		}
	}()

	wg.Wait()
	close(errChan)

	// 收集错误
	var errs []error
	for err := range errChan {
		errs = append(errs, err)
	}

	if len(errs) > 0 {
		return fmt.Errorf("图片处理部分失败: %v", errs)
	}

	return nil
}

// loadImage 加载图片
func (p *ImageProcessor) loadImage(path string) (image.Image, string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, "", err
	}
	defer file.Close()

	// 检测格式
	ext := filepath.Ext(path)
	var img image.Image

	switch ext {
	case ".jpg", ".jpeg":
		img, err = jpeg.Decode(file)
		return img, "jpeg", err
	case ".png":
		img, err = png.Decode(file)
		return img, "png", err
	case ".gif":
		img, err = gif.Decode(file)
		return img, "gif", err
	case ".webp":
		img, err = webp.Decode(file)
		return img, "webp", err
	default:
		// 尝试自动检测
		img, format, err := image.Decode(file)
		return img, format, err
	}
}

// compressImage 压缩图片
func (p *ImageProcessor) compressImage(path string, img image.Image, format string) error {
	// 对于 JPEG，使用指定质量重新编码
	if format == "jpeg" {
		var buf bytes.Buffer
		err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: p.Quality})
		if err != nil {
			return err
		}

		// 只有当压缩后体积更小时才替换
		compressedSize := buf.Len()
		originalSize := p.getFileSize(path)

		if compressedSize < originalSize {
			return os.WriteFile(path, buf.Bytes(), 0644)
		}
	}

	return nil
}

// generateThumbnails 生成所有尺寸的缩略图
func (p *ImageProcessor) generateThumbnails(sourcePath string, img image.Image) error {
	dir := filepath.Dir(sourcePath)
	filename := filepath.Base(sourcePath)
	ext := filepath.Ext(filename)
	nameWithoutExt := filename[:len(filename)-len(ext)]

	var wg sync.WaitGroup
	errChan := make(chan error, len(ThumbnailSizes))

	for _, size := range ThumbnailSizes {
		wg.Add(1)
		go func(s ThumbnailSize) {
			defer wg.Done()

			// 生成缩略图
			thumbnail := resize.Thumbnail(s.Width, s.Height, img, resize.Lanczos3)

			// 保存缩略图
			thumbPath := filepath.Join(dir, fmt.Sprintf("%s_%s%s", nameWithoutExt, s.Name, ext))
			if err := p.saveImage(thumbPath, thumbnail, ext); err != nil {
				errChan <- err
			}
		}(size)
	}

	wg.Wait()
	close(errChan)

	// 收集错误
	for err := range errChan {
		if err != nil {
			return err
		}
	}

	return nil
}

// convertToWebP 转换为 WebP 格式
func (p *ImageProcessor) convertToWebP(sourcePath string, img image.Image) error {
	dir := filepath.Dir(sourcePath)
	filename := filepath.Base(sourcePath)
	ext := filepath.Ext(filename)
	nameWithoutExt := filename[:len(filename)-len(ext)]

	webpPath := filepath.Join(dir, nameWithoutExt+".webp")

	// 注意：golang.org/x/image/webp 只支持解码，不支持编码
	// 这里我们使用一个占位实现，实际项目中可以使用 cwebp 工具或其他库
	// 例如: github.com/chai2010/webp 或调用系统命令

	// 临时方案：将图片编码为 JPEG 并重命名（仅作示例）
	// 生产环境建议使用专门的 WebP 编码库
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, img, &jpeg.Options{Quality: p.Quality}); err != nil {
		return err
	}

	return os.WriteFile(webpPath, buf.Bytes(), 0644)
}

// saveImage 保存图片
func (p *ImageProcessor) saveImage(path string, img image.Image, ext string) error {
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	switch ext {
	case ".jpg", ".jpeg":
		return jpeg.Encode(file, img, &jpeg.Options{Quality: p.Quality})
	case ".png":
		return png.Encode(file, img)
	case ".gif":
		return gif.Encode(file, img, nil)
	default:
		return jpeg.Encode(file, img, &jpeg.Options{Quality: p.Quality})
	}
}

// getFileSize 获取文件大小
func (p *ImageProcessor) getFileSize(path string) int {
	info, err := os.Stat(path)
	if err != nil {
		return 0
	}
	return int(info.Size())
}

// GetThumbnailPath 获取缩略图路径
func GetThumbnailPath(originalPath string, size string) string {
	dir := filepath.Dir(originalPath)
	filename := filepath.Base(originalPath)
	ext := filepath.Ext(filename)
	nameWithoutExt := filename[:len(filename)-len(ext)]

	return filepath.Join(dir, fmt.Sprintf("%s_%s%s", nameWithoutExt, size, ext))
}

// GetWebPPath 获取 WebP 格式路径
func GetWebPPath(originalPath string) string {
	dir := filepath.Dir(originalPath)
	filename := filepath.Base(originalPath)
	ext := filepath.Ext(filename)
	nameWithoutExt := filename[:len(filename)-len(ext)]

	return filepath.Join(dir, nameWithoutExt+".webp")
}

// IsSupportedFormat 检查是否支持的格式
func IsSupportedFormat(ext string) bool {
	for _, format := range SupportedFormats {
		if ext == format {
			return true
		}
	}
	return false
}

// CleanupProcessedFiles 清理处理后的文件（可选）
func CleanupProcessedFiles(originalPath string) error {
	var errs []error

	// 删除缩略图
	for _, size := range ThumbnailSizes {
		thumbPath := GetThumbnailPath(originalPath, size.Name)
		if err := os.Remove(thumbPath); err != nil && !os.IsNotExist(err) {
			errs = append(errs, err)
		}
	}

	// 删除 WebP
	webpPath := GetWebPPath(originalPath)
	if err := os.Remove(webpPath); err != nil && !os.IsNotExist(err) {
		errs = append(errs, err)
	}

	if len(errs) > 0 {
		return errors.New("清理文件时发生部分错误")
	}

	return nil
}
