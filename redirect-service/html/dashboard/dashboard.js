// dashboard.js
// Web 管理界面交互逻辑

console.log('🎯 dashboard.js 开始加载...');

// API 基础配置 - 统一使用 V2 API
const API_BASE = '/api/v2/imagebed';  // V2 统一 API
let API_KEY = localStorage.getItem('api_key') || '';

console.log('🔑 API_KEY:', API_KEY ? '已设置' : '未设置');
console.log('🔗 API V2:', API_BASE);

// 显示 API KEY 登录界面
function showApiKeyPrompt() {
  // 创建登录遮罩层
  const loginOverlay = document.createElement('div');
  loginOverlay.id = 'login-overlay';
  loginOverlay.innerHTML = `
    <div class="login-container">
      <div class="login-box">
        <div class="login-header">
          <h2>🔐 短链管理系统</h2>
          <p>请输入 API Key 登录</p>
        </div>
        <form id="login-form" onsubmit="handleLogin(event)">
          <div class="login-form-group">
            <label for="api-key-input">API Key</label>
            <input 
              type="password" 
              id="api-key-input" 
              placeholder="请输入您的 API Key" 
              required
              autocomplete="off"
            />
          </div>
          <button type="submit" class="login-btn">登录</button>
        </form>
      </div>
    </div>
  `;
  
  document.body.appendChild(loginOverlay);
  
  // 聚焦到输入框
  setTimeout(() => {
    document.getElementById('api-key-input').focus();
  }, 100);
}

// 处理登录
function handleLogin(event) {
  event.preventDefault();
  
  const apiKey = document.getElementById('api-key-input').value.trim();
  
  if (!apiKey) {
    alert('请输入 API Key');
    return;
  }
  
  // 保存 API Key
  localStorage.setItem('api_key', apiKey);
  API_KEY = apiKey;
  
  // 移除登录界面
  const overlay = document.getElementById('login-overlay');
  if (overlay) {
    overlay.remove();
  }
  
  // 刷新页面数据
  console.log('✅ API Key 已设置，正在加载数据...');
  location.reload();
}

// 登出功能
function logout() {
  if (confirm('确定要登出吗？')) {
    localStorage.removeItem('api_key');
    location.reload();
  }
}

// 工具函数
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => document.querySelectorAll(selector);

console.log('✅ dashboard.js 工具函数加载完成');

// HTTP 请求封装
async function request(url, options = {}) {
  const headers = {
    'Content-Type': 'application/json',
    'X-API-Key': API_KEY,
    ...options.headers
  };

  try {
    const response = await fetch(url, {
      ...options,
      headers
    });

    // 检查响应是否为空或无内容
    const contentType = response.headers.get('content-type');
    let data = null;

    if (contentType && contentType.includes('application/json')) {
      const text = await response.text();
      if (text.trim()) {
        data = JSON.parse(text);
      } else {
        data = {};
      }
    } else {
      // 非JSON响应，尝试读取文本
      const text = await response.text();
      console.warn('非JSON响应:', text);
      data = { message: text || 'No response body' };
    }

    if (!response.ok) {
      throw new Error(data.error || data.message || `HTTP ${response.status}`);
    }

    return data;
  } catch (error) {
    console.error('请求失败:', error);
    showNotification(error.message, 'error');
    throw error;
  }
}

// 通知提示
function showNotification(message, type = 'info') {
  // 创建toast通知容器（如果不存在）
  let toastContainer = document.getElementById('toast-container');
  if (!toastContainer) {
    toastContainer = document.createElement('div');
    toastContainer.id = 'toast-container';
    toastContainer.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 10000;
      pointer-events: none;
    `;
    document.body.appendChild(toastContainer);
  }

  // 创建toast元素
  const toast = document.createElement('div');
  toast.style.cssText = `
    padding: 12px 20px;
    margin-bottom: 10px;
    border-radius: 6px;
    background: ${type === 'success' ? '#10b981' : type === 'error' ? '#ef4444' : '#3b82f6'};
    color: white;
    font-size: 14px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
    opacity: 0;
    transform: translateX(100%);
    transition: all 0.3s ease;
    pointer-events: auto;
    max-width: 300px;
  `;
  toast.textContent = message;

  toastContainer.appendChild(toast);

  // 显示动画
  setTimeout(() => {
    toast.style.opacity = '1';
    toast.style.transform = 'translateX(0)';
  }, 10);

  // 自动隐藏
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(100%)';
    setTimeout(() => {
      toastContainer.removeChild(toast);
    }, 300);
  }, 2000);
}

// 选项卡切换
$$('.tab-button').forEach(button => {
  button.addEventListener('click', () => {
    const tabName = button.dataset.tab;

    // 更新按钮状态
    $$('.tab-button').forEach(b => b.classList.remove('active'));
    button.classList.add('active');

    // 更新内容显示
    $$('.tab-content').forEach(content => content.classList.remove('active'));
    $(`#${tabName}-tab`).classList.add('active');

    // 加载对应数据
    loadTabData(tabName);
  });
});

