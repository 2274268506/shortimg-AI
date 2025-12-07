package utils

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// ShortLinkClient 短链服务客户端
type ShortLinkClient struct {
	BaseURL    string
	APIKey     string
	HTTPClient *http.Client
}

// ShortLinkRequest 创建短链请求（图床专用）
type ShortLinkRequest struct {
	ImagePath  string                 `json:"image_path"` // 图片CDN路径（如：/uploads/xxx.jpg）
	CustomCode string                 `json:"custom_code,omitempty"`
	ExpireTime int64                  `json:"expire_time,omitempty"` // 过期时间（秒）
	Metadata   map[string]interface{} `json:"metadata,omitempty"`
}

// ShortLinkResponse 短链响应
type ShortLinkResponse struct {
	Success bool       `json:"success"`
	Data    *ShortLink `json:"data,omitempty"`
	Error   string     `json:"error,omitempty"`
}

// ShortLink 短链信息
type ShortLink struct {
	Code      string `json:"code"`
	ShortURL  string `json:"short_url"`
	LongURL   string `json:"long_url"`
	ExpireAt  *int64 `json:"expire_at,omitempty"`
	CreatedAt int64  `json:"created_at"`
}

// BatchShortLinkRequest 批量创建请求
type BatchShortLinkRequest struct {
	Images     []ImageInfo `json:"images"`
	ExpireTime int64       `json:"expire_time,omitempty"`
}

// ImageInfo 图片信息
type ImageInfo struct {
	ImagePath  string                 `json:"image_path"` // CDN路径
	CustomCode string                 `json:"custom_code,omitempty"`
	Metadata   map[string]interface{} `json:"metadata,omitempty"`
}

// BatchShortLinkResponse 批量响应
type BatchShortLinkResponse struct {
	Success bool         `json:"success"`
	Data    *BatchResult `json:"data,omitempty"`
	Error   string       `json:"error,omitempty"`
}

// BatchResult 批量结果
type BatchResult struct {
	Total   int         `json:"total"`
	Success int         `json:"success"`
	Failed  int         `json:"failed"`
	Results []BatchItem `json:"results"`
}

// BatchItem 批量项
type BatchItem struct {
	Success  bool   `json:"success"`
	Code     string `json:"code,omitempty"`
	ShortURL string `json:"short_url,omitempty"`
	LongURL  string `json:"long_url,omitempty"`
	Error    string `json:"error,omitempty"`
}

// NewShortLinkClient 创建短链客户端
func NewShortLinkClient(baseURL string, apiKey string) *ShortLinkClient {
	return &ShortLinkClient{
		BaseURL: baseURL,
		APIKey:  apiKey,
		HTTPClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// CreateShortLink 创建单个短链
func (c *ShortLinkClient) CreateShortLink(req *ShortLinkRequest) (*ShortLink, error) {
	jsonData, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("序列化请求失败: %w", err)
	}

	httpReq, err := http.NewRequest("POST", c.BaseURL+"/api/imagebed/create", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("创建请求失败: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	if c.APIKey != "" {
		httpReq.Header.Set("X-API-Key", c.APIKey)
	}

	resp, err := c.HTTPClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("请求失败: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取响应失败: %w", err)
	}

	var result ShortLinkResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %w", err)
	}

	if !result.Success {
		return nil, fmt.Errorf("创建短链失败: %s", result.Error)
	}

	return result.Data, nil
}

// BatchCreateShortLinks 批量创建短链
func (c *ShortLinkClient) BatchCreateShortLinks(req *BatchShortLinkRequest) (*BatchResult, error) {
	jsonData, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("序列化请求失败: %w", err)
	}

	httpReq, err := http.NewRequest("POST", c.BaseURL+"/api/imagebed/batch", bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, fmt.Errorf("创建请求失败: %w", err)
	}

	httpReq.Header.Set("Content-Type", "application/json")
	if c.APIKey != "" {
		httpReq.Header.Set("X-API-Key", c.APIKey)
	}

	resp, err := c.HTTPClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("请求失败: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取响应失败: %w", err)
	}

	var result BatchShortLinkResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %w", err)
	}

	if !result.Success {
		return nil, fmt.Errorf("批量创建失败: %s", result.Error)
	}

	return result.Data, nil
}

// GetShortLinkInfo 获取短链信息
func (c *ShortLinkClient) GetShortLinkInfo(code string) (*ShortLink, error) {
	resp, err := c.HTTPClient.Get(c.BaseURL + "/api/imagebed/info/" + code)
	if err != nil {
		return nil, fmt.Errorf("请求失败: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取响应失败: %w", err)
	}

	var result ShortLinkResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %w", err)
	}

	if !result.Success {
		return nil, fmt.Errorf("获取短链失败: %s", result.Error)
	}

	return result.Data, nil
}

// UpdateMetadata 更新短链元数据
func (c *ShortLinkClient) UpdateMetadata(code string, metadata map[string]interface{}) error {
	jsonData, err := json.Marshal(metadata)
	if err != nil {
		return fmt.Errorf("序列化元数据失败: %w", err)
	}

	req, err := http.NewRequest(
		"PUT",
		c.BaseURL+"/api/imagebed/metadata/"+code,
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		return fmt.Errorf("创建请求失败: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("请求失败: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("读取响应失败: %w", err)
	}

	var result ShortLinkResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return fmt.Errorf("解析响应失败: %w", err)
	}

	if !result.Success {
		return fmt.Errorf("更新元数据失败: %s", result.Error)
	}

	return nil
}

// StatsResponse 统计响应
type StatsResponse struct {
	Success bool   `json:"success"`
	Data    *Stats `json:"data,omitempty"`
	Error   string `json:"error,omitempty"`
}

// Stats 统计信息
type Stats struct {
	TotalLinks   int        `json:"total_links"`
	TodayCreated int        `json:"today_created"`
	TotalClicks  int        `json:"total_clicks"`
	TopImages    []TopImage `json:"top_images"`
}

// TopImage 热门图片
type TopImage struct {
	Code       string `json:"code"`
	LongURL    string `json:"long_url"`
	ClickCount int    `json:"click_count"`
	CreatedAt  string `json:"created_at"`
}

// GetStats 获取统计信息
func (c *ShortLinkClient) GetStats() (*Stats, error) {
	resp, err := c.HTTPClient.Get(c.BaseURL + "/api/imagebed/stats")
	if err != nil {
		return nil, fmt.Errorf("请求失败: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("读取响应失败: %w", err)
	}

	var result StatsResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("解析响应失败: %w", err)
	}

	if !result.Success {
		return nil, fmt.Errorf("获取统计失败: %s", result.Error)
	}

	return result.Data, nil
}
