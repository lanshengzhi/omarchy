# Omarchy

Omarchy 是一个基于 Hyprland 的桌面环境发行层。其桌面 UI 由单一长期运行的 Quickshell 进程（omarchy-shell）托管，一切可视功能都是插件。

## Language

### Shell 架构

**Shell**:
长期运行的单一 Quickshell 进程（入口 `shell/shell.qml`），托管整个桌面 UI。状态栏、通知、锁屏、面板全部作为插件运行在它内部。
_Avoid_: 桌面进程、UI 守护进程

**Plugin**:
带 `manifest.json` 的目录（第一方在 `shell/plugins/` 下，第三方在 `~/.config/omarchy/plugins/<id>/`），声明 id、`kinds` 和入口 QML 文件，由 PluginRegistry 发现、校验和加载。
_Avoid_: 组件、模块、扩展（extension）

**Kind**:
插件清单中声明的角色类型，决定插件以什么形态被加载。六种：`bar-widget`、`bar`、`panel`、`overlay`、`menu`、`service`。一个清单可声明多种 kind。
_Avoid_: 类型、类别（type/category）

**Bar Widget**:
kind 为 `bar-widget` 的插件——被激活状态栏放进某个分区（left/center/right）的组件。启用/禁用等价于"是否在状态栏占位"。
_Avoid_: 状态栏插件、指示器

**Bar**:
kind 为 `bar` 的插件——完整状态栏实现，可整体替换内置的 `omarchy.bar`。同时只有一个处于激活状态；没有"关闭"态，启用一个即替换当前 bar。
_Avoid_: 面板栏、顶栏

**Panel**:
kind 为 `panel` 的插件——浮动窗口式表面（如 OSD）。被召唤（summon）时才加载。
_Avoid_: 窗口、对话框

**Overlay**:
kind 为 `overlay` 的插件——全屏浮层（如背景选择器、剪贴板管理器）。被召唤时才加载。
_Avoid_: 弹窗、模态框

**Menu**:
kind 为 `menu` 的插件——被召唤的菜单表面（如应用菜单）。
_Avoid_: 下拉框、上下文菜单

**Service**:
kind 为 `service` 的插件——无 UI 的后台单例（如电池、锁屏、通知服务）。第一方 service 在 shell 启动时加载。
_Avoid_: 守护进程、后台任务

### 生命周期

**Summon**:
通过 IPC（`omarchy-shell shell summon <id> <payloadJson>`）加载并打开一个 panel/overlay/menu 插件的动作。对应动作是 `hide`。
_Avoid_: 打开、启动（open/launch）

**keepLoaded**:
清单字段。为 `true` 时插件在两次召唤之间保持加载，不随 hide 卸载。
