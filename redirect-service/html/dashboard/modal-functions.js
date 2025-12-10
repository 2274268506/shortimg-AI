// 模态框相关函数 - 简化独立版本
console.log('📦 modal-functions.js 开始加载');

// 当前步骤
let currentStep = 1;
const totalSteps = 3;

// 生成随机代码（12位）
function generateRandomCode() {
  console.log('🎲 generateRandomCode 执行');
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  let code = '';
  for (let i = 0; i < 12; i++) {  // 12位
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  const input = document.getElementById('short_code');
  if (input) {
    input.value = code;
    updatePreviewUrl();
  }
  console.log('✅ 生成代码:', code);
}

// 更新预览 URL
function updatePreviewUrl() {
  const code = document.getElementById('short_code')?.value || 'your-code';
  const preview = document.getElementById('code-preview');
  if (preview) {
    preview.textContent = code;
  }
}

// 更新服务类型帮助
function updateServiceHelp() {
  const serviceType = document.getElementById('service_type')?.value;
  const helpText = document.getElementById('service-help');

  const helps = {
    imagebed: '用于图床服务，CDN分流由后端自动处理',
    general: '通用短链服务，直接跳转到指定URL',
    file: '用于文件分享，CDN分流由后端自动处理',
    video: '视频服务专用，CDN分流由后端自动处理'
  };

  if (helpText) {
    helpText.textContent = helps[serviceType] || '选择短链的用途类型';
  }

  // 根据服务类型切换目标配置方式
  const generalTarget = document.getElementById('general-target');
  const cdnTarget = document.getElementById('cdn-target');

  if (serviceType === 'general') {
    // 通用类型：显示URL输入框
    if (generalTarget) generalTarget.style.display = 'block';
    if (cdnTarget) cdnTarget.style.display = 'none';
  } else {
    // 其他类型：显示路径输入框
    if (generalTarget) generalTarget.style.display = 'none';
    if (cdnTarget) cdnTarget.style.display = 'block';
  }
}

// 下一步
function nextStep() {
  console.log('➡️ nextStep, 当前步骤:', currentStep);

  if (!validateCurrentStep()) {
    return;
  }

  if (currentStep < totalSteps) {
    showStep(currentStep + 1);
  }
}

// 上一步
function prevStep() {
  console.log('⬅️ prevStep, 当前步骤:', currentStep);

  if (currentStep > 1) {
    showStep(currentStep - 1);
  }
}

// 显示指定步骤
function showStep(step) {
  console.log('📍 显示步骤:', step);
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
  const prevBtn = document.getElementById('prev-btn');
  const nextBtn = document.getElementById('next-btn');
  const submitBtn = document.getElementById('submit-btn');

  if (prevBtn) prevBtn.style.display = step > 1 ? 'inline-block' : 'none';
  if (nextBtn) nextBtn.style.display = step < totalSteps ? 'inline-block' : 'none';
  if (submitBtn) submitBtn.style.display = step === totalSteps ? 'inline-block' : 'none';
}

// 验证当前步骤
function validateCurrentStep() {
  const step = currentStep;

  if (step === 1) {
    // 第一步：验证服务类型
    const serviceType = document.getElementById('service_type')?.value;
    if (!serviceType) {
      alert('请选择服务类型');
      return false;
    }
  }

  if (step === 2) {
    // 第二步：根据服务类型验证目标URL或路径
    const serviceType = document.getElementById('service_type')?.value;
    
    if (serviceType === 'general') {
      // 通用类型：验证完整URL
      const url = document.getElementById('target_url')?.value.trim();
      if (!url) {
        alert('请输入目标URL');
        return false;
      }
      try {
        new URL(url);
      } catch {
        alert('请输入有效的完整URL（如：https://www.baidu.com）');
        return false;
      }
    } else {
      // 其他类型：验证资源路径
      const path = document.getElementById('target_path')?.value.trim();
      if (!path) {
        alert('请输入资源路径');
        return false;
      }
    }
  }

  return true;
}

// 切换配置模式
function switchMode(mode) {
  console.log('🔄 切换模式:', mode);

  // 更新按钮状态
  document.querySelectorAll('.mode-btn').forEach(btn => {
    btn.classList.remove('active');
    if (btn.getAttribute('data-mode') === mode) {
      btn.classList.add('active');
    }
  });

  // 更新模式内容
  const simpleMode = document.getElementById('simple-mode');
  const advancedMode = document.getElementById('advanced-mode');

  if (mode === 'simple') {
    if (simpleMode) simpleMode.classList.add('active');
    if (advancedMode) advancedMode.classList.remove('active');
  } else {
    if (simpleMode) simpleMode.classList.remove('active');
    if (advancedMode) advancedMode.classList.add('active');
  }
}

// 使用快速模板
function useTemplate(type) {
  console.log('📋 使用模板:', type);

  const templates = {
    single: `[
  {
    "cdn": "default",
    "path": "/path/to/file",
    "weight": 1
  }
]`,
    dual: `[
  {
    "cdn": "north_telecom",
    "path": "/path/to/file",
    "weight": 2
  },
  {
    "cdn": "south_mobile",
    "path": "/path/to/file",
    "weight": 1
  }
]`,
    geo: `[
  {
    "cdn": "beijing",
    "path": "/path/to/file",
    "region": "north"
  },
  {
    "cdn": "guangzhou",
    "path": "/path/to/file",
    "region": "south"
  }
]`
  };

  const textarea = document.getElementById('targets');
  if (textarea) {
    textarea.value = templates[type] || templates.single;
  }
}

// 显示目标配置帮助
function showTargetHelp() {
  alert(`目标配置说明：

每个目标对象包含以下字段：
• cdn: CDN标识（如 north_telecom, south_mobile）
• path: 目标路径
• host: 可选，目标主机
• weight: 可选，权重值（用于权重分流）

示例：
[
  {
    "cdn": "north_telecom",
    "path": "/uploads/image.jpg",
    "weight": 2
  },
  {
    "cdn": "south_mobile",
    "path": "/uploads/image.jpg",
    "weight": 1
  }
]`);
}

// 从简单模式更新 targets
function updateTargetsFromSimple() {
  const url = document.getElementById('simple_url')?.value.trim();
  if (url) {
    try {
      const urlObj = new URL(url);
      const targets = [{
        cdn: 'default',
        path: urlObj.pathname + urlObj.search,
        host: urlObj.host,
        weight: 1
      }];
      const textarea = document.getElementById('targets');
      if (textarea) {
        textarea.value = JSON.stringify(targets, null, 2);
      }
    } catch {
      // 无效 URL，忽略
    }
  }
}

console.log('✅ modal-functions.js 加载完成');
console.log('✅ generateRandomCode:', typeof generateRandomCode);
console.log('✅ nextStep:', typeof nextStep);
console.log('✅ prevStep:', typeof prevStep);
console.log('✅ switchMode:', typeof switchMode);
