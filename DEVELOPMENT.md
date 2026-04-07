# MusicPlayer 开发文档

## 目录

1. [项目概述](#1-项目概述)
2. [技术栈](#2-技术栈)
3. [项目结构](#3-项目结构)
4. [架构设计](#4-架构设计)
5. [数据模型](#5-数据模型)
6. [核心服务](#6-核心服务)
7. [视图组件](#7-视图组件)
8. [开发环境搭建](#8-开发环境搭建)
9. [开发流程](#9-开发流程)
10. [关键实现细节](#10-关键实现细节)
11. [已知问题与修复记录](#11-已知问题与修复记录)

---

## 1. 项目概述

- **项目名称**：MusicPlayer
- **Bundle ID**：`com.dashu.musicplayer`
- **最低 macOS 版本**：macOS 14.0
- **核心功能**：macOS 本地音乐播放器，支持 QQ 音乐/网易云音乐歌单同步、本地下载播放
- **目标用户**：大树（macOS 独立开发者）

---

## 2. 技术栈

| 类别 | 技术 |
|------|------|
| 语言 | Swift 5.9+ |
| UI 框架 | SwiftUI（macOS 14+） |
| 数据存储 | SQLite.swift（本地歌曲/歌单缓存） |
| 音频播放 | AVFoundation（AVAudioPlayer 本地 / AVPlayer 流媒体） |
| 下载服务 | yt-dlp（YouTube 音频抓取） |
| 包管理 | XcodeGen + Swift Package Manager |
| 架构 | MVVM |
| 窗口管理 | NSWindow + NSHostingView（SwiftUI 嵌入 AppKit） |

---

## 3. 项目结构

```
MusicPlayer/
├── SPEC.md                      # 产品规格说明书
├── DEVELOPMENT.md               # 本文档
├── project.yml                  # XcodeGen 配置
├── MusicPlayer.xcodeproj/      # Xcode 项目（由 XcodeGen 生成）
├── Sources/
│   ├── main.swift               # 入口点（NSApplication.shared.run）
│   ├── AppDelegate.swift         # 应用生命周期管理
│   ├── Info.plist
│   ├── Models/
│   │   ├── Platform.swift       # 平台枚举（QQ音乐/网易云音乐）
│   │   ├── Playlist.swift       # 歌单数据结构
│   │   └── Song.swift           # 歌曲数据结构
│   ├── ViewModels/
│   │   ├── PlayerViewModel.swift    # 播放状态管理
│   │   └── PlaylistViewModel.swift  # 歌单列表管理
│   ├── Views/
│   │   ├── MainView.swift           # 主布局（三栏：侧边栏+歌曲列表+迷你播放器）
│   │   ├── PlayerBarView.swift      # 底部播放控制栏
│   │   ├── PlaylistSidebarView.swift # 左侧歌单列表
│   │   ├── SongListView.swift       # 歌曲列表（含下载按钮）
│   │   ├── RightPanelView.swift     # 右侧面板（歌词/播放队列）
│   │   ├── MiniPlayerView.swift     # 迷你播放器
│   │   └── DownloadSheet.swift      # 下载管理界面
│   ├── Services/
│   │   ├── AudioPlayerService.swift  # 音频播放核心（AVAudioPlayer/AVPlayer）
│   │   ├── DatabaseService.swift     # SQLite 数据持久化
│   │   ├── DownloadService.swift      # 下载记录管理
│   │   ├── PlaylistSyncService.swift # 歌单同步（QQ/网易云）
│   │   └── YouTubeMusicService.swift # yt-dlp 下载封装
│   └── Design/
│       └── Theme.swift              # 主题配色（Google Material 3 风格）
└── download/                        # 本地下载音频存放目录
```

---

## 4. 架构设计

### MVVM 架构

```
┌─────────────────────────────────────────────┐
│                    Views                     │
│  MainView / PlayerBarView / SongListView    │
│         ↕ @EnvironmentObject                │
├─────────────────────────────────────────────┤
│               ViewModels                     │
│  PlayerViewModel / PlaylistViewModel         │
│         ↕ 依赖                               │
├─────────────────────────────────────────────┤
│                Services                      │
│  AudioPlayerService / DatabaseService        │
│  PlaylistSyncService / DownloadService       │
│         ↕ 数据                               │
├─────────────────────────────────────────────┤
│              数据层                           │
│  SQLite.swift / UserDefaults / 文件系统      │
└─────────────────────────────────────────────┘
```

### 关键设计决策

- **Window 管理**：SwiftUI 不能直接创建 NSWindow，用 `NSHostingView` 将 SwiftUI View 嵌入 AppKit NSWindow
- **PlayerViewModel 单例**：`PlayerViewModel.shared` 贯穿整个应用生命周期，通过 `@EnvironmentObject` 注入
- **数据库并发**：DatabaseService 是 `actor`，所有操作 `await` 执行
- **音频播放双引擎**：本地文件用 `AVAudioPlayer`（稳定），流媒体用 `AVPlayer`（异步）

---

## 5. 数据模型

### Platform

```swift
enum Platform: String, Codable, CaseIterable {
    case qq = "QQ音乐"
    case netEase = "网易云音乐"
}
```

### Song

```swift
struct Song: Identifiable, Codable, Equatable, Hashable {
    let id: String              // 格式：netease_3362533985 / qq_xxx
    let platform: Platform
    var title: String
    var artist: String
    var album: String?
    var duration: Int           // 秒
    var playUrl: String?        // 流媒体 URL
    var coverUrl: String?       // 封面图 URL
}
```

### Playlist

```swift
struct Playlist: Identifiable, Codable, Equatable {
    let id: String
    let platform: Platform
    var name: String
    var songCount: Int
    var lastSyncTime: Date?
    var songs: [Song]           // 展开的歌曲列表
    var coverUrl: String?
}
```

### DownloadRecord（本地下载记录）

```swift
struct DownloadRecord: Codable {
    let songId: String          // 同 Song.id
    let platform: String        // 原始平台中文名
    let localPath: String       // 下载文件路径
    let downloadedAt: Date
}
```

---

## 6. 核心服务

### AudioPlayerService

**职责**：音频播放控制

**播放策略**：
1. 先查 DownloadService 是否有本地文件（`localPath(for: songId)`）
2. 有本地文件 → `AVAudioPlayer`（对本地 MP3 稳定）
3. 无本地文件 → `AVPlayer` + 流媒体 URL

**关键方法**：

```swift
func startPlayback(song: Song, completion: @escaping (Bool, String?) -> Void)
func pause()
func resume()
func stop()
func seek(to seconds: Double)
func setVolume(_ value: Double)
```

**本地文件优先逻辑**：

```swift
func playbackURL(for song: Song) -> URL? {
    // Step 1: 查 UserDefaults 里的下载记录
    if let localURL = DownloadService.shared.localPath(for: song.id) {
        return localURL  // 本地文件优先
    }
    // Step 2: fallback 流媒体 URL
    if let urlString = resolvedStreamingURL(for: song) {
        return URL(string: urlString)
    }
    return nil
}
```

**restart 时防抖**：播放新歌曲时，`startPlayback` 先 `playbackCompletion = nil` 再 `stopSilently()`，防止旧 completion（`false`）触发导致错误弹窗。

### DatabaseService

**职责**：SQLite 持久化

**表结构**：

```sql
CREATE TABLE playlists (
    id TEXT PRIMARY KEY,
    platform TEXT,
    name TEXT,
    song_count INTEGER,
    last_sync REAL
);

CREATE TABLE songs (
    id TEXT PRIMARY KEY,
    platform TEXT,
    title TEXT,
    artist TEXT,
    album TEXT,
    duration INTEGER,
    play_url TEXT,
    cover_url TEXT,
    playlist_id TEXT NOT NULL
);
```

所有操作走 `actor` 隔离，`await` 调用。

### DownloadService

**职责**：本地下载文件路径管理

**存储位置**：`~/Documents/program/MusicPlayer/download/`

**文件命名**：`{platform}_{songId}.mp3`（例：`netease_3362533985.mp3`）

**记录存储**：UserDefaults key = `downloadedSongs_v1`，JSON 数组格式

**下载流程**（YouTube 音频）：
1. 用 `YouTubeMusicService.search(query:)` 搜 YouTube URL
2. 用 `yt-dlp -x --audio-format mp3` 下载
3. 保存记录到 UserDefaults

### PlaylistSyncService

**职责**：从 QQ 音乐/网易云音乐拉取歌单

**QQ 音乐**：解析 `https://y.qq.com/n/ryqq/playlist/{id}`，通过 `c.y.qq.com` API 获取歌曲列表

**网易云音乐**：解析 `https://music.163.com/playlist?id={id}`，通过网页抓取获取歌曲列表

---

## 7. 视图组件

### MainView（三栏布局）

```
┌──────────────┬──────────────────────┬─────────────┐
│ Playlist     │ SongListView         │ RightPanel  │
│ Sidebar      │ （可展开/收起）        │ （可选）     │
│ (240px)      │                      │             │
├──────────────┴──────────────────────┴─────────────┤
│              PlayerBarView (80px)                 │
└──────────────────────────────────────────────────┘
```

### PlayerBarView（底部播放控制栏）

- 歌曲封面（42×42）
- 歌曲名 + 艺术家（已移除测试用 ID 显示）
- 播放按钮组：⏮ ⏸/▶ ⏭（`PlaybackButton`，悬停变色）
- 进度条（`NetEaseProgressBar`，悬停加粗+浮窗时长）
- 音量控制（`VolumeSlider`，悬停加粗+浮窗百分比）
- 播放模式切换
- 错误弹窗（`.alert` 绑定 `playbackError`）

### SongListView（歌曲列表）

- 歌曲行：`selectSong` → `startPlayback`
- 下载状态图标：未下载 / 下载中 / ✓已下载
- 下载按钮：`YouTubeMusicService` 下载
- 当前播放高亮

---

## 8. 开发环境搭建

### 前置依赖

```bash
# XcodeGen（生成 Xcode 项目）
brew install xcodegen

# yt-dlp（音频下载，需预装）
brew install yt-dlp
```

### 生成项目

```bash
cd ~/Documents/program/MusicPlayer
xcodegen generate
open MusicPlayer.xcodeproj
```

### 构建

```bash
# Debug 构建
xcodebuild -project MusicPlayer.xcodeproj -scheme MusicPlayer -configuration Debug build

# Release 构建
xcodebuild -project MusicPlayer.xcodeproj -scheme MusicPlayer -configuration Release build
```

### 运行

```bash
# 通过 Xcode 运行（调试）
open MusicPlayer.xcodeproj

# 或直接打开构建产物
open ~/Library/Developer/Xcode/DerivedData/MusicPlayer-*/Build/Products/Debug/MusicPlayer.app
```

---

## 9. 开发流程

### 新增功能步骤

1. **改数据**：Model → Service → ViewModel → View（单向依赖）
2. **写代码**：
   - 数据/业务逻辑放 Services
   - UI 状态放 ViewModels
   - 纯展示放 Views
3. **调试**：
   - 日志写 `/tmp/musicplayer_debug.log`
   - macOS `console.app` 过滤 `MusicPlayer`
4. **自测**：至少覆盖正常流程 + 异常分支

### 添加新平台支持

1. `Platform.swift` 加枚举值
2. `PlaylistSyncService.swift` 加 `parseXxxSong()` 解析方法
3. `AudioPlayerService.resolvedStreamingURL()` 加 URL 生成逻辑

---

## 10. 关键实现细节

### 日志系统

`AudioPlayerService` 将所有关键操作写入 `/tmp/musicplayer_debug.log`：

```swift
private let logPath = "/tmp/musicplayer_debug.log"
private func logToFile(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
}
```

调试播放问题时优先检查此文件。

### 窗口配置（AppDelegate）

```swift
window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 900, height: 640),
    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
window.contentView = NSHostingView(rootView: contentView)
```

### 下载文件管理

- **下载目录**：`~/Documents/program/MusicPlayer/download/`
- **下载记录**：UserDefaults（key: `downloadedSongs_v1`）
- **文件名**：`{platform}_{songId}.mp3`
- **播放优先级**：本地文件 > 流媒体 URL

### NetEaseProgressBar（播放进度条）

位于 PlayerBarView 顶部，全宽无时间标签占空间。悬停时右侧浮窗显示 `当前 / 总时长`。

**悬停行为**：
- 轨道：3px → 5px 加粗
- 圆点：10px → 12px，始终显示
- 浮窗：右上角显示 `00:00 / 03:45`，有半透明背景，移开消失（0.15s 动画）

**拖动**：`DragGesture(minimumDistance: 0)` 实时更新 `displayTime`，松开时调用 `playerVM.seek()`。

### VolumeSlider（音量滑块）

位于 PlayerBarView 右侧，宽度 68px。

**颜色**：
- 未填充区域：`tc.progressBar`（与进度条轨道同色）
- 填充区域：`tc.accent`（蓝色）
- 小白点：始终显示

**悬停行为**：
- 轨道：4px → 6px 加粗
- 浮窗：显示 `75%` 数值，移开消失

**实时拖动关键**：用 `@State dragVolume` 本地状态记录拖动位置，`onChanged` 直接写本地状态（立即重绘），`onEnded` 才写入 `playerVM.setVolume()`。避免直接绑定 Published 属性导致的批量更新延迟。

### PlaybackButton（播放按钮组）

统一封装播放按钮的悬停效果：

```swift
struct PlaybackButton: View {
    let iconName: String
    let size: CGFloat
    var isPrimary: Bool = false   // 中央播放按钮有圆形背景
    let action: () -> Void

    private var hoverColor: Color {
        guard playerVM.currentSong != nil else { return tc.textTertiary }
        return isHovering ? tc.accent : tc.textSecondary
    }
}
```

- **上一曲/下一曲**：悬停颜色 `textSecondary → accent`
- **播放按钮**：悬停加深（`.overlay(Circle().fill(Color.black.opacity(0.20))))`）

---

## 11. 已知问题与修复记录

### Bug #1：暂停后重播错误弹窗（已修复）

**现象**：首次播放正常，暂停后再点播放，出现"播放失败"弹窗但歌曲继续播放。

**根因**：`startPlayback()` → `stop()` 同步触发旧的 `playbackCompletion?(false)` → `playbackState = .failed` → 弹窗出现 → 新 completion 注册成功 → `AVAudioPlayer` 开始播放（但弹窗已弹出）。

**修复**：新增 `stopSilently()` 内部方法，`startPlayback` 时先 `playbackCompletion = nil` 再调用 `stopSilently()`，彻底切断旧 completion 触发的可能。

### Bug #2：网络超时导致播放失败（已修复）

**现象**：有本地文件的歌曲仍然报"网络超时"。

**根因**：旧版 `AudioPlayerService` 对本地文件也用 `AVPlayer`，`AVPlayerItem.status` 事件对本地文件不可靠，导致 12 秒超时后才放弃。

**修复**：本地文件（`url.isFileURL`）用 `AVAudioPlayer`；流媒体 URL 用 `AVPlayer`。

### Bug #3：AVAudioPlayer 无法播放部分 MP3（已确认）

**现象**：部分 MP3 文件时长显示正确但播放无声。

**修复**：使用 `afplay`（macOS 系统播放器）验证文件有效性。

### Bug #4：暂停→拖动进度条→播放从头开始（已修复，2026-04-06）

**现象**：暂停后拖动进度条到某个位置，再点播放，播放从 0:00 开始而非拖动位置。

**根因**：`startPlayback()` 每次调用 `stopSilently()`（置 `audioPlayer = nil`）再重建，新 `AVAudioPlayer` 实例从 `currentTime = 0` 开始，seek 位置被丢弃。

**修复**：新增 early-return 分支——同一首歌 + 本地文件时，直接 `resume()` 不重建播放器，保留 seek 位置：

```swift
// 在 startPlayback() 开头
if song.id == currentSong?.id, audioPlayer != nil, url.isFileURL {
    playbackCompletion = completion
    audioPlayer?.volume = Float(volume)
    audioPlayer?.play()
    isPlaying = true
    isLoading = false
    duration = audioPlayer?.duration ?? 0
    completion(true, nil)
    startAudioPlayerTimer()
    return
}
```

### 限制

- **歌单同步**：QQ Music API（referer 封锁）、网易云 API（需登录凭证 20001），均已失效
- **下载**：通过 YouTube 音频间接下载，非官方渠道
- **歌词**：v1.0 未实现

---

## 附录：Theme 颜色参考 + 常见错误

### Theme 颜色速查

| 属性 | 深色 | 浅色 | 用途 |
|------|------|------|------|
| `accent` | `#4285F4` | `#4285F4` | 主色（播放按钮/进度填充） |
| `progressBar` | `#3D3D3D` | `#DADCE0` | 进度条未填充轨道 |
| `progressFill` | `#4285F4` | `#4285F4` | 进度条已填充（=accent） |
| `bgSecondary` | `#1E1E1E` | `#F8F9FA` | PlayerBar 背景 |
| `bgTertiary` | `#2D2D2D` | `#F1F3F4` | 浮窗背景 |

### 常见编译错误

- `NSColor.accentColor` → 改为 `NSColor.controlAccentColor`（macOS API）
- `private` 类型被 `internal` 方法返回 → 将底层类改为 `fileprivate`

---

## 附录：常用命令

```bash
# 重启 MusicPlayer
killall MusicPlayer && open ~/Library/Developer/Xcode/DerivedData/MusicPlayer-*/Build/Products/Debug/MusicPlayer.app

# 查看日志
cat /tmp/musicplayer_debug.log

# 清空日志
rm /tmp/musicplayer_debug.log

# 查看崩溃日志
ls ~/Library/Logs/DiagnosticReports/ | grep MusicPlayer

# 查看数据库内容
sqlite3 ~/Library/Application\ Support/MusicPlayer.sqlite ".tables"
sqlite3 ~/Library/Application\ Support/MusicPlayer.sqlite "SELECT * FROM songs LIMIT 5;"

# 查看下载记录
python3 -c "
import plistlib, json
with open('/Users/jason/Library/Preferences/com.dashu.musicplayer.plist','rb') as f:
    d = plistlib.load(f)
print(json.loads(d['downloadedSongs_v1'].decode('utf-8')))
"
```
