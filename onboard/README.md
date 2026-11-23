# 海康机载桥接

机载改动以补丁分发。上游桥接仓库未提供独立许可证文件；完整上游代码及 SDK 由上游提供。本仓库保留机载端改动、示例相机配置和可调整的 systemd 单元补丁。

在机载电脑的 Linux 终端中获取上游并应用补丁：

~~~bash
git clone https://github.com/dkjsiogu/minimal_hik_gimbal_bridge.git
cd minimal_hik_gimbal_bridge
git checkout 249579adbaf9461fc927430fedaa3693c77bd316
git apply --check /path/to/RM-Custom-Terminal/onboard/bridge.patch
git apply /path/to/RM-Custom-Terminal/onboard/bridge.patch
chmod +x scripts/run-onboard.sh
cp /path/to/RM-Custom-Terminal/onboard/bridge.onboard.example.yaml config/bridge.onboard.yaml
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
~~~

按设备调整 YAML 中的相机序列号和串口。运行脚本前安装本机所需的 MVS 运行库、OpenCV 和 FFmpeg。systemd 示例在应用补丁后位于 deploy/onboard，安装前请按实际账户、目录和 USB 转串口路径调整。默认彩色配置保留完整视野、轻度降噪、静态区域简化及暗部提亮。可选的灰度编码保留在源代码中。
