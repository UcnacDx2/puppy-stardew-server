# v1.0.62 Release Notes (Upcoming)

## Critical Fixes / 关键修复

### Selkies Web 界面无限重启问题修复
- **问题**: Selkies v1.6.2 在 Ubuntu 22.04 上存在两个致命错误
  - Python 环境冲突：`PyUnicode_FromFormat` 未定义符号错误
  - `on_resize_handler` 崩溃：ValueError - not enough values to unpack (expected 5, got 4)
- **解决方案**: 降级到稳定版本 Selkies v1.5.2
  - 与 Ubuntu 22.04 和 Python 3.10 完全兼容
  - 避免了 v1.6.x 引入的 pygobject 初始化问题
  - 修复了 resize handler 崩溃问题
- **影响**: 现在 Web 远程访问可以稳定运行，不会出现无限重启循环

## 升级说明 / Upgrade Instructions

从之前版本升级：
```bash
docker-compose down
docker-compose pull
docker-compose up -d
```

---

# v1.0.21 Release Notes

## 主要改进

### 自动权限修复
- 容器以 root 启动，自动修复挂载卷权限
- 无需手动运行 init.sh 或 chown 命令
- 自动切换到 steam 用户运行游戏

### 提升可靠性
- 修复游戏存在时的容器重启循环问题
- 改进错误处理和日志输出

## 升级说明

从 v1.0.20 升级到 v1.0.21：
```bash
docker-compose down
docker-compose pull
docker-compose up -d
```

无需其他操作！

