# Sing-Box Hysteria2 & Reality 快速配置脚本 (ml.sh)

作者：米粒儿  TG群：@https://t.me/mlkjfx6  NL论坛：@https:/nodeloc.com


## 使用方法

### 1. 下载并运行脚本

```bash
wget -O ml.sh https://raw.githubusercontent.com/charmtv/vlhy2/main/ml.sh && chmod +x ml.sh && ./ml.sh
```
或者
```bash
bash <(curl -sSL https://raw.githubusercontent.com/charmtv/vlhy2/main/ml.sh)
```

### 2. 再次运行脚本

```bash
sudo bash ml.sh
```

脚本将以 root 权限运行，并显示主菜单。

### 3. 菜单选项说明

脚本启动后，你会看到类似如下的菜单：

```
================================================
 Sing-Box Hysteria2 & Reality 管理脚本 
================================================
 作者:        米粒儿
 TG群:        https://t.me/mlkjfx6
 NL论坛:      https:/nodeloc.com
 今日安装:    3 次
 总计安装:    15 次
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
  10. 编辑当前配置文件 (nano/vim)
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

### 4. 安装统计功能

脚本会自动统计安装使用情况：

*   **今日安装次数**：当天成功执行安装操作（选项 1、2、3）的次数，每天午夜后自动重置
*   **总计安装次数**：累计成功执行安装操作的总次数，永久保存
*   **统计显示**：在主菜单顶部实时显示安装统计信息
*   **数据持久化**：统计数据保存在 `/usr/local/etc/sing-box/.install_count` 文件中

注意：只有完成实际安装操作时才会增加计数，查看配置、管理服务等操作不会影响统计。

### 注意事项

*   **配置文件**: Sing-Box 的主配置文件位于 `/usr/local/etc/sing-box/config.json`。Hysteria2 使用的自签名证书位于 `/etc/hysteria/`。
*   **持久化信息**: 上次成功安装的导入参数会保存在 `/usr/local/etc/sing-box/.last_singbox_script_info` 文件中，以便下次运行时通过菜单查看。卸载时如果选择删除配置目录，此文件也会被删除。
*   **安装统计**: 安装次数统计数据保存在 `/usr/local/etc/sing-box/.install_count` 文件中，卸载时会一并删除。
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
