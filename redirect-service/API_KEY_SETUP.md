# API Key 设置指南

## 问题：前端界面查询不到创建的短链

**原因**：前端没有设置 API Key，无法通过身份验证访问 API。

## 解决方案

### 方法一：通过设置页面（推荐）

1. 访问 Dashboard: http://localhost/dashboard/
2. 如果弹出提示框，点击"确定"跳转到设置页面
3. 或直接访问: http://localhost/dashboard/setup.html
4. 输入测试用 API Key: `sk_test_12345678901234567890123456789012`
5. 点击"保存设置"

### 方法二：通过浏览器控制台

1. 打开浏览器开发者工具（F12）
2. 切换到"控制台"（Console）标签
3. 输入以下命令并回车：

```javascript
localStorage.setItem('api_key', 'sk_test_12345678901234567890123456789012')
```

4. 刷新页面（F5）

### 方法三：在提示框中输入

1. 访问 Dashboard 时会弹出输入框
2. 直接输入 API Key: `sk_test_12345678901234567890123456789012`
3. 点击确定

## 当前可用的测试 API Key

```
sk_test_12345678901234567890123456789012
```

**重要提示**：此 Key 为测试密钥，仅用于开发环境。

## 验证设置是否成功

设置完成后，页面右上角应显示：

```
API Key: sk_test_...9012 ✓
```

如果显示为绿色，说明设置成功。刷新页面后应能看到短链列表。

## 如何创建新的 API Key

如需创建生产环境的 API Key，请使用管理工具：

```bash
cd redirect-service
docker-compose exec openresty resty tools/manage_api_keys.lua create "我的管理Key" "admin" 365
```

参数说明：
- `"我的管理Key"`: API Key 的名称
- `"admin"`: 权限级别
- `365`: 有效期（天数）

## 常见问题

### Q: 设置了 API Key 但仍然无法查询？

A: 请检查：
1. 浏览器控制台是否有错误信息
2. API Key 是否正确（不要有多余的空格）
3. 刷新页面后重试

### Q: API Key 存储在哪里？

A: 存储在浏览器的 localStorage 中，不会发送到服务器存储。

### Q: 如何清除已设置的 API Key？

A: 在浏览器控制台执行：
```javascript
localStorage.removeItem('api_key')
```

## 测试 API 访问

使用 curl 测试 API 是否正常工作：

```bash
curl -s "http://localhost/api/v1/links?page=1&limit=5" \
  -H "X-API-Key: sk_test_12345678901234567890123456789012" \
  | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

应返回短链列表的 JSON 数据。
