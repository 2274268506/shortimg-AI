// 短链管理系统 - 增强功能模块
// 文件: html/dashboard/enhanced-features.js
// 功能: 批量操作、高级搜索、导入导出等

console.log('🚀 enhanced-features.js 加载中...');

// ========================================
// 全局变量
// ========================================

let selectedLinks = new Set();  // 选中的短链
let batchMode = false;  // 批量模式开关
let searchFilters = {};  // 当前搜索条件

// ========================================
// 批量选择功能
// ========================================

// 切换批量模式
function toggleBatchMode() {
  batchMode = !batchMode;
  selectedLinks.clear();
  
  const checkboxes = document.querySelectorAll('.link-checkbox');
  const batchBar = document.getElementById('batch-action-bar');
  const toggleBtn = document.getElementById('batch-mode-btn');
  
  if (batchMode) {
    // 显示复选框和批量操作栏
    checkboxes.forEach(cb => cb.style.display = 'inline-block');
    batchBar.style.display = 'flex';
    toggleBtn.textContent = '✅ 取消批量';
    toggleBtn.classList.add('active');
  } else {
    // 隐藏复选框和批量操作栏
    checkboxes.forEach(cb => {
      cb.style.display = 'none';
      cb.checked = false;
    });
    batchBar.style.display = 'none';
    toggleBtn.textContent = '☑️ 批量操作';
    toggleBtn.classList.remove('active');
  }
  
  updateBatchCount();
}

// 切换单个短链选中状态
function toggleLinkSelection(shortCode, checkbox) {
  if (checkbox.checked) {
    selectedLinks.add(shortCode);
  } else {
    selectedLinks.delete(shortCode);
  }
  updateBatchCount();
}

// 全选/取消全选
function toggleSelectAll(checkbox) {
  const checkboxes = document.querySelectorAll('.link-checkbox');
  
  checkboxes.forEach(cb => {
    cb.checked = checkbox.checked;
    const shortCode = cb.getAttribute('data-code');
    
    if (checkbox.checked) {
      selectedLinks.add(shortCode);
    } else {
      selectedLinks.delete(shortCode);
    }
  });
  
  updateBatchCount();
}

// 更新批量操作计数
function updateBatchCount() {
  const count = selectedLinks.size;
  const countElement = document.getElementById('selected-count');
  
  if (countElement) {
    countElement.textContent = `已选择 ${count} 个`;
  }
  
  // 更新批量操作按钮状态
  const batchDeleteBtn = document.getElementById('batch-delete-btn');
  const batchExportBtn = document.getElementById('batch-export-btn');
  const batchUpdateBtn = document.getElementById('batch-update-btn');
  
  if (count > 0) {
    if (batchDeleteBtn) batchDeleteBtn.disabled = false;
    if (batchExportBtn) batchExportBtn.disabled = false;
    if (batchUpdateBtn) batchUpdateBtn.disabled = false;
  } else {
    if (batchDeleteBtn) batchDeleteBtn.disabled = true;
    if (batchExportBtn) batchExportBtn.disabled = true;
    if (batchUpdateBtn) batchUpdateBtn.disabled = true;
  }
}

// ========================================
// 批量删除功能
// ========================================

async function batchDelete() {
  if (selectedLinks.size === 0) {
    showNotification('请先选择要删除的短链', 'warning');
    return;
  }
  
  const confirmMsg = `确定要删除选中的 ${selectedLinks.size} 个短链吗？\n\n` +
    `注意：这是软删除，可以在回收站中恢复。`;
  
  if (!confirm(confirmMsg)) {
    return;
  }
  
  const codes = Array.from(selectedLinks);
  let successCount = 0;
  let failedCount = 0;
  
  // 显示进度
  showNotification(`正在删除 ${codes.length} 个短链...`, 'info');
  
  // 逐个删除 (可优化为批量API)
  for (const code of codes) {
    try {
      await request(`${API_BASE}/${code}`, {
        method: 'DELETE'
      });
      successCount++;
    } catch (error) {
      failedCount++;
      console.error(`删除 ${code} 失败:`, error);
    }
  }
  
  // 显示结果
  if (successCount > 0) {
    showNotification(`✅ 成功删除 ${successCount} 个短链${failedCount > 0 ? `，${failedCount} 个失败` : ''}`, 'success');
    selectedLinks.clear();
    updateBatchCount();
    refreshLinks();
  } else {
    showNotification('❌ 删除失败', 'error');
  }
}

// ========================================
// 批量导出功能
// ========================================

