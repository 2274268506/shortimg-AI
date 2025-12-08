# ⚡ Nginx 快速参考卡

## 📝 常用命令

```bash
# 测试配置
sudo nginx -t

# 重新加载配置（不中断服务）
sudo nginx -s reload

# 重启服务
sudo systemctl restart nginx

# 查看状态
sudo systemctl status nginx

# 查看访问日志
sudo tail -f /var/log/nginx/img.oxvxo.link.access.log

# 查看错误日志
sudo tail -f /var/log/nginx/img.oxvxo.link.error.log
```

## 🔧 配置位置

```
配置文件: /etc/nginx/sites-available/img.oxvxo.link.conf
启用链接: /etc/nginx/sites-enabled/img.oxvxo.link.conf
或直接:   /etc/nginx/conf.d/img.oxvxo.link.conf

前端资源: /var/www/img.oxvxo.link/dist
SSL证书:  /etc/letsencrypt/live/img.oxvxo.link/
日志目录: /var/log/nginx/
```

## 🔒 证书管理

```bash
# 申请证书
sudo certbot certonly --webroot -w /var/www/certbot \
  -d img.oxvxo.link -d www.img.oxvxo.link

# 续期证书
sudo certbot renew

# 测试续期
sudo certbot renew --dry-run

# 查看证书信息
sudo certbot certificates
```

## 🚀 部署前端

```bash
# 构建
npm run build

# 上传到服务器
rsync -avz --delete dist/ user@server:/var/www/img.oxvxo.link/dist/

# 设置权限
sudo chown -R www-data:www-data /var/www/img.oxvxo.link/dist
sudo chmod -R 755 /var/www/img.oxvxo.link/dist
```

## 📊 限流配置

```nginx
认证接口: 5 请求/秒  (burst=10)
上传接口: 10 请求/秒 (burst=5)
通用API:  100 请求/秒 (burst=50)
```

## 🛡️ 安全检查清单

- [ ] SSL 证书已配置且有效
- [ ] HTTPS 强制跳转已启用
- [ ] CORS 白名单已正确配置
- [ ] Swagger 文档已限制访问
- [ ] Metrics 端点已限制访问
- [ ] 上传大小限制已设置
- [ ] 限流规则已启用
- [ ] 防火墙已配置
- [ ] 日志轮转已配置
- [ ] 证书自动续期已设置

## 🐛 快速故障排查

| 问题 | 检查命令 | 解决方法 |
|------|---------|---------|
| 502 错误 | `curl http://127.0.0.1:8080/health` | 检查后端服务 |
| CORS 错误 | 查看浏览器控制台 | 检查 map $cors_origin |
| 证书错误 | `sudo certbot certificates` | 续期证书 |
| 配置错误 | `sudo nginx -t` | 修复语法错误 |
| 权限错误 | `ls -la /var/www/...` | 修复文件权限 |

## 📞 支持

- Nginx 文档: https://nginx.org/en/docs/
- Certbot: https://certbot.eff.org/
- SSL测试: https://www.ssllabs.com/ssltest/
