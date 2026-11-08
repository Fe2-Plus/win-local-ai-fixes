# Windows 本地 AI 环境修复小工具

三个在 Windows 上把本地 AI 环境跑起来时踩出来的小脚本。都是 PowerShell，没有依赖。

> 起因：GitHub 时通时不通、插件更新会删掉自己的运行环境、Docker/ffmpeg 子进程闪黑框。
> 这三个坑都不报错，只是悄悄坏掉。

## 1. `github-hosts-fix.ps1` —— GitHub 打不开时，挑一个能连的 IP

```powershell
# 以管理员身份打开 PowerShell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\github-hosts-fix.ps1
```

- 逐个测试候选 IP 的 443 端口，挑第一个能连的
- 写入 hosts 前**先备份**到 `%USERPROFILE%\hosts-backups\`
- 只改 `github.com` 一行，不碰别的
- 找不到可用 IP 时会明确说"没找到"，而不是静默失败

**为什么不用"加速器"**：有些加速器会往 hosts 写 `127.0.0.1`，浏览器可能还能走它自己的代理，但 `git` / `npm` / 脚本拿不到网。改 hosts 不经过第三方，也不装证书。

## 2. `dsh-config-backup.ps1` —— 更新前备份 DSH 的配置与插件源码

```powershell
.\dsh-config-backup.ps1 -ProfileDir "$env:USERPROFILE\.dsh\profiles\desktop"
```

- 备份 `package.json`、`cordis.yml`、`cordis.patch.yml`、`pnpm-lock.yaml`
- 备份本机插件源码（跳过 `node_modules`）
- 输出一个 zip，路径打印在最后一行

**为什么需要**：插件更新会整目录替换，装在该目录里的 venv、模型、本地补丁会一起没。

## 3. `patch-windows-hide.js` —— 给插件里的 `spawn` 补上 `windowsHide`

```javascript
node patch-windows-hide.js <node_modules 目录>
```

Windows 上 `spawn` 一个控制台程序（ffmpeg / yt-dlp / python）时，如果不加 `windowsHide: true`，每起一次就闪一个黑框。这个脚本按已知模式给常见的几处打补丁，可重复执行（已打过的会跳过）。

> 注意：它会连 GUI 程序的 `spawn`（比如启动 Edge、资源管理器）一起报出来。那些加不加都无所谓，`--fix` 加上也无害。默认是 dry run，先看报告再决定。

## 环境

- Windows 10 / 11
- PowerShell 5.1 或 7
- Node.js ≥ 20（仅第 3 个脚本需要）

## 许可

MIT