// 加载选项卡数据
function loadTabData(tabName) {
  switch (tabName) {
    case 'links':
      refreshLinks();
      break;
    case 'stats':
      loadStatsOptions();
      break;
    case 'tasks':
      loadTaskStatus();
      break;
    case 'settings':
      loadSystemInfo();
      break;
  }
}

// 刷新短链列表
async function refreshLinks(page = 1) {
  const tbody = $('#links-tbody');
  tbody.innerHTML = '<tr><td colspan="7" class="loading">加载中...</td></tr>';

  try {
    const response = await request(`${API_BASE}?page=${page}&limit=20`);

    // 处理响应数据结构 { success: true, data: { links: [...], total: ... } }
    const data = response.data || response;
    const links = data.links || [];

    if (!links || links.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" class="empty-state">暂无数据</td></tr>';
      return;
    }

    tbody.innerHTML = links.map(link => {
      const isDeleted = link.status === 'deleted';
      const shortUrl = `http://localhost/${link.short_code}`;
      const actionButtons = isDeleted ? `
        <button class="btn btn-success btn-xs" onclick="restoreLink('${link.short_code}')" title="恢复">🔄</button>
        <button class="btn btn-danger btn-xs" onclick="permanentDeleteLink('${link.short_code}')" title="永久删除">🗑️</button>
      ` : `
        <button class="btn btn-secondary btn-xs" onclick="copyToClipboard('${shortUrl}')" title="复制链接">📋</button>
        <button class="btn btn-secondary btn-xs" onclick="viewLink('${link.short_code}')" title="查看详情">👁️</button>
        <button class="btn btn-secondary btn-xs" onclick="editLink('${link.short_code}')" title="编辑">✏️</button>
        <button class="btn btn-danger btn-xs" onclick="deleteLink('${link.short_code}')" title="删除">🗑️</button>
      `;

      return `
            <tr style="${isDeleted ? 'opacity: 0.6; background-color: #f5f5f5;' : ''}">
                <td>
                  <code style="cursor: pointer;" onclick="copyToClipboard('${shortUrl}')" title="点击复制完整链接">
                    ${link.short_code}
                  </code>
                </td>
                <td>${getServiceTypeDisplay(link.service_type)}</td>
                <td>${link.strategy}</td>
                <td>
                    <span class="badge badge-${getStatusBadgeClass(link.status)}">
                        ${getStatusText(link.status)}
                    </span>
                </td>
                <td>${link.visit_count || 0}</td>
                <td>${formatDate(link.created_at)}</td>
                <td style="white-space: nowrap;">
                    ${actionButtons}
                </td>
            </tr>
      `;
    }).join('');

    // 更新分页
    updatePagination(parseInt(data.total) || 0, page, 20);
  } catch (error) {
    console.error('加载短链列表失败:', error);
    tbody.innerHTML = '<tr><td colspan="7" class="empty-state">加载失败</td></tr>';
  }
}

// 服务类型显示
function getServiceTypeDisplay(serviceType) {
  const typeMap = {
    'general': '<span class="badge badge-info">通用</span>',
    'imagebed': '<span class="badge badge-primary">图床</span>',
    'file': '<span class="badge badge-warning">文件</span>',
    'video': '<span class="badge badge-success">视频</span>',
    'api': '<span class="badge badge-secondary">API</span>'
  };
  return typeMap[serviceType] || `<span class="badge">${serviceType || '未知'}</span>`;
}

// 状态样式
function getStatusBadgeClass(status) {
  const map = {
    'active': 'success',
    'inactive': 'warning',
    'expired': 'error',
    'deleted': 'error'
  };
  return map[status] || 'warning';
}

function getStatusText(status) {
  const map = {
    'active': '活跃',
    'inactive': '已禁用',
    'expired': '已过期',
    'deleted': '已删除'
  };
  return map[status] || status;
}