async function batchExport() {
  if (selectedLinks.size === 0) {
    showNotification('请先选择要导出的短链', 'warning');
    return;
  }
  
  const codes = Array.from(selectedLinks);
  const data = [];
  
  showNotification(`正在导出 ${codes.length} 个短链...`, 'info');
  
  // 获取每个短链的详细信息
  for (const code of codes) {
    try {
      const result = await request(`${API_BASE}/info/${code}`);
      if (result.success && result.data) {
        data.push(result.data);
      }
    } catch (error) {
      console.error(`获取 ${code} 信息失败:`, error);
    }
  }
  
  // 生成 CSV
  const csv = generateCSV(data);
  downloadFile(csv, `shortlinks_export_${Date.now()}.csv`, 'text/csv');
  
  showNotification(`✅ 成功导出 ${data.length} 个短链`, 'success');
}

// 生成 CSV 内容
function generateCSV(data) {
  const headers = ['短链码', '服务类型', '状态', '目标路径', '访问量', '创建时间'];
  const rows = [headers.join(',')];
  
  data.forEach(item => {
    const row = [
      item.short_code || '',
      item.service_type || '',
      item.status || '',
      `"${item.targets || ''}"`,
      item.visit_count || 0,
      item.created_at || ''
    ];
    rows.push(row.join(','));
  });
  
  return rows.join('\n');
}

// 下载文件
function downloadFile(content, filename, mimeType) {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// ========================================
// 高级搜索功能
// ========================================

// 显示高级搜索面板
function showAdvancedSearch() {
  const modal = document.getElementById('advanced-search-modal');
  if (modal) {
    modal.style.display = 'block';
  }
}

// 隐藏高级搜索面板
function hideAdvancedSearch() {
  const modal = document.getElementById('advanced-search-modal');
  if (modal) {
    modal.style.display = 'none';
  }
}

// 应用高级搜索
async function applyAdvancedSearch() {
  const form = document.getElementById('advanced-search-form');
  const formData = new FormData(form);
  
  searchFilters = {
    short_code: formData.get('search_code'),
    service_type: formData.get('search_service_type'),
    status: formData.get('search_status'),
    date_from: formData.get('search_date_from'),
    date_to: formData.get('search_date_to'),
    visit_count_min: formData.get('search_visit_min'),
    visit_count_max: formData.get('search_visit_max'),
    page: 1,
    page_size: 20
  };
  
  // 移除空值
  Object.keys(searchFilters).forEach(key => {
    if (!searchFilters[key]) {
      delete searchFilters[key];
    }
  });
  
  try {
    showNotification('搜索中...', 'info');
    
    const result = await request(`${API_BASE}/search`, {
      method: 'POST',
      body: JSON.stringify(searchFilters)
    });
    
    if (result.success && result.data) {
      displaySearchResults(result.data);
      hideAdvancedSearch();
      showNotification(`✅ 找到 ${result.data.pagination.total} 个结果`, 'success');
    }
  } catch (error) {
    console.error('搜索失败:', error);
  }
}

// 显示搜索结果
function displaySearchResults(data) {
  const tbody = document.querySelector('#links-table tbody');
  if (!tbody) return;
  
  tbody.innerHTML = '';
  
  if (!data.links || data.links.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;">没有找到匹配的结果</td></tr>';
    return;
  }
  
  data.links.forEach(link => {
    const row = createLinkRow(link);
    tbody.appendChild(row);
  });
  
  // 更新分页
  updatePagination(data.pagination);
}

// 清除搜索条件
function clearSearch() {
  searchFilters = {};
  document.getElementById('advanced-search-form').reset();
  refreshLinks();
}

// ========================================
// 导入功能
// ========================================

// 显示导入对话框
function showImportDialog() {
  const modal = document.getElementById('import-modal');
  if (modal) {
    modal.style.display = 'block';
  }
}

// 隐藏导入对话框
function hideImportDialog() {
  const modal = document.getElementById('import-modal');
  if (modal) {
    modal.style.display = 'none';
  }
}

// 处理文件选择
function handleFileSelect(event) {
  const file = event.target.files[0];
  if (!file) return;
  
  const fileType = file.name.split('.').pop().toLowerCase();
  
  if (fileType === 'csv') {
    parseCSVFile(file);
  } else if (fileType === 'json') {
    parseJSONFile(file);
  } else {
    showNotification('不支持的文件格式，请上传 CSV 或 JSON 文件', 'error');
  }
}

// 解析 CSV 文件
function parseCSVFile(file) {
  const reader = new FileReader();
  
  reader.onload = async (e) => {
    const csv = e.target.result;
    const lines = csv.split('\n');
    const data = [];
    
    // 跳过标题行
    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (!line) continue;
      
      const parts = line.split(',');
      if (parts.length < 3) continue;
      
      data.push({
        short_code: parts[0],
        service_type: parts[1],
        image_path: parts[2],
        strategy: parts[3] || 'round_robin',
        expire_time: parts[4] ? parseInt(parts[4]) : null,
        note: parts[5] || ''
      });
    }
    
    if (data.length > 0) {
      await importLinks(data);
    } else {
      showNotification('CSV 文件中没有有效数据', 'warning');
    }
  };
  
  reader.readAsText(file);
}

