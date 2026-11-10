# 个人工具

macOS 菜单栏小工具。两个功能各自开关，选择会记住：

- **反转鼠标滚轮**。触控板和妙控鼠标保持系统「自然滚动」。逻辑来自 [mouse-scroll-flip](https://github.com/yerled/mouse-scroll-flip)（MIT，yerled），见 `THIRD_PARTY_NOTICES.md`。
- **屏幕取色**。连按两次 Command 键（每次都是按下再松开）。放大镜跟随指针，准星是当前像素，旁边是实时颜色。点击把 `#RRGGBB` 复制到剪贴板，Esc 取消。

界面是中文。没有账号、没有遥测、不会联网。

最低系统：**macOS 13**。二进制是 **arm64 + x86_64**。安装包是 **临时签名（ad-hoc）**，**没有 Apple 公证**。没有使用付费开发者证书。

## 安装

从 [Releases](https://github.com/yerled/personal-tools/releases) 或本分支的 GitHub Actions artifact 下载 `PersonalTools-*-macOS.dmg`（或 `.zip`）。

1. 打开磁盘映像，把 **个人工具** 拖到「应用程序」。
2. 直接双击会被系统拒绝。在访达里按住 Control 点按应用，选择「打开」，再点一次「打开」。
3. 如果提示已损坏或来自身份不明的开发者：

   ```sh
   xattr -dr com.apple.quarantine "/Applications/个人工具.app"
   ```

   这是 Gatekeeper 在拦截未公证的下载，不是文件坏了。
4. 菜单栏出现滴管图标，程序坞里没有图标。
5. 按提示允许 **辅助功能** 和 **屏幕录制**。也可以用菜单里的入口打开系统设置。如果之前拒绝过，macOS 不会反复弹窗，需要手动打开开关。允许辅助功能之后一般不用注销。屏幕录制有时要退出应用再打开。
6. 让 **自然滚动** 保持打开。
7. 如果单独的 Mouse Scroll Flip 还在运行，请退出。两份一起会把滚轮翻转两次。

登录时启动使用系统登录项。请把应用留在「应用程序」文件夹。

## 怎么用

| 菜单 | 作用 |
| --- | --- |
| 反转鼠标滚轮 | 开关滚轮反转。默认打开。 |
| 同时反转水平滚动 | 滚轮左右倾斜。默认关闭。 |
| 启用屏幕取色 | 开关取色。默认打开。 |
| 取色说明… | 双击 Command 的规则。 |
| 登录时启动 | 登录后打开。 |
| 设置… | 同一组开关。 |

取色不会占用普通快捷键。按住 Command、Command-C、Command-Tab、Command-Shift 都不会打开放大镜。滚轮事件不在取色监听的范围内。只有放大镜出现时，才会吃掉这一下左键和 Esc。

有些鼠标的「平滑滚动」会被系统标成连续滚动，看起来和触控板一样，因此不会被反转。关掉厂商软件里的平滑滚动后，齿格滚轮才会反转。

## 构建

在装有 Xcode 的 Mac 上：

```sh
swift test
./scripts/build-app.sh
./scripts/verify-package.sh
```

产物在 `dist/`：`个人工具.app`、`PersonalTools-<版本>-macOS.zip`、同名 `.dmg`，以及 `package-report.txt`。

GitHub Actions 工作流 `.github/workflows/build.yml` 在 `macos-26` 上跑测试、打通用二进制包，并上传 artifact。推送 `v*` 标签时，同一次构建会发布 GitHub Release。发布用的是 Actions 自带的 `GITHUB_TOKEN`，仓库里不放 Apple 证书或密钥。

这台开发环境如果是 Linux，只能跑 `PersonalToolsCore` 的单元测试，不能编译 `.app`。不要把 Linux 上的文件说成 macOS 安装包。

## 测试范围

已覆盖的纯逻辑（Linux 和 macOS 都能跑）：

- Command 两次按下/松开的时间窗口
- Command-C、Command-Tab、按住、Shift/Option/Control 不会误触发
- 滚轮事件不会打断这个手势，也不会被手势监听吃掉
- Cocoa / Quartz 坐标、Retina 像素、多显示器接缝、取样矩形、放大镜位置
- 取色状态机、HEX、偏好默认值和各开关互不影响
- 事件 tap 的掩码：滚轮 tap 只有滚轮；取色 tap 只有左键和 keyDown，且只在放大镜出现时吞掉左键和 Esc

macOS 工作流额外核对 `CGEventType`、修饰键掩码，以及像素缓冲的上下方向，并检查成品的架构、最低系统版本和 ad-hoc 签名。

没有在真机上点过菜单、滚轮或取色放大镜，也没有看过系统权限弹窗。这些在下面的说明里标成未验证。

---

# Personal Tools

Menu-bar utilities for macOS 13 or later:

- Reverse a discrete mouse wheel, leaving trackpad and Magic Mouse natural scrolling alone. Derived from [mouse-scroll-flip](https://github.com/yerled/mouse-scroll-flip) (MIT).
- Pick a screen color by double-tapping Command (two press-and-release cycles). The loupe magnifies pixels with a crosshair and a live HEX value. Click copies `#RRGGBB`. Escape cancels.

The app UI is Chinese. There is no account, telemetry, or network client.

The download is a universal **ad-hoc signed** binary. It is **not notarized**.

Install by dragging `个人工具.app` to Applications, then Control-click → Open. If Gatekeeper reports a damaged app:

```sh
xattr -dr com.apple.quarantine "/Applications/个人工具.app"
```

Grant Accessibility and Screen Recording. Leave Natural scrolling on. Quit the standalone Mouse Scroll Flip app so the wheel is not inverted twice.

Holding Command, or using Command with another key, does not open the loupe. Scroll events are not part of the picker tap. Escape and the selecting click are consumed only while the loupe is visible.

```sh
swift test
./scripts/build-app.sh
./scripts/verify-package.sh
```

The GitHub Actions workflow builds on a macOS runner. A `v*` tag publishes a Release with the zip and dmg. No Apple credentials are stored in the repo.