// 日期格式化
function formatDate(timestamp) {
  if (!timestamp) return '-';

  let date;

  // 判断是时间戳还是日期字符串
  if (typeof timestamp === 'string') {
    // 处理字符串格式的日期，如 "2025-12-06 13:31:04"
    date = new Date(timestamp.replace(' ', 'T')); // 转换为 ISO 格式
  } else if (typeof timestamp === 'number') {
    // 处理时间戳（秒或毫秒）
    // 如果是秒级时间戳（10位），需要乘以1000
    date = timestamp < 10000000000 ? new Date(timestamp * 1000) : new Date(timestamp);
  } else {
    return '-';
  }

  // 检查日期是否有效
  if (isNaN(date.getTime())) {
    console.warn('无效的日期格式:', timestamp);
    return timestamp; // 返回原始值
  }

  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
}

// 更新分页
function updatePagination(total, current, pageSize) {
  const totalPages = Math.ceil(total / pageSize);
  const pagination = $('#links-pagination');

  if (totalPages <= 1) {
    pagination.innerHTML = '';
    return;
  }

  const buttons = [];

  // 上一页
  if (current > 1) {
    buttons.push(`<button onclick="refreshLinks(${current - 1})">上一页</button>`);
  }

  // 页码
  for (let i = 1; i <= totalPages; i++) {
    if (i === 1 || i === totalPages || (i >= current - 2 && i <= current + 2)) {
      const activeClass = i === current ? 'active' : '';
      buttons.push(`<button class="${activeClass}" onclick="refreshLinks(${i})">${i}</button>`);
    } else if (i === current - 3 || i === current + 3) {
      buttons.push(`<button disabled>...</button>`);
    }
  }

  // 下一页
  if (current < totalPages) {
    buttons.push(`<button onclick="refreshLinks(${current + 1})">下一页</button>`);
  }

  pagination.innerHTML = buttons.join('');
}

// ========== 新增：多步骤表单功能 ==========
// currentStep 已在 modal-functions.js 中定义，避免重复声明

// 显示创建模态框
function showCreateModal() {
  console.log('🚀 showCreateModal 被调用');
  const modal = $('#create-modal');
  console.log('📦 模态框元素:', modal);

  modal.classList.add('show');
  resetForm();
  showStep(1);

  // 延迟绑定事件，确保 DOM 已渲染
  setTimeout(() => {
    initModalEvents();
  }, 100);
}

// 初始化模态框事件
function initModalEvents() {
  console.log('🔧 初始化模态框事件...');

  // 下一步按钮
  const nextBtn = document.getElementById('next-btn');
  console.log('➡️ 下一步按钮:', nextBtn);
  if (nextBtn) {
    // 移除所有旧的事件监听器
    const newBtn = nextBtn.cloneNode(true);
    nextBtn.parentNode.replaceChild(newBtn, nextBtn);

    newBtn.onclick = function (e) {
      console.log('➡️ 点击下一步');
      e.preventDefault();
      e.stopPropagation();
      nextStep();
      return false;
    };
    console.log('✅ 下一步按钮事件已绑定');
  }

  // 上一步按钮
  const prevBtn = document.getElementById('prev-btn');
  console.log('⬅️ 上一步按钮:', prevBtn);
  if (prevBtn) {
    // 移除所有旧的事件监听器
    const newBtn = prevBtn.cloneNode(true);
    prevBtn.parentNode.replaceChild(newBtn, prevBtn);

    newBtn.onclick = function (e) {
      console.log('⬅️ 点击上一步');
      e.preventDefault();
      e.stopPropagation();
      prevStep();
      return false;
    };
    console.log('✅ 上一步按钮事件已绑定');
  }

  // 关闭按钮
  const closeBtn = document.getElementById('close-create-modal-btn');
  console.log('❌ 关闭按钮:', closeBtn);
  if (closeBtn) {
    closeBtn.onclick = function (e) {
      console.log('❌ 点击关闭');
      e.preventDefault();
      e.stopPropagation();
      closeModal('create-modal');
      return false;
    };
  }

  // 服务类型选择
  const serviceSelect = document.getElementById('service_type');
  if (serviceSelect) {
    serviceSelect.onchange = updateServiceHelp;
  }

  console.log('✅ 事件监听器绑定完成');
}

console.log('✅ 模态框事件初始化完成');

// 重置表单
function resetForm() {
  currentStep = 1;
  $('#create-form').reset();
}

// 显示指定步骤
function showStep(step) {
  currentStep = step;

  // 更新步骤指示器
  document.querySelectorAll('.step').forEach((el, index) => {
    el.classList.remove('active', 'completed');
    if (index + 1 === step) {
      el.classList.add('active');
    } else if (index + 1 < step) {
      el.classList.add('completed');
    }
  });

  // 更新表单步骤
  document.querySelectorAll('.form-step').forEach((el, index) => {
    el.classList.remove('active');
    if (index + 1 === step) {
      el.classList.add('active');
    }
  });

  // 更新按钮显示
  $('#prev-btn').style.display = step > 1 ? 'inline-block' : 'none';
  $('#next-btn').style.display = step < totalSteps ? 'inline-block' : 'none';
  $('#submit-btn').style.display = step === totalSteps ? 'inline-block' : 'none';
}

