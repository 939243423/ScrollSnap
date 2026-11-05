# 代码修改后自动提交准则 (Always Commit on Completion Rule)

每次完成代码编写、重构或 Bug 修复，并验证编译通过后，必须顺带执行 Git 提交（`git commit`）并推送到远端（`git push`），切勿遗留未提交的修改。

## 执行标准
1. **测试与编译验证**：完成修改后必须先执行 build 确保工程编译无误。
2. **规范化提交**：
   - 纳入所有修改与新增的相关文件。
   - 撰写清晰明了的 Conventional Commit 说明（例如 `feat(...)`, `fix(...)`, `refactor(...)`）。
3. **推送到远程仓库**：使用配置好的 SSH 远端将提交同步到远程分支。
