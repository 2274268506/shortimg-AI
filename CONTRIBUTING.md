# 贡献指南

感谢你考虑为 TC-GO 图床系统做出贡献！

## 📋 目录

- [开发环境搭建](#开发环境搭建)
- [代码规范](#代码规范)
- [提交规范](#提交规范)
- [Pull Request 流程](#pull-request-流程)
- [问题报告](#问题报告)

## 🛠️ 开发环境搭建

### 前置要求

- Go 1.24+
- Node.js 18+
- Git 2.30+
- Make (可选)

### 克隆仓库

```bash
git clone https://github.com/your-username/TC-GO.git
cd TC-GO
```

### 安装依赖

```bash
# 使用 Makefile
make install

# 或手动安装
cd backend && go mod download
cd frontend && npm install
```

### 启动开发服务器

```bash
# 使用 Makefile
make dev

# 或分别启动
# 终端 1 - 后端
cd backend && go run main.go

# 终端 2 - 前端
cd frontend && npm run dev
```

## 📝 代码规范

### Go 代码规范

- 使用 `gofmt` 格式化代码
- 使用 `golangci-lint` 检查代码
- 遵循 [Effective Go](https://golang.org/doc/effective_go) 指南
- 导出的函数和类型必须有注释

示例：
```go
// GetImageByID 根据ID获取图片信息
// 参数:
//   - id: 图片ID
// 返回:
//   - *models.Image: 图片对象
//   - error: 错误信息
func GetImageByID(id uint) (*models.Image, error) {
    var image models.Image
    if err := db.First(&image, id).Error; err != nil {
        return nil, err
    }
    return &image, nil
}
```

### Vue/TypeScript 代码规范

- 使用 ESLint + Prettier
- 遵循 [Vue 风格指南](https://vuejs.org/style-guide/)
- 组件名使用 PascalCase
- Props 和 emits 必须有类型定义

示例：
```vue
<script setup lang="ts">
import { ref, computed } from 'vue'

interface Props {
  imageId: number
  showActions?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  showActions: true
})

const emit = defineEmits<{
  delete: [id: number]
  edit: [id: number]
}>()
</script>
```

### 命名规范

#### Go
- 包名：小写，单个单词 (如 `models`, `utils`)
- 文件名：小写+下划线 (如 `image_controller.go`)
- 变量：驼峰命名 (如 `imageList`, `userID`)
- 常量：全大写+下划线 (如 `MAX_FILE_SIZE`)

#### TypeScript
- 文件名：小写+连字符 (如 `image-grid.vue`)
- 变量/函数：驼峰命名 (如 `imageList`, `handleUpload`)
- 接口/类型：PascalCase (如 `ImageData`, `UserInfo`)
- 常量：全大写+下划线 (如 `MAX_FILE_SIZE`)

## 🔖 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type 类型

| Emoji | Type | 说明 |
|-------|------|------|
| ✨ | `feat` | 新功能 |
| 🐛 | `fix` | Bug 修复 |
| 📝 | `docs` | 文档更新 |
| 🎨 | `style` | 代码格式/样式 |
| ♻️ | `refactor` | 重构 |
| ⚡ | `perf` | 性能优化 |
| 🧪 | `test` | 测试相关 |
| 🔧 | `chore` | 构建/配置 |
| 🔒 | `security` | 安全修复 |

### 示例

```bash
git commit -m "✨ feat(image): 添加图片批量下载功能"
git commit -m "🐛 fix(auth): 修复 JWT 过期时间计算错误"
git commit -m "📝 docs(api): 更新 API 文档"
git commit -m "⚡ perf(cache): 优化图片缓存策略"
```

## 🔀 Pull Request 流程

### 1. Fork 仓库

点击右上角的 Fork 按钮

### 2. 创建分支

```bash
git checkout -b feature/your-feature-name
# 或
git checkout -b fix/your-bug-fix
```

分支命名规范：
- `feature/xxx` - 新功能
- `fix/xxx` - Bug 修复
- `docs/xxx` - 文档更新
- `refactor/xxx` - 重构

### 3. 开发并提交

```bash
# 开发你的功能
# ...

# 运行测试
make test

# 格式化代码
make format

# 提交代码
git add .
git commit -m "✨ feat: 添加新功能"
```

### 4. 推送到 Fork 仓库

```bash
git push origin feature/your-feature-name
```

### 5. 创建 Pull Request

在 GitHub 上创建 PR，并填写：

**PR 标题**：使用提交规范格式
```
✨ feat(image): 添加图片批量下载功能
```

**PR 描述模板**：
```markdown
## 📝 变更说明
简要描述此 PR 的目的和改动内容

## 🔗 相关 Issue
Closes #123

## ✅ 变更类型
- [ ] 新功能
- [ ] Bug 修复
- [ ] 文档更新
- [ ] 性能优化
- [ ] 重构
- [ ] 其他

## 🧪 测试
- [ ] 添加了单元测试
- [ ] 添加了集成测试
- [ ] 手动测试通过

## 📸 截图（如适用）
添加截图说明变更

## 📋 检查清单
- [ ] 代码遵循项目规范
- [ ] 已运行测试并通过
- [ ] 已更新相关文档
- [ ] 已添加必要的注释
- [ ] 无破坏性变更
```

### 6. 代码审查

- 维护者会审查你的代码
- 根据反馈进行修改
- 修改后推送到同一分支

### 7. 合并

- 审查通过后会被合并到主分支
- 记得删除你的功能分支

## 🐛 问题报告

### 提交 Bug

使用 [Bug 报告模板]：

```markdown
## 🐛 Bug 描述
简要描述遇到的问题

## 📋 复现步骤
1. 进入 '...'
2. 点击 '...'
3. 滚动到 '...'
4. 看到错误

## 🎯 期望行为
描述你期望发生什么

## 📸 截图
如果适用，添加截图帮助说明问题

## 💻 环境信息
- OS: [e.g. Windows 11, macOS 14]
- 浏览器: [e.g. Chrome 120, Firefox 121]
- 版本: [e.g. v1.0.0]

## 📝 额外信息
其他相关信息
```

### 功能请求

使用 [功能请求模板]：

```markdown
## ✨ 功能描述
清晰描述你想要的功能

## 🎯 使用场景
描述为什么需要这个功能

## 💡 建议的实现方式
如果有想法，可以描述如何实现

## 📋 替代方案
是否考虑过其他替代方案？

## 📝 额外信息
其他相关信息
```

## 🧪 测试

### 运行测试

```bash
# 所有测试
make test

# 只测试后端
make test-backend

# 只测试前端
make test-frontend

# 查看覆盖率
make test-coverage
```

### 编写测试

#### Go 单元测试
```go
// controllers/image_controller_test.go
func TestUploadImage(t *testing.T) {
    // 设置测试环境
    gin.SetMode(gin.TestMode)
    
    // 创建测试数据
    // ...
    
    // 执行测试
    // ...
    
    // 断言结果
    assert.Equal(t, 200, w.Code)
}
```

#### Vue 组件测试
```typescript
// components/__tests__/ImageCard.spec.ts
import { mount } from '@vue/test-utils'
import ImageCard from '../ImageCard.vue'

describe('ImageCard', () => {
  it('renders image correctly', () => {
    const wrapper = mount(ImageCard, {
      props: {
        image: { id: 1, url: 'test.jpg' }
      }
    })
    expect(wrapper.find('img').exists()).toBe(true)
  })
})
```

## 📚 文档

### 更新文档

- API 变更：更新 Swagger 注释
- 功能变更：更新 README.md
- 配置变更：更新 .env.example

### 生成 API 文档

```bash
make swagger
```

访问: http://localhost:8080/swagger/index.html

## 🎓 学习资源

- [Go 官方文档](https://golang.org/doc/)
- [Vue 3 文档](https://vuejs.org/)
- [Element Plus 组件库](https://element-plus.org/)
- [TypeScript 手册](https://www.typescriptlang.org/docs/)

## 🤝 行为准则

- 尊重所有贡献者
- 接受建设性批评
- 专注于对社区最有利的事情
- 展现同理心

## 📞 联系方式

- 提交 Issue: [GitHub Issues](https://github.com/your-username/TC-GO/issues)
- 讨论: [GitHub Discussions](https://github.com/your-username/TC-GO/discussions)

---

再次感谢你的贡献！ 🎉