// 下一步
function nextStep() {
  console.log('📝 nextStep 被调用, 当前步骤:', currentStep);
  if (validateCurrentStep()) {
    showStep(currentStep + 1);
  }
}

// 上一步
function prevStep() {
  console.log('📝 prevStep 被调用, 当前步骤:', currentStep);
  showStep(currentStep - 1);
}

// 验证当前步骤
function validateCurrentStep() {
  const step = currentStep;

  if (step === 1) {
    const serviceType = $('#service_type').value;
    if (!serviceType) {
      showNotification('请选择服务类型', 'warning');
      return false;
    }
  }

  if (step === 2) {
    const serviceType = $('#service_type').value;

    if (serviceType === 'general') {
      // 通用类型：验证URL
      const url = $('#target_url').value.trim();
      if (!url) {
        showNotification('请输入目标URL', 'warning');
        return false;
      }
      try {
        new URL(url); // 验证URL格式
      } catch {
        showNotification('请输入有效的URL（如：https://www.baidu.com）', 'warning');
        return false;
      }
    } else {
      // 其他类型：验证路径
      const path = $('#target_path').value.trim();
      if (!path) {
        showNotification('请输入资源路径', 'warning');
        return false;
      }
    }
  }

  return true;
}

// 更新服务类型帮助
function updateServiceHelp() {
  const serviceType = $('#service_type').value;
  const helpText = $('#service-help');

  const helps = {
    imagebed: '用于图床服务，支持多CDN加速和智能分流',
    general: '通用短链服务，适合各种URL跳转场景',
    file: '用于文件分享，支持大文件和断点续传',
    video: '视频服务专用，支持流媒体优化'
  };

  helpText.textContent = helps[serviceType] || '选择短链的用途类型';
}

// 复制到剪贴板
function copyToClipboard(text) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(() => {
      showNotification('✅ 已复制到剪贴板', 'success');
    }).catch(err => {
      console.error('复制失败:', err);
      fallbackCopyToClipboard(text);
    });
  } else {
    fallbackCopyToClipboard(text);
  }
}

// 降级复制方案
function fallbackCopyToClipboard(text) {
  const textArea = document.createElement('textarea');
  textArea.value = text;
  textArea.style.position = 'fixed';
  textArea.style.left = '-999999px';
  document.body.appendChild(textArea);
  textArea.focus();
  textArea.select();

  try {
    document.execCommand('copy');
    showNotification('✅ 已复制到剪贴板', 'success');
  } catch (err) {
    showNotification('❌ 复制失败，请手动复制', 'error');
  }

  document.body.removeChild(textArea);
}

function closeModal(modalId) {
  $(`#${modalId}`).classList.remove('show');
}

// 提交创建表单
$('#create-form').addEventListener('submit', async (e) => {
  e.preventDefault();

  // 获取表单数据
  const serviceType = $('#service_type').value || 'general';
  const enableCache = $('#enable_cache').checked;
  const expiresAt = $('#expires_at').value;
  const description = $('#description').value.trim();

  // 根据服务类型构建 targets
  let targets;

  if (serviceType === 'general') {
    // 通用类型：使用完整URL
    const url = $('#target_url').value.trim();
    if (!url) {
      showNotification('请输入目标URL', 'warning');
      return;
    }

    try {
      new URL(url); // 验证URL格式
      targets = [{
        url: url,
        weight: 1
      }];
    } catch (error) {
      showNotification('URL格式不正确，请输入完整URL（如：https://www.baidu.com）', 'error');
      return;
    }
  } else {
    // 其他类型：使用路径，CDN由后端处理
    const path = $('#target_path').value.trim();
    if (!path) {
      showNotification('请输入资源路径', 'warning');
      return;
    }

    // 确保路径以/开头
    const normalizedPath = path.startsWith('/') ? path : '/' + path;

    targets = [{
      path: normalizedPath,
      weight: 1
    }];
  }

  const data = {
    service_type: serviceType,
    targets: targets,
    strategy: 'weight', // 固定使用权重策略
    security_config: {
      enable_cache: enableCache
    }
  };

  if (description) {
    data.description = description;
  }

  if (expiresAt) {
    data.expires_at = new Date(expiresAt).toISOString();
  }

  try {
    const result = await request(`${API_BASE}`, {
      method: 'POST',
      body: JSON.stringify(data)
    });

    showNotification(`✅ 创建成功！短链码: ${result.data.short_code}`, 'success', 5000);
    closeModal('create-modal');
    refreshLinks();
  } catch (error) {
    // 错误已在 request 中处理
  }
});

