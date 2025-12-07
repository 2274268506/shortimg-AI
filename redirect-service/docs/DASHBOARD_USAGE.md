# Dashboard 使用指南

## 访问地址

```
http://localhost/dashboard/
```

## 首次使用配置

### 1. 设置 API Key

Dashboard 需要 API Key 才能访问管理接口。

**当前可用的测试 API Key**：
```
sk_test_12345678901234567890123456789012
```

**设置方法**：

1. 打开 Dashboard: `http://localhost/dashboard/`
2. 按 F12 打开浏览器开发者工具
3. 在 Console 中输入：
   ```javascript
   localStorage.setItem('api_key', 'sk_test_12345678901234567890123456789012');
   location.reload();
   ```
4. 页面会自动刷新，此时 API Key 已生效

### 2. 验证 API Key 是否设置成功

在浏览器 Console 中输入：
```javascript
localStorage.getItem('api_key')
```

应该返回：
```
"sk_test_12345678901234567890123456789012"
```

## 功能说明

### 短链管理
- 查看所有短链
- 创建新短链
- 编辑短链规则
- 删除短链
- 批量操作

### 统计信息
- 总访问量
- 今日访问量
- 短链总数
- 服务类型分布

### 实时监控
- 访问趋势图表
- 服务健康状态
- 性能指标

## 常见问题

### Q: 提示 "Rate limit exceeded" 错误？

**原因**：请求过于频繁，触发了限流保护。

**解决方案**：
1. 等待 60 秒后重试
2. 限流配置已调整为 1000 次/分钟，正常使用不会触发

### Q: 提示 "Authentication required" 错误？

**原因**：未设置或 API Key 无效。

**解决方案**：
1. 检查是否已设置 API Key（参见上方"设置 API Key"）
2. 确认 API Key 正确且有效
3. 检查 API Key 是否已过期

### Q: Dashboard 无法加载数据？

**检查步骤**：
1. 确认服务是否正常运行：
   ```bash
   docker ps | grep openresty
   ```

2. 检查 API 是否可访问：
   ```bash
   curl -H "X-API-Key: sk_test_12345678901234567890123456789012" http://localhost/api/v1/stats
   ```

3. 查看浏览器 Console 是否有错误信息

4. 查看 OpenResty 日志：
   ```bash
   docker logs short-link-openresty
   ```

## API Key 管理

### 查看所有 API Keys

```bash
docker exec short-link-redis redis-cli KEYS "api_key:*"
```

### 查看 API Key 详情

```bash
docker exec short-link-redis redis-cli GET "api_key:sk_test_12345678901234567890123456789012"
```

### 清除本地 API Key

如需重新设置 API Key，在浏览器 Console 中执行：
```javascript
localStorage.removeItem('api_key');
location.reload();
```

## 限流配置

当前限流策略：
- **API 接口**: 1000 次/分钟
- **短链访问**: 100 次/分钟/IP

如需调整，修改 `conf/nginx.conf` 中的限流参数后重启服务。

## 技术支持

如遇到其他问题，请查看：
- [管理 API 文档](./ADMIN_API.md)
- [服务配置指南](../README.md)
- OpenResty 日志: `redirect-service/logs/error.log`
