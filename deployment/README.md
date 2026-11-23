# EGA 客户端 Windows 本地部署

源码位于 `../RM26_Client`，上游为 https://github.com/ClearWei/RM26_Client ，本次基础版本为 `e291f2f65f5a5924509e4e2fe1b148ff9d4b24af`。

本地部署采用 Windows 原生 UCRT64 工具链。工具与依赖安装在 `%USERPROFILE%\RMTools\msys64`，没有覆盖系统 PATH；启动、构建脚本只修改当前进程及其子进程的环境。

项目源码和构建产物都在当前项目中。`%USERPROFILE%\RMTools\terminal-workspace` 是指向当前项目的目录联接，用于避免中文路径影响编译工具，不是第二份源码。

## 构建

在项目根目录的 PowerShell 中执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\deployment\build-windows.ps1
```

可执行文件：`RM26_Client\build\windows\RoboMasterClient2025.exe`。沿用上游的兼容程序名称。

## 本地联调

```powershell
powershell -ExecutionPolicy Bypass -File .\deployment\start-local.ps1
```

启动本地 MQTT Broker、Python 模拟器和客户端。打开 http://127.0.0.1:8000/ 操作模拟控制台。首次客户端可能需要在其界面选择机器人身份并登录。

上游默认进入指挥屏的大地图。`M` 在大地图和普通指挥屏之间切换；`P` 打开设置；设置中按 `1` 后按回车可选择并登录红方1号。`Ctrl+T` 切换指挥屏与机器人操作视图。窗口需处于前台，快捷键才会正常工作。

只启动服务、不启动桌面客户端：

```powershell
powershell -ExecutionPolicy Bypass -File .\deployment\start-local.ps1 -NoClient
```

停止本脚本启动的进程：

```powershell
powershell -ExecutionPolicy Bypass -File .\deployment\stop-local.ps1
```

脚本遇到端口占用会报错，不结束已有进程。关闭进程前会核对进程启动时间，避免 PID 被复用后结束其他程序。

本地参数：MQTT `127.0.0.1:3333`、机器人 ID `1`、Web `127.0.0.1:8000`、主图传 UDP `3334`。保留官方示例配置到 `RM26_Client/config.json`，没有接入真实赛事服务器。日志位于 `.local/runtime`；客户端另有上游自己的运行日志。

初始不发送模拟视频。在模拟控制台上传自己的测试视频，再按控制台功能启动视频；主图传和额外工业相机的路径不同，详见上游 `docs/getting-started/configuration.md`。

## 依赖

MSYS2 UCRT64：GCC、CMake、Ninja、Qt6 Base/Declarative/Multimedia/SerialPort/Svg、Protobuf、Abseil、Paho MQTT C、FFmpeg、Mosquitto。客户端必须用同一套 UCRT64 编译器和依赖构建，避免混入本机其他 MinGW 或 MSVC 的库。

模拟器使用 `RM26_Client/sim/.venv`，基于 Python 3.12，安装命令为 `python -m pip install -e RM26_Client/sim`。本次 Python 包版本记录在 `sim-requirements.lock.txt`；其中不包括 editable 项目本身。

这是 2026 项目的本地部署。2027 通信协议、官方设备接入和比赛机制仍需另行适配与实测。

## 本次验证（2026-10-18）

- Windows 原生 Release 构建成功，MQTT 和 FFmpeg 功能均启用；上游客户端源码未修改。
- CTest：排除 Linux Shell 依赖检查后，26/26 通过，包括 H.264 解码测试。
- 模拟器赛事引擎与协议核心测试：22/22 通过；地图 JavaScript 测试：3/3 通过。
- 全量模拟器 Python 测试：23项通过，5项 Shell 启动契约测试在原生 Windows 下因 `.sh` 执行方式失败；本次提供了 PowerShell 启停脚本，并实际验证服务启动、停止、重启和端口释放。
- Web 控制台返回 HTTP 200；MQTT 实际收到并成功解析 `GameStatus`、`GlobalUnitStatus` 和 `RobotStaticStatus`。
- 客户端桌面窗口正常启动并显示比赛状态；生成了640×360、15 fps测试视频，通过模拟器传输，客户端日志确认UDP组帧完整及H.265成功解码。此次没有完成所有视图下的视频呈现验证，也没有连接真实相机或裁判系统。
- 没有安装可选 ONNX Runtime 和 Qt WebEngine，因此相应检测叠加和网页播放功能关闭。

构建日志：`.local/build-windows.log`；C++测试日志：`.local/ctest-windows.log`；模拟器测试日志：`.local/sim-core-tests.log`。详细依赖版本见本目录两个lock文件。

## 本地修复：结算界面哨兵血量闪动

`src/ui/MainWindow.cpp` 的三个结算统计入口原来会比较哨兵和比赛状态的最新更新时间。比赛状态消息频率更高，导致有效血量交替被判为过期并显示为0。现改为读取最近收到的血量快照；初始化未上报的机器人血量本来就是0。

已重新构建、重启客户端，保留运行中的模拟器。GameData、结算控件、主窗口交互三项相关测试通过；在实际结算界面连续采样20帧，包含双方哨兵血量的区域图像完全一致。修复构建与测试日志分别为 `.local/build-sentry-fix.log`、`.local/ctest-sentry-fix.log`。
