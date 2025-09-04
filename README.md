# Sing-Box Hysteria2 & Reality 快速配置脚本

作者：米粒儿  TG群：@https://t.me/mlkjfx6

一个用于在 Linux 服务器上快速安装、配置和管理 [Sing-Box](https://github.com/SagerNet/sing-box) 的 Shell 脚本，特别针对 Hysteria2 和 VLESS Reality 协议进行了优化。

## 特性

*   **一键安装 Sing-Box (beta 版)**：自动从官方渠道下载并安装最新 beta 版本的 Sing-Box。
*   **多种安装模式**：
    *   同时安装 Hysteria2 和 Reality (VLESS) 服务，实现共存。
    *   单独安装 Hysteria2 服务。
    *   单独安装 Reality (VLESS) 服务。
*   **自动化配置**：
    *   Hysteria2: 自动生成自签名证书、随机密码。
    *   Reality (VLESS): 自动生成 UUID、Reality Keypair (私钥和公钥)。
    *   自动填充生成的凭证到 `config.json` 配置文件。
    *   用户可自定义监听端口、伪装域名 (SNI) 等关键参数。
*   **Systemd 服务管理**：
    *   自动创建并配置 Sing-Box 的 systemd 服务。
    *   方便地启动、停止、重启、查看服务状态及日志。
    *   设置开机自启。
*   **导入信息与二维码**：
    *   安装完成后，自动显示详细的客户端导入参数。
    *   如果系统已安装 `qrencode`，则会直接在终端显示导入链接的二维码。
    *   支持随时查看上次成功安装的配置信息及二维码。
*   **依赖自动处理**：
    *   自动检测核心依赖 (`curl`, `openssl`, `jq`) 和可选依赖 (`qrencode`)。
    *   如果依赖缺失，会提示用户并尝试通过系统包管理器 (apt, yum, dnf) 自动安装。
*   **便捷管理**：
    *   提供菜单式交互界面，操作简单直观。
    *   支持查看和编辑 Sing-Box 配置文件 (使用 `nano`)。
    *   一键更新 Sing-Box 内核。
    *   一键卸载 Sing-Box 及相关配置。
*   **信息持久化**：上次成功安装的配置参数会被保存，方便后续通过菜单再次查看。

## 环境要求

*   Linux (x86_64 / amd64, aarch64 / arm64 架构理论上支持，未全面测试)
*   root 权限 (脚本内操作需要 sudo)
*   核心依赖: `curl`, `openssl`, `jq` (脚本会尝试自动安装)
*   可选依赖: `qrencode` (用于显示二维码，脚本会尝试自动安装)

## 使用方法

### 1. 下载并运行脚本

```bash
wget -O lvhy.sh https://raw.githubusercontent.com/Netflixxp/vlhy2/main/lvhy.sh && chmod +x lvhy.sh && ./lvhy.sh
```
或者
```bash
bash <(curl -sSL https://raw.githubusercontent.com/Netflixxp/vlhy2/main/lvhy.sh)
```

### 2. 再次运行脚本

```bash
sudo bash lvhy.sh
```

脚本将以 root 权限运行，并显示主菜单。

### 3. 菜单选项说明

脚本启动后，你会看到类似如下的菜单：

```
================================================
 Sing-Box Hysteria2 & Reality 管理脚本 
================================================
 作者:      米粒儿
 TG群:      https://t.me/mlkjfx6
================================================
安装选项:
  1. 安装 Hysteria2 + Reality (共存)
  2. 单独安装 Hysteria2
  3. 单独安装 Reality (VLESS)
------------------------------------------------
管理选项:
  4. 启动 Sing-box 服务
  5. 停止 Sing-box 服务
  6. 重启 Sing-box 服务
  7. 查看 Sing-box 服务状态
  8. 查看 Sing-box 实时日志
  9. 查看当前配置文件
  10. 编辑当前配置文件 (使用 nano)
  11. 显示上次保存的导入信息 (含二维码)
------------------------------------------------
其他选项:
  12. 更新 Sing-box 内核 (使用官方beta脚本)
  13. 卸载 Sing-box
  0. 退出脚本
================================================
请输入选项 [0-13]: 
```

根据提示输入数字选择相应功能即可。

**初次使用建议：**

*   选择 `1`, `2`, 或 `3` 进行安装。脚本会引导你输入必要的参数（如端口、SNI 等），大部分参数有默认值可直接回车使用。
*   安装成功后，脚本会显示客户端导入所需的全部信息，包括文本参数和二维码（如果 `qrencode` 已安装）。请妥善保存这些信息。
*   之后你可以使用选项 `11` 再次查看这些信息。

### 注意事项

*   **配置文件**: Sing-Box 的主配置文件位于 `/usr/local/etc/sing-box/config.json`。Hysteria2 使用的自签名证书位于 `/etc/hysteria/`。
*   **持久化信息**: 上次成功安装的导入参数会保存在 `/usr/local/etc/sing-box/.last_singbox_script_info` 文件中，以便下次运行时通过菜单查看。卸载时如果选择删除配置目录，此文件也会被删除。
*   **SNI (伪装域名)**:
    *   对于 Reality，选择一个响应良好且不易被GFW干扰的SNI（如 `www.microsoft.com`, `www.apple.com` 等）非常重要。脚本会让你自定义。
    *   对于 Hysteria2 的自签名证书，SNI 主要用于客户端验证，默认使用 `bing.com`，你也可以自定义。
*   **端口占用**: 请确保你为 Hysteria2 和 Reality 选择的监听端口未被其他程序占用。脚本默认 Hysteria2 使用 `8443`，Reality 使用 `443`。
*   **防火墙**: 如果你的服务器启用了防火墙 (如 ufw, firewalld)，请确保放行 Sing-Box 使用的端口。
    例如，如果使用 ufw 并且 Reality 使用 443 端口，Hysteria2 使用 8443 端口：
    ```bash
    sudo ufw allow 443/tcp
    sudo ufw allow 8443/tcp
    sudo ufw allow 8443/udp # Hysteria2 需要 UDP
    sudo ufw reload
    ```

## 贡献

欢迎提交 Pull Requests 或在 Issues 中报告错误、提出建议。

## 免责声明

*   本脚本仅为学习和测试目的提供。
*   请遵守当地法律法规，不要将此脚本用于非法用途。
*   作者不对使用此脚本可能造成的任何后果负责。

## 致谢

*   [Sing-Box](https://github.com/SagerNet/sing-box) 项目及其开发者。
*   所有为开源社区做出贡献的人。