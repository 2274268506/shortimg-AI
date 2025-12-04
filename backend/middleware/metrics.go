package middleware

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// HTTP 请求计数器
	httpRequestsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "path", "status"},
	)

	// HTTP 请求延迟直方图
	httpRequestDuration = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request latencies in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "path"},
	)

	// HTTP 请求大小
	httpRequestSize = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_size_bytes",
			Help:    "HTTP request sizes in bytes",
			Buckets: prometheus.ExponentialBuckets(100, 10, 7),
		},
		[]string{"method", "path"},
	)

	// HTTP 响应大小
	httpResponseSize = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_response_size_bytes",
			Help:    "HTTP response sizes in bytes",
			Buckets: prometheus.ExponentialBuckets(100, 10, 7),
		},
		[]string{"method", "path"},
	)

	// 当前活跃请求数
	httpActiveRequests = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "http_requests_active",
			Help: "Number of active HTTP requests",
		},
	)

	// 图片上传计数
	imageUploadsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "image_uploads_total",
			Help: "Total number of image uploads",
		},
		[]string{"format", "status"},
	)

	// 缓存命中率
	cacheHitsTotal = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "cache_hits_total",
			Help: "Total number of cache hits",
		},
		[]string{"cache_type", "hit"},
	)
)

// PrometheusMiddleware Prometheus 监控中间件
func PrometheusMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// 记录请求开始
		start := time.Now()
		httpActiveRequests.Inc()
		defer httpActiveRequests.Dec()

		// 记录请求大小
		requestSize := computeApproximateRequestSize(c.Request)
		httpRequestSize.WithLabelValues(c.Request.Method, c.FullPath()).Observe(float64(requestSize))

		// 处理请求
		c.Next()

		// 记录请求完成
		duration := time.Since(start).Seconds()
		status := strconv.Itoa(c.Writer.Status())
		path := c.FullPath()
		if path == "" {
			path = c.Request.URL.Path
		}

		// 记录指标
		httpRequestsTotal.WithLabelValues(c.Request.Method, path, status).Inc()
		httpRequestDuration.WithLabelValues(c.Request.Method, path).Observe(duration)
		httpResponseSize.WithLabelValues(c.Request.Method, path).Observe(float64(c.Writer.Size()))
	}
}

// RecordImageUpload 记录图片上传
func RecordImageUpload(format, status string) {
	imageUploadsTotal.WithLabelValues(format, status).Inc()
}

// RecordCacheHit 记录缓存命中
func RecordCacheHit(cacheType string, hit bool) {
	hitStr := "miss"
	if hit {
		hitStr = "hit"
	}
	cacheHitsTotal.WithLabelValues(cacheType, hitStr).Inc()
}

// computeApproximateRequestSize 计算请求大小
func computeApproximateRequestSize(r *http.Request) int {
	s := 0
	if r.URL != nil {
		s += len(r.URL.String())
	}

	s += len(r.Method)
	s += len(r.Proto)
	for name, values := range r.Header {
		s += len(name)
		for _, value := range values {
			s += len(value)
		}
	}
	s += len(r.Host)

	// 如果有 body，估算其大小
	if r.ContentLength > 0 {
		s += int(r.ContentLength)
	}

	return s
}
