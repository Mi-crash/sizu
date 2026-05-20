# CLAUDE.md - 工作流程规范

此文件定义 AI 跨会话工作的规范流程，确保一致性和质量。

> 项目具体信息（技术栈、目录结构、编码规范等）请参阅 [PROJECT.md](./PROJECT.md)

---

## Git Flow 分支模型

```
main (生产分支 - 稳定版本)
  │
  └── develop (开发主分支 - 集成测试)
        │
        ├── feature/F001-env-setup
        ├── feature/F002-comm-verify
        └── feature/F005-slam-mapping
```

### 分支说明

| 分支 | 用途 | 来源 | 合并到 |
|------|------|------|--------|
| `main` | 稳定版本 | - | - |
| `develop` | 开发主分支 | main | main (发布时) |
| `feature/Fxxx-name` | 单个功能开发 | develop | develop |

### 多智能体协作规则

1. **每个智能体开发不同功能** - 避免同时修改同一文件
2. **从 develop 创建 feature 分支** - 不直接在 develop 提交
3. **功能完成后创建 PR** - 通过 PR 合并回 develop
4. **拉取最新代码** - 开始前先 `git pull origin develop`

---

## 会话启动流程

每次会话开始时，**必须**按顺序执行：

### 1. 确认工作目录
```bash
pwd  # /home/NKCCC/sizu-master
```

### 2. 阅读项目指南
```
读取 CLAUDE.md 和 PROJECT.md
```

### 3. 阅读进度记录
```
读取 claude-progress.txt 了解上次会话内容和当前状态
```

### 4. 阅读功能列表
```
读取 feature_list.json 了解功能完成情况
```

### 5. 查看 Git 状态
```bash
git branch          # 确认当前分支
git log --oneline -10
git pull origin develop  # 拉取最新代码
```

### 6. 验证开发环境
```bash
bash init.sh        # 检查 SDK 依赖是否就绪
```

---

## 功能开发流程

### 1. 选择功能
- 从 `feature_list.json` 选择状态为 `pending` 的功能
- **一次只开发一个功能**
- 按 F001 → F002 → ... 顺序，部分功能有前置依赖

### 2. 创建功能分支
```bash
git checkout develop
git checkout -b feature/Fxxx-short-name
```

### 3. 规划实现
- 列出需要修改/创建的文件
- 阅读 `开发计划/` 中对应阶段的技术方案
- 二次开发代码放在 `code/` 目录下，不修改官方 SDK

### 4. 实现功能
- 遵循 PROJECT.md 中的编码规范
- 处理错误和边界情况

### 5. 测试验证
- 按 `feature_list.json` 中的 `passes` 逐项验证
- **只有所有 pass 项通过才能标记为完成**

### 6. 提交代码
```bash
git add <files>
git commit -m "feat(Fxxx): 功能描述"
git push origin feature/Fxxx-short-name
```

### 7. 合并到 develop
```bash
git checkout develop
git merge --no-ff feature/Fxxx-short-name
git push origin develop
git branch -d feature/Fxxx-short-name
```

---

## 会话结束流程

每次会话结束前，**必须**执行：

### 1. 更新进度文件
编辑 `claude-progress.txt`：记录本次完成的工作、遇到的问题、更新当前状态

### 2. 更新功能列表
- **只能**修改 `feature_list.json` 中 `status` 字段
- **禁止**删除或修改 `passes` 中的测试条目

### 3. 确保代码整洁
- 没有遗留的临时文件，代码可被下一个会话直接使用

---

## Commit Message 规范

| 类型 | 说明 |
|------|------|
| `feat:` | 新功能 |
| `fix:` | 修复 bug |
| `docs:` | 文档更新 |
| `refactor:` | 重构 |
| `test:` | 测试相关 |
| `chore:` | 构建/工具/环境 |
| `wip:` | 进行中（未完成） |

**格式**：`type(Fxxx): description`

示例：
```
feat(F001): 完成 CycloneDDS 环境配置
fix(F005): 修复 SLAM 建图定位漂移问题
chore: 更新 .gitignore
```

---

## 重要规则

1. **禁止直接在 develop/main 分支提交** - 必须使用 feature 分支
2. **禁止删除或修改 feature_list.json 中的测试用例描述**
3. **每次会话只做一个功能**
4. **开始前先拉取最新代码** - `git pull origin develop`
5. **不修改官方 SDK 代码** - 二次开发代码独立放置在 `code/` 下
6. **充分测试** - 不标记功能为完成除非所有 pass 项验证通过
7. **记录进度** - 每次会话都要更新 claude-progress.txt

---

## 当前开发阶段

| 阶段 | 时间 | 功能 | 状态 |
|------|------|------|------|
| W1 | 5.19–5.23 | F001 环境搭建 + F002 通信验证 + F003 场地选定 | 进行中 |
| W2 | 5.26–5.30 | F004 ROS2 集成 + F005 SLAM 建图 | 待开始 |
| W3 | 6.02–6.06 | F006 自主导航 + F007 巡检路线 | 待开始 |
| W4 | 6.09–6.13 | F008 安全机制 + F009 循环验收 | 待开始 |