// 解析 JSON 文件
function parseJSONFile(file) {
  const reader = new FileReader();
  
  reader.onload = async (e) => {
    try {
      const json = JSON.parse(e.target.result);
      
      if (json.links && Array.isArray(json.links)) {
        await importLinks(json.links);
      } else {
        showNotification('JSON 格式错误，请确保有 links 数组', 'error');
      }
    } catch (error) {
      showNotification('JSON 解析失败: ' + error.message, 'error');
    }
  };
  
  reader.readAsText(file);
}

// 导入短链
async function importLinks(links) {
  if (!links || links.length === 0) {
    showNotification('没有要导入的数据', 'warning');
    return;
  }
  
  showNotification(`正在导入 ${links.length} 个短链...`, 'info');
  
  try {
    const result = await request(`${API_BASE}/import`, {
      method: 'POST',
      body: JSON.stringify({ links: links })
    });
    
    if (result.success && result.data) {
      const { success_count, failed_count, total } = result.data;
      
      showNotification(
        `✅ 导入完成！成功 ${success_count} 个，失败 ${failed_count} 个，总计 ${total} 个`,
        success_count > 0 ? 'success' : 'warning'
      );
      
      hideImportDialog();
      refreshLinks();
    }
  } catch (error) {
    console.error('导入失败:', error);
  }
}

// 下载导入模板
async function downloadTemplate(format = 'csv') {
  try {
    window.open(`${API_BASE}/template?format=${format}`, '_blank');
    showNotification('模板下载中...', 'info');
  } catch (error) {
    showNotification('模板下载失败', 'error');
  }
}

// ========================================
// 回收站功能
// ========================================

// 显示回收站
async function showTrash() {
  try {
    const result = await request(`${API_BASE}/trash?page=1&page_size=50`);
    
    if (result.success && result.data) {
      displayTrashLinks(result.data);
    }
  } catch (error) {
    console.error('加载回收站失败:', error);
  }
}

// 显示回收站列表
function displayTrashLinks(data) {
  const modal = document.getElementById('trash-modal');
  const tbody = document.querySelector('#trash-table tbody');
  
  if (!tbody) return;
  
  tbody.innerHTML = '';
  
  if (!data.links || data.links.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;">回收站是空的</td></tr>';
  } else {
    data.links.forEach(link => {
      const row = document.createElement('tr');
      row.innerHTML = `
        <td>${link.short_code}</td>
        <td>${link.service_type}</td>
        <td>${link.visit_count || 0}</td>
        <td>${link.deleted_at || ''}</td>
        <td>
          <button class="btn btn-sm" onclick="restoreLink('${link.short_code}')">
            🔄 恢复
          </button>
          <button class="btn btn-sm btn-danger" onclick="permanentDelete('${link.short_code}')">
            🗑️ 永久删除
          </button>
        </td>
      `;
      tbody.appendChild(row);
    });
  }
  
  if (modal) {
    modal.style.display = 'block';
  }
}

// 恢复短链
async function restoreLink(shortCode) {
  if (!confirm(`确定要恢复短链 "${shortCode}" 吗？`)) {
    return;
  }
  
  try {
    const result = await request(`${API_BASE}/restore/${shortCode}`, {
      method: 'POST'
    });
    
    if (result.success) {
      showNotification(`✅ 短链 ${shortCode} 已恢复`, 'success');
      showTrash();  // 刷新回收站
    }
  } catch (error) {
    console.error('恢复失败:', error);
  }
}

// 永久删除
async function permanentDelete(shortCode) {
  const confirmMsg = `⚠️ 警告：永久删除操作！\n\n` +
    `确定要永久删除短链 "${shortCode}" 吗？\n\n` +
    `此操作将：\n` +
    `- 从数据库中完全删除\n` +
    `- 删除所有统计数据\n` +
    `- 无法恢复\n\n` +
    `请谨慎操作！`;
  
  if (!confirm(confirmMsg)) {
    return;
  }
  
  // 二次确认
  if (!confirm('最后确认：真的要永久删除吗？此操作不可撤销！')) {
    return;
  }
  
  try {
    const result = await request(`${API_BASE}/permanent/${shortCode}`, {
      method: 'DELETE'
    });
    
    if (result.success) {
      showNotification(`✅ 短链 ${shortCode} 已永久删除`, 'success');
      showTrash();  // 刷新回收站
    }
  } catch (error) {
    console.error('永久删除失败:', error);
  }
}

// ========================================
// 导出所有数据
// ========================================

async function exportAllLinks(format = 'csv') {
  try {
    const url = `${API_BASE}/export?format=${format}`;
    window.open(url, '_blank');
    showNotification('导出中...', 'info');
  } catch (error) {
    showNotification('导出失败', 'error');
  }
}

console.log('✅ enhanced-features.js 加载完成');