// 加载统计选项
async function loadStatsOptions() {
  try {
    const response = await request(`${API_BASE}?limit=1000`);
    const data = response.data || response;
    const links = data.links || [];
    const select = $('#stats-link-select');

    select.innerHTML = '<option value="">选择短链...</option>' +
      links.map(link => `
                <option value="${link.short_code}">${link.short_code}</option>
            `).join('');
  } catch (error) {
    // 错误已处理
  }
}

// 加载统计数据
async function loadStats() {
  const shortCode = $('#stats-link-select').value;
  const days = $('#stats-period').value;

  if (!shortCode) {
    showNotification('请选择短链', 'warning');
    return;
  }

  const container = $('#stats-content');
  container.innerHTML = '<div class="loading">加载中...</div>';

  try {
    const data = await request(`${API_BASE}/stats/${shortCode}/dashboard?days=${days}`);

    container.innerHTML = `
            <div class="stats-grid">
                <div class="stat-card">
                    <h3>总访问量</h3>
                    <div class="value">${data.total.total_visits || 0}</div>
                </div>
                <div class="stat-card">
                    <h3>独立访客</h3>
                    <div class="value">${data.total.unique_visitors || 0}</div>
                </div>
                <div class="stat-card">
                    <h3>平均响应时间</h3>
                    <div class="value">${(data.total.avg_response_time || 0).toFixed(2)}ms</div>
                </div>
                <div class="stat-card">
                    <h3>今日访问</h3>
                    <div class="value">${data.today.visits_today || 0}</div>
                </div>
            </div>

            <div class="chart-container">
                <h3>访问趋势</h3>
                <canvas id="trend-chart"></canvas>
            </div>

            <div class="chart-container">
                <h3>地区分布 Top 5</h3>
                <table>
                    <thead>
                        <tr>
                            <th>国家</th>
                            <th>省份</th>
                            <th>访问量</th>
                            <th>独立访客</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${(data.top_regions || []).map(region => `
                            <tr>
                                <td>${region.country || '-'}</td>
                                <td>${region.province || '-'}</td>
                                <td>${region.visit_count}</td>
                                <td>${region.unique_visitors}</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>

            <div class="chart-container">
                <h3>设备类型分布</h3>
                <table>
                    <thead>
                        <tr>
                            <th>设备类型</th>
                            <th>访问量</th>
                            <th>平均响应时间</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${(data.device_distribution || []).map(device => `
                            <tr>
                                <td>${device.device_type}</td>
                                <td>${device.visit_count}</td>
                                <td>${(device.avg_response_time || 0).toFixed(2)}ms</td>
                            </tr>
                        `).join('')}
                    </tbody>
                </table>
            </div>
        `;
  } catch (error) {
    container.innerHTML = '<div class="empty-state">加载失败</div>';
  }
}

// 导出统计数据
async function exportStats() {
  const shortCode = $('#stats-link-select').value;

  if (!shortCode) {
    showNotification('请选择短链', 'warning');
    return;
  }

  const startTime = Math.floor(Date.now() / 1000) - (30 * 24 * 3600);
  const endTime = Math.floor(Date.now() / 1000);

  try {
    const response = await fetch(
      `${API_BASE}/stats/${shortCode}/export?start=${startTime}&end=${endTime}&format=csv`,
      {
        headers: { 'X-API-Key': API_KEY }
      }
    );

    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `stats_${shortCode}_${Date.now()}.csv`;
    a.click();

    showNotification('导出成功', 'success');
  } catch (error) {
    showNotification('导出失败', 'error');
  }
}

// 加载定时任务状态
async function loadTaskStatus() {
  const tbody = $('#tasks-tbody');
  tbody.innerHTML = '<tr><td colspan="5" class="loading">加载中...</td></tr>';

  try {
    const data = await request(`${API_BASE}/tasks/status`);

    tbody.innerHTML = data.tasks.map(task => `
            <tr>
                <td>${task.name}</td>
                <td>${formatInterval(task.interval)}</td>
                <td>${formatDate(task.last_run)}</td>
                <td>${formatDate(task.next_run)}</td>
                <td>
                    <button class="btn btn-secondary" onclick="triggerTask('${task.name}')">立即执行</button>
                </td>
            </tr>
        `).join('');
  } catch (error) {
    tbody.innerHTML = '<tr><td colspan="5" class="empty-state">加载失败</td></tr>';
  }
}

// 格式化时间间隔
function formatInterval(seconds) {
  if (seconds >= 86400) {
    return `${Math.floor(seconds / 86400)} 天`;
  } else if (seconds >= 3600) {
    return `${Math.floor(seconds / 3600)} 小时`;
  } else {
    return `${Math.floor(seconds / 60)} 分钟`;
  }
}

// 触发任务
async function triggerTask(taskName) {
  if (!confirm(`确定要立即执行任务 "${taskName}" 吗？`)) {
    return;
  }

  try {
    await request(`${API_BASE}/tasks/trigger`, {
      method: 'POST',
      body: JSON.stringify({ task_name: taskName })
    });

    showNotification('任务已触发', 'success');
    loadTaskStatus();
  } catch (error) {
    // 错误已处理
  }
}

// 加载系统信息
async function loadSystemInfo() {
  const container = $('#system-info');
  container.innerHTML = '<div class="loading">加载中...</div>';

  try {
    const data = await request('/health');

    container.innerHTML = `
            <table>
                <tr>
                    <td><strong>系统状态</strong></td>
                    <td><span class="badge badge-${data.status === 'healthy' ? 'success' : 'error'}">${data.status}</span></td>
                </tr>
                <tr>
                    <td><strong>运行时间</strong></td>
                    <td>${formatInterval(data.uptime)}</td>
                </tr>
                <tr>
                    <td><strong>Redis 状态</strong></td>
                    <td><span class="badge badge-${data.checks.redis.status === 'healthy' ? 'success' : 'error'}">${data.checks.redis.status}</span></td>
                </tr>
                <tr>
                    <td><strong>MySQL 状态</strong></td>
                    <td><span class="badge badge-${data.checks.mysql.status === 'healthy' ? 'success' : 'error'}">${data.checks.mysql.status}</span></td>
                </tr>
                <tr>
                    <td><strong>内存状态</strong></td>
                    <td><span class="badge badge-${data.checks.memory.status === 'healthy' ? 'success' : 'error'}">${data.checks.memory.status}</span></td>
                </tr>
            </table>
        `;
  } catch (error) {
    container.innerHTML = '<div class="empty-state">加载失败</div>';
  }
}

// 加载首页统计
async function loadDashboardStats() {
  try {
    // 加载总体统计 - 使用 V2 API 统计接口
    const response = await request(`${API_BASE}/stats/overview`);
    const statsData = response.data || response;

    $('#total-links').textContent = statsData.total_links || 0;
    $('#total-visits').textContent = (parseInt(statsData.total_visits) || 0).toLocaleString();
    $('#unique-visitors').textContent = (parseInt(statsData.unique_visitors) || 0).toLocaleString();

    // 如果有今日访问数据
    if ($('#today-visits')) {
      $('#today-visits').textContent = (parseInt(statsData.today_visits) || 0).toLocaleString();
    }
  } catch (error) {
    console.error('加载统计失败:', error);
    // 显示默认值
    $('#total-links').textContent = '-';
    $('#total-visits').textContent = '-';
    $('#unique-visitors').textContent = '-';
  }
}

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', () => {
  // 检查 API Key
  if (!API_KEY) {
    console.log('⚠️ 未找到 API Key，显示登录界面');
    showApiKeyPrompt();
    return;
  }

  // 加载初始数据
  loadDashboardStats();
  refreshLinks();

  // 定时刷新统计
  setInterval(loadDashboardStats, 30000);  // 每30秒刷新一次
});

// 更新 API Key 显示状态
function updateApiKeyDisplay() {
  const displayEl = $('#api-key-display');
  if (displayEl) {
    if (API_KEY) {
      const maskedKey = API_KEY.substring(0, 8) + '...' + API_KEY.substring(API_KEY.length - 4);
      displayEl.textContent = maskedKey;
      displayEl.style.color = '#52c41a';
    } else {
      displayEl.textContent = '未设置';
      displayEl.style.color = '#ff4d4f';
    }
  }
}

// 搜索功能
$('#search-input').addEventListener('input', debounce((e) => {
  filterLinks();
}, 300));

// 服务类型筛选
$('#service-type-filter').addEventListener('change', () => {
  filterLinks();
});

// 状态筛选
$('#status-filter').addEventListener('change', () => {
  filterLinks();
});

// 综合筛选函数
function filterLinks() {
  const keyword = $('#search-input').value.toLowerCase();
  const serviceType = $('#service-type-filter').value;
  const status = $('#status-filter').value;
  const rows = $$('#links-tbody tr');

  rows.forEach(row => {
    // 跳过加载中和空状态行
    if (row.cells.length === 1) {
      return;
    }

    const text = row.textContent.toLowerCase();
    const typeCell = row.cells[1]; // 类型列
    const statusCell = row.cells[3]; // 状态列

    // 检查搜索关键词
    const matchKeyword = !keyword || text.includes(keyword);

    // 检查服务类型
    let matchType = true;
    if (serviceType) {
      const typeText = typeCell.textContent.toLowerCase();
      const typeMap = {
        'general': '通用',
        'imagebed': '图床',
        'file': '文件',
        'video': '视频',
        'api': 'api'
      };
      matchType = typeText.includes(typeMap[serviceType].toLowerCase());
    }

    // 检查状态
    let matchStatus = true;
    if (status) {
      const statusText = statusCell.textContent.toLowerCase();
      const statusMap = {
        'active': '活跃',
        'inactive': '已禁用',
        'deleted': '已删除',
        'expired': '已过期'
      };
      matchStatus = statusText.includes(statusMap[status].toLowerCase());
    }

    row.style.display = (matchKeyword && matchType && matchStatus) ? '' : 'none';
  });
}

// 防抖函数
function debounce(func, wait) {
  let timeout;
  return function (...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(this, args), wait);
  };
}

// 批量操作相关函数
function showBatchCreateModal() {
  showNotification('批量创建功能开发中', 'info');
}

function showBatchUpdateModal() {
  showNotification('批量更新功能开发中', 'info');
}

function showBatchDeleteModal() {
  showNotification('批量删除功能开发中', 'info');
}

function showCreateApiKeyModal() {
  showNotification('API Key 创建功能请使用命令行工具', 'info');
}

function loadApiKeys() {
  showNotification('请使用命令行工具管理 API Key', 'info');
}

// 查看、编辑、删除短链
async function viewLink(shortCode) {
  const modal = $('#view-modal');
  const content = $('#view-modal-content');

  modal.classList.add('show');
  content.innerHTML = '<div class="loading">加载中...</div>';

  try {
    const response = await request(`${API_BASE}/${shortCode}`);
    const link = response.data || response;

    content.innerHTML = `
      <div style="display: grid; gap: 20px;">
        <div class="info-section">
          <h3 style="border-bottom: 2px solid #1890ff; padding-bottom: 10px; margin-bottom: 15px;">基本信息</h3>
          <div class="info-grid">
            <div class="info-item">
              <label>短链代码:</label>
              <div><code style="background: #f5f5f5; padding: 5px 10px; border-radius: 4px;">${link.short_code}</code></div>
            </div>
            <div class="info-item">
              <label>服务类型:</label>
              <div>${getServiceTypeDisplay(link.service_type)}</div>
            </div>
            <div class="info-item">
              <label>状态:</label>
              <div><span class="badge badge-${getStatusBadgeClass(link.status)}">${getStatusText(link.status)}</span></div>
            </div>
            <div class="info-item">
              <label>分流策略:</label>
              <div>${link.strategy}</div>
            </div>
            <div class="info-item">
              <label>描述:</label>
              <div>${link.description || '-'}</div>
            </div>
          </div>
        </div>

        <div class="info-section">
          <h3 style="border-bottom: 2px solid #52c41a; padding-bottom: 10px; margin-bottom: 15px;">访问统计</h3>
          <div class="info-grid">
            <div class="info-item">
              <label>总访问量:</label>
              <div><strong style="color: #1890ff; font-size: 18px;">${(link.visit_count || 0).toLocaleString()}</strong></div>
            </div>
            <div class="info-item">
              <label>创建时间:</label>
              <div>${formatDate(link.created_at)}</div>
            </div>
            <div class="info-item">
              <label>更新时间:</label>
              <div>${formatDate(link.updated_at)}</div>
            </div>
            ${link.expire_at ? `
            <div class="info-item">
              <label>过期时间:</label>
              <div>${formatDate(link.expire_at)}</div>
            </div>
            ` : ''}
          </div>
        </div>

        <div class="info-section">
          <h3 style="border-bottom: 2px solid #faad14; padding-bottom: 10px; margin-bottom: 15px;">目标配置</h3>
          <pre style="background: #f5f5f5; padding: 15px; border-radius: 4px; overflow-x: auto;">${JSON.stringify(link.targets, null, 2)}</pre>
        </div>

        <div class="info-section">
          <h3 style="border-bottom: 2px solid #722ed1; padding-bottom: 10px; margin-bottom: 15px;">访问链接</h3>
          <div style="background: #f0f5ff; padding: 15px; border-radius: 4px;">
            <div style="margin-bottom: 10px;">
              <strong>完整URL:</strong><br>
              <a href="http://localhost/${link.short_code}" target="_blank" style="color: #1890ff; word-break: break-all;">
                http://localhost/${link.short_code}
              </a>
            </div>
            <button class="btn btn-secondary" onclick="copyToClipboard('http://localhost/${link.short_code}')">📋 复制链接</button>
          </div>
        </div>
      </div>
    `;
  } catch (error) {
    content.innerHTML = `<div class="empty-state" style="color: #ff4d4f;">加载失败: ${error.message}</div>`;
  }
}

async function editLink(shortCode) {
  const modal = $('#edit-modal');
  modal.classList.add('show');

  try {
    const response = await request(`${API_BASE}/${shortCode}`);
    const link = response.data || response;

    // 填充表单
    $('#edit_short_code').value = link.short_code;
    $('#edit_service_type').value = link.service_type || 'general';
    $('#edit_description').value = link.description || '';
    $('#edit_targets').value = JSON.stringify(link.targets, null, 2);
    $('#edit_strategy').value = link.strategy;
    $('#edit_status').value = link.status;

  } catch (error) {
    showNotification('加载短链信息失败', 'error');
    closeModal('edit-modal');
  }
}

// 编辑表单提交
$('#edit-form').addEventListener('submit', async (e) => {
  e.preventDefault();

  const shortCode = $('#edit_short_code').value;
  const serviceType = $('#edit_service_type').value;
  const strategy = $('#edit_strategy').value;
  const status = $('#edit_status').value;

  let targets;
  try {
    targets = JSON.parse($('#edit_targets').value);
    if (!Array.isArray(targets) || targets.length === 0) {
      showNotification('目标配置必须是非空数组', 'warning');
      return;
    }
  } catch (error) {
    showNotification('目标配置格式错误', 'error');
    return;
  }

  const data = {
    service_type: serviceType,
    targets: targets,
    strategy: strategy,
    status: status
  };

  try {
    await request(`${API_BASE}/${shortCode}`, {
      method: 'PUT',
      body: JSON.stringify(data)
    });

    showNotification('✅ 更新成功', 'success');
    closeModal('edit-modal');
    refreshLinks();
  } catch (error) {
    // 错误已处理
  }
});

async function deleteLink(shortCode) {
  const confirmMsg = `确定要删除短链 "${shortCode}" 吗？

注意：这是软删除，短链将被标记为"已删除"状态，
但数据仍会保留，您可以稍后恢复。

如需永久删除，请使用批量操作功能。`;

  if (!confirm(confirmMsg)) {
    return;
  }

  try {
    await request(`${API_BASE}/${shortCode}`, {
      method: 'DELETE'
    });

    showNotification('✅ 短链已标记为删除状态', 'success');
    refreshLinks();
  } catch (error) {
    // 错误已处理
  }
}

// 恢复已删除的短链
async function restoreLink(shortCode) {
  if (!confirm(`确定要恢复短链 "${shortCode}" 吗？`)) {
    return;
  }

  try {
    // 通过更新状态为 active 来恢复
    await request(`${API_BASE}/${shortCode}`, {
      method: 'PUT',
      body: JSON.stringify({
        status: 'active'
      })
    });

    showNotification('✅ 短链已恢复', 'success');
    refreshLinks();
  } catch (error) {
    // 错误已处理
  }
}

// 永久删除短链
async function permanentDeleteLink(shortCode) {
  const confirmMsg = `⚠️ 警告：永久删除操作！

确定要永久删除短链 "${shortCode}" 吗？

此操作将：
- 从数据库中完全删除该记录
- 删除所有相关的统计数据
- 无法恢复

请谨慎操作！`;

  if (!confirm(confirmMsg)) {
    return;
  }

  // 二次确认
  if (!confirm('最后确认：真的要永久删除吗？此操作不可撤销！')) {
    return;
  }

  try {
    // 使用 permanent=true 参数进行硬删除
    await request(`${API_BASE}/${shortCode}?permanent=true`, {
      method: 'DELETE'
    });

    showNotification('✅ 短链已永久删除', 'success');
    refreshLinks();
  } catch (error) {
    // 错误已处理
  }
}

// 确认所有函数已加载
console.log('✅ 所有函数定义完成');
console.log('✅ generateRandomCode:', typeof generateRandomCode);
console.log('✅ nextStep:', typeof nextStep);
console.log('✅ prevStep:', typeof prevStep);
console.log('✅ showCreateModal:', typeof showCreateModal);
