# RoboMaster 自定义终端：Windows 本地开发版

本项目基于复旦星云 EGA 的 [RM26_Client](https://github.com/ClearWei/RM26_Client)，用于在 Windows 上开发和验证 RoboMaster 自定义终端。客户端可以通过本地模拟器接收比赛状态，并验证图传的接收、组帧与解码。

## 本地工作

- 配置 Windows 原生构建，使用 MSYS2 UCRT64、Qt 6、Protobuf、Paho MQTT 和 FFmpeg。
- 提供一键启停脚本，用于运行客户端、本地 MQTT 服务和比赛模拟器。
- 修复结算页哨兵血量反复跳到 0 的问题。原先用更新更频繁的比赛状态时间戳判断血量是否有效；现在读取最近收到的血量。原部署中三项相关测试通过，结算页连续采样 20 帧，血量区域保持稳定。

## 在本机运行

本机工具链位于 `%USERPROFILE%\RMTools\msys64`。迁移时没有复制旧构建缓存、Python 虚拟环境或本地配置；首次运行前请在本目录重新创建环境并构建。以下命令在 PowerShell 中执行：

```powershell
python -m venv .\RM26_Client\sim\.venv
& .\RM26_Client\sim\.venv\Scripts\python.exe -m pip install -e .\RM26_Client\sim
powershell -NoProfile -ExecutionPolicy Bypass -File .\deployment\build-windows.ps1
```

构建后双击 `Start-Local.cmd`，打开 [模拟器控制台](http://127.0.0.1:8000/)。默认 MQTT 为 `127.0.0.1:3333`，机器人 ID 为 1。结束时双击 `Stop-Local.cmd`。若旧目录的服务仍在运行，先用旧目录的停止脚本释放端口。

更多依赖见[部署说明](deployment/README.md)。上游 MIT 许可证和素材授权清单保留在客户端目录。

## 实物链路

海康相机帧由机载桥接编码为 H.264，经 USB 转 TTL 写入 VT03 的 0x0310 串口。VT13 接收后由官方选手端通过 MQTT CustomByteBlock 转发，复旦客户端解码。F6 切换海康与主图传。当前部署已验证实物出图，使用彩色、完整 4:3 视野、有效 360×270、8 FPS、80 kbps，并以 50 包/秒为发送上限。

- [机载桥接补丁和应用步骤](onboard/README.md)
- [Windows 同机启动脚本](deployment/start-same-pc-client.ps1)
- [台架协议模拟脚本](tools/armcam_simulate.py)

## 构建资源

本仓库提交客户端和模拟器源码。上游图像、音频及演示媒体从[复旦项目固定版本](https://github.com/ClearWei/RM26_Client/tree/e291f2f65f5a5924509e4e2fe1b148ff9d4b24af)获取。在该版本的完整 checkout 中覆盖本仓库 RM26_Client 内的文件，再按客户端说明构建；也可以将上游资源复制到 RM26_Client 中对应的相对位置。本地 config.json 从 config.example.json 新建。
