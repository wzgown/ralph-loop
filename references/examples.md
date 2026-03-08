# 完整示例

## 用户输入

> 我需要实现一个用户个人资料编辑功能，用户可以修改头像、昵称、个人简介，还要能预览更改

## AI 响应（Task Planner）

我来帮你创建这个任务。首先创建 task.md：

```markdown
# 任务：用户个人资料编辑功能

## 背景

用户需要能够编辑自己的个人资料，包括头像、昵称和个人简介，并能在保存前预览更改。

## 成功标准

- [ ] 用户可以上传并裁剪头像
- [ ] 用户可以修改昵称（2-20字符）
- [ ] 用户可以编辑个人简介（最多500字）
- [ ] 预览功能实时显示更改
- [ ] 保存后数据持久化

## 实现计划

- [ ] **T1**: 创建个人资料编辑页面 UI
- [ ] **T2**: 实现头像上传和裁剪
- [ ] **T3**: 实现表单验证
- [ ] **T4**: 实现预览功能
- [ ] **T5**: 实现 API 集成

## 约束

**必须：**
- 头像大小限制 2MB
- 昵称不能包含特殊字符
- 使用现有的认证系统

**禁止：**
- 不允许上传非图片文件
- 不允许修改其他用户的资料

## 完成信号

MISSION_COMPLETE
```

然后创建 features.json：

```json
{
  "task_id": "F-20260308-002",
  "task_name": "用户个人资料编辑功能",
  "created_at": "2026-03-08T14:00:00+08:00",
  "features": [
    {
      "id": "F001",
      "category": "ui",
      "description": "个人资料编辑页面基础布局",
      "priority": "high",
      "steps": [
        "访问 /profile/edit",
        "验证页面包含头像、昵称、简介输入区域",
        "验证有保存和取消按钮"
      ],
      "verify_command": "npm run test:e2e -- --grep 'profile edit page'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    },
    {
      "id": "F002",
      "category": "functional",
      "description": "头像上传和裁剪功能",
      "priority": "high",
      "steps": [
        "点击头像区域",
        "选择图片文件（< 2MB）",
        "使用裁剪器调整",
        "验证预览更新"
      ],
      "verify_command": "npm run test:e2e -- --grep 'avatar upload'",
      "passes": false,
      "completed_at": null,
      "notes": "使用 Cropper.js"
    },
    {
      "id": "F003",
      "category": "functional",
      "description": "表单验证",
      "priority": "high",
      "steps": [
        "输入 1 字符昵称，验证错误提示",
        "输入 21 字符昵称，验证错误提示",
        "输入 501 字符简介，验证错误提示",
        "输入有效数据，验证通过"
      ],
      "verify_command": "npm run test:e2e -- --grep 'profile validation'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    },
    {
      "id": "F004",
      "category": "functional",
      "description": "实时预览功能",
      "priority": "medium",
      "steps": [
        "修改昵称，验证预览区实时更新",
        "修改简介，验证预览区实时更新",
        "更换头像，验证预览区实时更新"
      ],
      "verify_command": "npm run test:e2e -- --grep 'profile preview'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    },
    {
      "id": "F005",
      "category": "api",
      "description": "保存资料 API 集成",
      "priority": "high",
      "steps": [
        "修改所有字段",
        "点击保存",
        "验证 API 请求正确",
        "验证成功提示",
        "刷新页面验证数据持久化"
      ],
      "verify_command": "npm run test:e2e -- --grep 'profile save'",
      "passes": false,
      "completed_at": null,
      "notes": ""
    }
  ]
}
```

现在可以运行 `./ralph --init` 初始化任务，然后 `./ralph --agent claude` 开始执行。

## Task Executor 执行示例

```
AI（Task Executor）：
    我将开始工作...

    1. 读取 features.json
    2. 选择 F001（passes: false）
    3. 启动开发服务器
    4. 实现 F001 功能
    5. 运行测试
    6. 更新 passes: true
    7. Git commit

    MISSION_COMPLETE
```
