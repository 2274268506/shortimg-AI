// dashboard.js
// Web 管理界面交互逻辑

// API 基础配置
const API_BASE = '/api/v1';
const API_KEY = localStorage.getItem('api_key') || '';

// 工具函数
const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => document.querySelectorAll(selector);

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

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || `HTTP ${response.status}`);
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
  // 简单实现，可替换为更好的通知组件
  alert(`[${type.toUpperCase()}] ${message}`);
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
  tbody.innerHTML = '<tr><td colspan="6" class="loading">加载中...</td></tr>';

  try {
    const data = await request(`${API_BASE}/links?page=${page}&limit=20`);

    if (!data.links || data.links.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="empty-state">暂无数据</td></tr>';
      return;
    }

    tbody.innerHTML = data.links.map(link => `
            <tr>
                <td><code>${link.short_code}</code></td>
                <td>${link.strategy}</td>
                <td>
                    <span class="badge badge-${getStatusBadgeClass(link.status)}">
                        ${getStatusText(link.status)}
                    </span>
                </td>
                <td>${link.visit_count || 0}</td>
                <td>${formatDate(link.created_at)}</td>
                <td>
                    <button class="btn btn-secondary" onclick="viewLink('${link.short_code}')">查看</button>
                    <button class="btn btn-secondary" onclick="editLink('${link.short_code}')">编辑</button>
                    <button class="btn btn-danger" onclick="deleteLink('${link.short_code}')">删除</button>
                </td>
            </tr>
        `).join('');

    // 更新分页
    updatePagination(data.total, page, 20);
  } catch (error) {
    tbody.innerHTML = '<tr><td colspan="6" class="empty-state">加载失败</td></tr>';
  }
}

// 状态样式
function getStatusBadgeClass(status) {
  const map = {
    'active': 'success',
    'inactive': 'warning',
    'expired': 'error'
  };
  return map[status] || 'warning';
}

function getStatusText(status) {
  const map = {
    'active': '活跃',
    'inactive': '已禁用',
    'expired': '已过期'
  };
  return map[status] || status;
}

// 日期格式化
function formatDate(timestamp) {
  if (!timestamp) return '-';
  const date = new Date(timestamp * 1000);
  return date.toLocaleString('zh-CN');
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

// 显示创建模态框
function showCreateModal() {
  $('#create-modal').classList.add('show');
}

// 关闭模态框
function closeModal(modalId) {
  $(`#${modalId}`).classList.remove('show');
}

// 提交创建表单
$('#create-form').addEventListener('submit', async (e) => {
  e.preventDefault();

  const formData = new FormData(e.target);
  const data = {
    short_code: formData.get('short_code'),
    targets: JSON.parse(formData.get('targets')),
    strategy: formData.get('strategy'),
    security_config: {}
  };

  try {
    await request(`${API_BASE}/links`, {
      method: 'POST',
      body: JSON.stringify(data)
    });

    showNotification('创建成功', 'success');
    closeModal('create-modal');
    refreshLinks();
  } catch (error) {
    // 错误已在 request 中处理
  }
});

// 加载统计选项
async function loadStatsOptions() {
  try {
    const data = await request(`${API_BASE}/links?limit=1000`);
    const select = $('#stats-link-select');

    select.innerHTML = '<option value="">选择短链...</option>' +
      data.links.map(link => `
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
    // 加载总体统计
    const statsData = await request(`${API_BASE}/stats/overview`);

    $('#total-links').textContent = statsData.total_links || 0;
    $('#total-visits').textContent = (statsData.total_visits || 0).toLocaleString();
    $('#unique-visitors').textContent = (statsData.unique_visitors || 0).toLocaleString();
    $('#today-visits').textContent = (statsData.today_visits || 0).toLocaleString();
  } catch (error) {
    console.error('加载统计失败:', error);
  }
}

// 页面加载完成后初始化
document.addEventListener('DOMContentLoaded', () => {
  // 检查 API Key
  if (!API_KEY) {
    const key = prompt('请输入 API Key:');
    if (key) {
      localStorage.setItem('api_key', key);
      location.reload();
    } else {
      showNotification('需要 API Key 才能使用', 'error');
      return;
    }
  }

  // 加载初始数据
  loadDashboardStats();
  refreshLinks();

  // 定时刷新统计
  setInterval(loadDashboardStats, 30000);  // 每30秒刷新一次
});

// 搜索功能
$('#search-input').addEventListener('input', debounce((e) => {
  const keyword = e.target.value.toLowerCase();
  const rows = $$('#links-tbody tr');

  rows.forEach(row => {
    const text = row.textContent.toLowerCase();
    row.style.display = text.includes(keyword) ? '' : 'none';
  });
}, 300));

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
function viewLink(shortCode) {
  showNotification(`查看短链: ${shortCode}（开发中）`, 'info');
}

function editLink(shortCode) {
  showNotification(`编辑短链: ${shortCode}（开发中）`, 'info');
}

async function deleteLink(shortCode) {
  if (!confirm(`确定要删除短链 "${shortCode}" 吗？此操作不可撤销！`)) {
    return;
  }

  try {
    await request(`${API_BASE}/links/${shortCode}`, {
      method: 'DELETE'
    });

    showNotification('删除成功', 'success');
    refreshLinks();
  } catch (error) {
    // 错误已处理
  }
}
