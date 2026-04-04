# Self Update — 自动更新 news-digest 技能

从 GitHub 仓库拉取最新版本并更新本地技能文件。

## 执行流程

### Step 1: 验证环境

1. 确认 `{baseDir}/SKILL.md` 存在且 frontmatter 包含 `name: news-digest`
2. 记录当前版本：从 SKILL.md frontmatter 读取 `_skill_version` 值，记为 `OLD_VERSION`

### Step 2: 检查本地状态

运行：
```bash
cd {baseDir} && git status --short
```

- 如有未提交的改动（tracked 文件），执行 `git stash push -m "news-digest-auto-update-stash"` 并记录 `STASHED=true`
- 无改动则 `STASHED=false`

### Step 3: 拉取并对比

运行：
```bash
cd {baseDir} && git fetch origin main
```

然后检查是否有新提交：
```bash
cd {baseDir} && git log --oneline HEAD..origin/main
```

- **无新提交**：告知用户 `news-digest v{OLD_VERSION} 已是最新版本`。若 STASHED=true 则 `git stash pop`。结束。
- **有新提交**：继续 Step 4

### Step 4: 合并更新

运行：
```bash
cd {baseDir} && git pull --rebase origin main
```

- **rebase 冲突**：执行 `git rebase --abort`，若 STASHED=true 则 `git stash pop`。告知用户合并冲突需手动处理。结束。
- **成功**：继续 Step 5

### Step 5: 恢复本地改动

若 STASHED=true：
```bash
cd {baseDir} && git stash pop
```

- pop 冲突时告知用户：更新已完成，但本地改动恢复时有冲突，请手动 `git stash show` 查看并解决。

### Step 6: 报告结果

1. 读取更新后 SKILL.md frontmatter `_skill_version`，记为 `NEW_VERSION`
2. 输出：

```
news-digest 更新完成
{OLD_VERSION} → {NEW_VERSION}

更新内容：
{Step 3 中 git log 的提交列表}
```
