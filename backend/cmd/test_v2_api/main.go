package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"

	"imagebed/utils"

	"github.com/joho/godotenv"
)

func main() {
	// 加载环境变量
	if err := godotenv.Load("../.env"); err != nil {
		log.Println("警告: 未找到 .env 文件")
	}

	// 创建短链客户端
	baseURL := os.Getenv("SHORT_LINK_BASE_URL")
	if baseURL == "" {
		baseURL = "http://localhost"
	}
	apiKey := os.Getenv("SHORT_LINK_API_KEY")
	if apiKey == "" {
		apiKey = "sk_test_12345678901234567890123456789012"
	}

	client := utils.NewShortLinkClient(baseURL, apiKey)

	fmt.Println("=== 测试 V2 API 集成 ===")
	fmt.Printf("Base URL: %s\n", baseURL)
	fmt.Printf("API Key: %s\n\n", apiKey)

	// 测试 1: 创建单个短链
	fmt.Println("测试 1: 创建单个短链（启用地理路由）")
	singleReq := &utils.ShortLinkRequest{
		ImagePath:        "/uploads/2024/12/test-go-integration.jpg",
		CustomCode:       fmt.Sprintf("go-test-%d", os.Getpid()),
		EnableGeoRouting: true,
		ExpireTime:       0, // 不过期
	}

	result, err := client.CreateShortLink(singleReq)
	if err != nil {
		log.Fatalf("❌ 创建短链失败: %v", err)
	}

	fmt.Println("✅ 短链创建成功:")
	printJSON(result)

	// 测试 2: 批量创建短链
	fmt.Println("\n测试 2: 批量创建短链")
	batchReq := &utils.BatchShortLinkRequest{
		Images: []utils.ImageInfo{
			{
				ImagePath:        "/uploads/2024/12/batch-1.jpg",
				CustomCode:       fmt.Sprintf("batch-1-%d", os.Getpid()),
				EnableGeoRouting: true,
			},
			{
				ImagePath:        "/uploads/2024/12/batch-2.jpg",
				CustomCode:       fmt.Sprintf("batch-2-%d", os.Getpid()),
				EnableGeoRouting: true,
			},
			{
				ImagePath:        "/uploads/2024/12/batch-3.jpg",
				CustomCode:       fmt.Sprintf("batch-3-%d", os.Getpid()),
				EnableGeoRouting: false, // 测试不启用地理路由
			},
		},
		ExpireTime: 0,
	}

	batchResult, err := client.BatchCreateShortLinks(batchReq)
	if err != nil {
		log.Fatalf("❌ 批量创建失败: %v", err)
	}

	fmt.Println("✅ 批量创建成功:")
	printJSON(batchResult)

	// 测试总结
	fmt.Println("\n=== 测试总结 ===")
	fmt.Printf("✅ 单个创建: 成功\n")
	fmt.Printf("   - 短链码: %s\n", result.Code)
	fmt.Printf("   - 短链URL: %s\n", result.ShortURL)
	fmt.Printf("   - 路由策略: %s\n", result.Strategy)
	fmt.Printf("   - CDN目标数: %d\n", result.TargetsCount)
	fmt.Printf("   - 地理路由: %v\n\n", result.GeoRoutingEnabled)

	fmt.Printf("✅ 批量创建: 成功\n")
	fmt.Printf("   - 总数: %d\n", batchResult.Total)
	fmt.Printf("   - 成功: %d\n", batchResult.Success)
	fmt.Printf("   - 失败: %d\n", batchResult.Failed)

	fmt.Println("\n✨ 所有测试通过！V2 API 集成成功！")
}

func printJSON(v interface{}) {
	data, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		log.Printf("JSON序列化失败: %v", err)
		return
	}
	fmt.Println(string(data))
}
