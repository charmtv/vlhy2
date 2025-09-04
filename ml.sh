#!/bin/bash

# Script for Sing-Box Hysteria2 & Reality Management

# --- Author Information ---
AUTHOR_NAME="米粒儿"
TG_GROUP_URL="https://t.me/mlkjfx6"
NL_FORUM_URL="https:/nodeloc.com"

# --- Configuration ---
SINGBOX_INSTALL_PATH_EXPECTED="/usr/local/bin/sing-box"
SINGBOX_CONFIG_DIR="/usr/local/etc/sing-box"
SINGBOX_CONFIG_FILE="${SINGBOX_CONFIG_DIR}/config.json"
SINGBOX_SERVICE_FILE="/etc/systemd/system/sing-box.service"

HYSTERIA_CERT_DIR="/etc/hysteria" # 针对自签名证书
HYSTERIA_CERT_KEY="${HYSTERIA_CERT_DIR}/private.key"
HYSTERIA_CERT_PEM="${HYSTERIA_CERT_DIR}/cert.pem"

# 用于持久存储上次配置信息的文件
PERSISTENT_INFO_FILE="${SINGBOX_CONFIG_DIR}/.last_singbox_script_info"

# 安装次数统计文件
INSTALL_COUNT_FILE="${SINGBOX_CONFIG_DIR}/.install_count"

# 默认值
DEFAULT_HYSTERIA_PORT="8443"
DEFAULT_REALITY_PORT="443"
DEFAULT_HYSTERIA_MASQUERADE_CN="bing.com"
DEFAULT_REALITY_SNI="www.tesla.com"

# 全局 SINGBOX_CMD
SINGBOX_CMD=""

# 全局变量，用于存储上次生成的配置信息 (将从文件加载)
LAST_SERVER_IP=""
LAST_HY2_PORT=""
LAST_HY2_PASSWORD=""
LAST_HY2_MASQUERADE_CN=""
LAST_HY2_LINK=""
LAST_REALITY_PORT=""
LAST_REALITY_UUID=""
LAST_REALITY_PUBLIC_KEY="" # 公钥需要显示
LAST_REALITY_SNI=""
LAST_REALITY_SHORT_ID="0123456789abcdef" # 默认值
LAST_REALITY_FINGERPRINT="chrome"    # 默认值
LAST_VLESS_LINK=""
LAST_INSTALL_MODE="" # "all", "hysteria2", "reality", 或 ""

# 安装次数统计
TODAY_INSTALL_COUNT=0
TOTAL_INSTALL_COUNT=0
LAST_INSTALL_DATE=""

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # 无颜色

# --- 辅助函数 ---
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

print_author_info() {
    echo -e "${MAGENTA}${BOLD}================================================${NC}"
    echo -e "${CYAN}${BOLD} Sing-Box Hysteria2 & Reality 管理脚本 ${NC}"
    echo -e "${MAGENTA}${BOLD}================================================${NC}"
    echo -e " ${YELLOW}作者:${NC}        ${GREEN}${AUTHOR_NAME}${NC}"
    echo -e " ${YELLOW}TG群:${NC}        ${UNDERLINE}${BLUE}${TG_GROUP_URL}${NC}"
    echo -e " ${YELLOW}NL论坛:${NC}      ${UNDERLINE}${BLUE}${NL_FORUM_URL}${NC}"
    echo -e " ${YELLOW}今日安装:${NC}    ${GREEN}${TODAY_INSTALL_COUNT}${NC} 次"
    echo -e " ${YELLOW}总计安装:${NC}    ${GREEN}${TOTAL_INSTALL_COUNT}${NC} 次"
    echo -e "${MAGENTA}${BOLD}================================================${NC}"
}

load_persistent_info() {
    if [ -f "$PERSISTENT_INFO_FILE" ]; then
        info "加载上次保存的配置信息从: $PERSISTENT_INFO_FILE"
        # Source 文件以加载变量。
        # 确保文件只包含安全格式的变量赋值。
        # 例如: LAST_SERVER_IP="1.2.3.4"
        source "$PERSISTENT_INFO_FILE"
        success "配置信息加载完成。"
    else
        info "未找到持久化的配置信息文件。"
    fi
}

save_persistent_info() {
    info "正在保存当前配置信息到: $PERSISTENT_INFO_FILE"
    # 如果目录不存在则创建 (例如，卸载配置目录后首次运行)
    mkdir -p "$(dirname "$PERSISTENT_INFO_FILE")"
    # 将变量赋值写入文件，覆盖原有文件。
    # 重要: 确保带空格或特殊字符的值被正确引用。
    cat > "$PERSISTENT_INFO_FILE" <<EOF
LAST_SERVER_IP="${LAST_SERVER_IP}"
LAST_HY2_PORT="${LAST_HY2_PORT}"
LAST_HY2_PASSWORD="${LAST_HY2_PASSWORD}"
LAST_HY2_MASQUERADE_CN="${LAST_HY2_MASQUERADE_CN}"
LAST_HY2_LINK="${LAST_HY2_LINK}"
LAST_REALITY_PORT="${LAST_REALITY_PORT}"
LAST_REALITY_UUID="${LAST_REALITY_UUID}"
LAST_REALITY_PUBLIC_KEY="${LAST_REALITY_PUBLIC_KEY}"
LAST_REALITY_SNI="${LAST_REALITY_SNI}"
LAST_REALITY_SHORT_ID="${LAST_REALITY_SHORT_ID}"
LAST_REALITY_FINGERPRINT="${LAST_REALITY_FINGERPRINT}"
LAST_VLESS_LINK="${LAST_VLESS_LINK}"
LAST_INSTALL_MODE="${LAST_INSTALL_MODE}"
EOF
    if [ $? -eq 0 ]; then
        success "配置信息保存成功。"
    else
        error "配置信息保存失败。"
    fi
}

load_install_count() {
    if [ -f "$INSTALL_COUNT_FILE" ]; then
        # 文件格式: TODAY_COUNT|TOTAL_COUNT|LAST_DATE
        local file_content=$(cat "$INSTALL_COUNT_FILE" 2>/dev/null)
        if [ -n "$file_content" ]; then
            TODAY_INSTALL_COUNT=$(echo "$file_content" | cut -d'|' -f1)
            TOTAL_INSTALL_COUNT=$(echo "$file_content" | cut -d'|' -f2)
            LAST_INSTALL_DATE=$(echo "$file_content" | cut -d'|' -f3)
            
            # 验证数值是否有效
            if ! [[ "$TODAY_INSTALL_COUNT" =~ ^[0-9]+$ ]]; then
                TODAY_INSTALL_COUNT=0
            fi
            if ! [[ "$TOTAL_INSTALL_COUNT" =~ ^[0-9]+$ ]]; then
                TOTAL_INSTALL_COUNT=0
            fi
            
            # 检查是否是新的一天，如果是则重置今日计数
            local current_date=$(date +%Y-%m-%d)
            if [ "$LAST_INSTALL_DATE" != "$current_date" ]; then
                TODAY_INSTALL_COUNT=0
                LAST_INSTALL_DATE="$current_date"
            fi
        else
            TODAY_INSTALL_COUNT=0
            TOTAL_INSTALL_COUNT=0
            LAST_INSTALL_DATE=$(date +%Y-%m-%d)
        fi
    else
        TODAY_INSTALL_COUNT=0
        TOTAL_INSTALL_COUNT=0
        LAST_INSTALL_DATE=$(date +%Y-%m-%d)
    fi
}

save_install_count() {
    # 确保目录存在
    mkdir -p "$(dirname "$INSTALL_COUNT_FILE")"
    # 保存格式: TODAY_COUNT|TOTAL_COUNT|LAST_DATE
    echo "${TODAY_INSTALL_COUNT}|${TOTAL_INSTALL_COUNT}|${LAST_INSTALL_DATE}" > "$INSTALL_COUNT_FILE" 2>/dev/null
}

increment_install_count() {
    load_install_count
    TODAY_INSTALL_COUNT=$((TODAY_INSTALL_COUNT + 1))
    TOTAL_INSTALL_COUNT=$((TOTAL_INSTALL_COUNT + 1))
    LAST_INSTALL_DATE=$(date +%Y-%m-%d)
    save_install_count
}


check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "此脚本需要以 root 权限运行。请使用 'sudo bash $0'"
        exit 1
    fi
}

attempt_install_package() {
    local package_name="$1"
    local friendly_name="${2:-$package_name}" # 如果第二个参数未提供，则使用包名本身

    if command -v "$package_name" &>/dev/null; then
        return 0 # 已安装
    fi

    # 提示用户是否安装
    read -p "依赖 '${friendly_name}' 未安装。是否尝试自动安装? (y/N): " install_confirm
    if [[ ! "$install_confirm" =~ ^[Yy]$ ]]; then
        warn "跳过安装 '${friendly_name}'。某些功能可能因此不可用或显示不完整。"
        return 1 # 用户选择不安装
    fi

    info "正在尝试安装 '${friendly_name}'..."
    if command -v apt-get &>/dev/null; then
        apt-get update -y && apt-get install -y "$package_name"
    elif command -v yum &>/dev/null; then
        yum install -y "$package_name"
    elif command -v dnf &>/dev/null; then
        dnf install -y "$package_name"
    else
        error "未找到已知的包管理器 (apt, yum, dnf)。请手动安装 '${friendly_name}'。"
        return 1 # 未知包管理器
    fi

    # 再次检查是否安装成功
    if command -v "$package_name" &>/dev/null; then
        success "'${friendly_name}' 安装成功。"
        return 0
    else
        error "'${friendly_name}' 安装失败。请检查错误信息并尝试手动安装。"
        return 1 # 安装失败
    fi
}


check_dependencies() {
    info "检查核心依赖..."
    local core_deps=("curl" "openssl" "jq") # jq 用于解析 JSON (如果需要)
    local all_deps_met=true
    for dep in "${core_deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            if ! attempt_install_package "$dep"; then
                all_deps_met=false
            fi
        fi
    done

    if ! $all_deps_met; then
        error "部分核心依赖未能安装。脚本可能无法正常运行。请手动安装后重试。"
        exit 1
    fi
    success "核心依赖检查通过。"
}

# 此函数现在仅检查/安装 qrencode 并返回状态。
# 它在显示信息前被调用一次。
check_and_prepare_qrencode() {
    if ! command -v qrencode &>/dev/null; then
        if attempt_install_package "qrencode" "二维码生成工具(qrencode)"; then
            return 0 # qrencode 安装成功
        else
            warn "未安装 'qrencode'。将无法生成二维码。"
            return 1 # qrencode 未安装或安装失败
        fi
    fi
    return 0 # qrencode 已存在
}


find_and_set_singbox_cmd() {
    if [ -x "$SINGBOX_INSTALL_PATH_EXPECTED" ]; then
        SINGBOX_CMD="$SINGBOX_INSTALL_PATH_EXPECTED"
    elif command -v sing-box &>/dev/null; then
        SINGBOX_CMD=$(command -v sing-box)
    else
        SINGBOX_CMD=""
    fi
    if [ -n "$SINGBOX_CMD" ]; then
        info "Sing-box 命令已设置为: $SINGBOX_CMD"
    else
        warn "初始未找到 Sing-box 命令。"
    fi
}


get_server_ip() {
    SERVER_IP=$(curl -s --max-time 5 ip.sb || curl -s --max-time 5 https://api.ipify.org || curl -s --max-time 5 https://checkip.amazonaws.com)
    if [ -z "$SERVER_IP" ]; then
        warn "无法自动获取服务器公网 IP。你可能需要手动配置客户端。"
        read -p "请输入你的服务器公网 IP (留空则尝试从hostname获取): " MANUAL_SERVER_IP
        if [ -n "$MANUAL_SERVER_IP" ]; then
            SERVER_IP="$MANUAL_SERVER_IP"
        else
            SERVER_IP=$(hostname -I | awk '{print $1}') # 如果所有其他方法失败，则回退到本地IP
            if [ -z "$SERVER_IP" ]; then
                warn "无法从hostname获取IP，请确保网络连接正常或手动输入。"
            fi
        fi
    fi
    # 进一步验证IP是否为公网IP (简单检查)
    if [[ "$SERVER_IP" =~ ^10\. || "$SERVER_IP" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. || "$SERVER_IP" =~ ^192\.168\. ]]; then
        warn "检测到的 IP (${SERVER_IP}) 似乎是私有IP。如果这是公网服务器，请手动输入正确的公网IP。"
        read -p "请再次输入你的服务器公网 IP (如果上面的IP不正确): " OVERRIDE_SERVER_IP
        if [ -n "$OVERRIDE_SERVER_IP" ]; then
            SERVER_IP="$OVERRIDE_SERVER_IP"
        fi
    fi
    info "检测到服务器 IP: ${SERVER_IP}"
    LAST_SERVER_IP="$SERVER_IP"
}

generate_random_password() {
    # 生成 URL 安全的密码 (字母数字组合)
    # 原命令: openssl rand -base64 16 # 可能包含 / 和 +
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 16
}

install_singbox_core() {
    if [ -f "$SINGBOX_INSTALL_PATH_EXPECTED" ]; then
        info "Sing-box 已检测到在 $SINGBOX_INSTALL_PATH_EXPECTED."
        find_and_set_singbox_cmd # 确保如果找到，SINGBOX_CMD 被设置
        if [ -n "$SINGBOX_CMD" ]; then
            # 尝试获取版本号，某些旧版sing-box可能没有 'version' 的标准输出格式
            current_version=$($SINGBOX_CMD version | awk '{print $3}' 2>/dev/null)
            if [ -n "$current_version" ]; then
                info "当前版本: $current_version"
            else
                info "无法确定当前版本 (可能是旧版sing-box或命令问题)。"
            fi
        else
            info "无法确定当前版本，因为 sing-box 命令未找到。"
        fi
        read -p "是否重新安装/更新 Sing-box (beta)? (y/N): " reinstall_choice
        if [[ ! "$reinstall_choice" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    info "正在安装/更新 Sing-box (beta)..."
    # 确保官方脚本可执行
    if bash -c "$(curl -fsSL https://sing-box.vercel.app/)" @ install --beta; then
        success "Sing-box 安装/更新成功。"
        find_and_set_singbox_cmd # 安装后重新查找命令
        if [ -z "$SINGBOX_CMD" ]; then
            error "安装后仍无法找到 sing-box 命令。请检查安装和 PATH。"
            return 1
        fi
    else
        error "Sing-box 安装失败。"
        return 1
    fi
    return 0
}

generate_self_signed_cert() {
    local domain_cn="$1"
    if [ -f "$HYSTERIA_CERT_PEM" ] && [ -f "$HYSTERIA_CERT_KEY" ]; then
        info "检测到已存在的证书: ${HYSTERIA_CERT_PEM} 和 ${HYSTERIA_CERT_KEY}"
        existing_cn=$(openssl x509 -in "$HYSTERIA_CERT_PEM" -noout -subject | sed -n 's/.*CN = \([^,]*\).*/\1/p')
        if [ "$existing_cn" == "$domain_cn" ]; then
            info "证书 CN ($existing_cn) 与目标 ($domain_cn) 匹配，跳过重新生成。"
            return 0
        else
            warn "证书 CN ($existing_cn) 与目标 ($domain_cn) 不匹配。"
            read -p "是否使用新的 CN ($domain_cn) 重新生成证书? (y/N): " regen_cert_choice
            if [[ ! "$regen_cert_choice" =~ ^[Yy]$ ]]; then
                info "保留现有证书。"
                return 0
            fi
        fi
    fi

    info "正在为 Hysteria2 生成自签名证书 (CN=${domain_cn})..."
    mkdir -p "$HYSTERIA_CERT_DIR"
    openssl ecparam -genkey -name prime256v1 -out "$HYSTERIA_CERT_KEY"
    openssl req -new -x509 -days 36500 -key "$HYSTERIA_CERT_KEY" -out "$HYSTERIA_CERT_PEM" -subj "/CN=${domain_cn}"
    if [ $? -eq 0 ]; then
        success "自签名证书生成成功。"
        info "证书: ${HYSTERIA_CERT_PEM}"
        info "私钥: ${HYSTERIA_CERT_KEY}"
    else
        error "自签名证书生成失败。"
        return 1
    fi
}

generate_reality_credentials() {
    if [ -z "$SINGBOX_CMD" ]; then
        error "Sing-box command (SINGBOX_CMD) 未设置。无法生成凭证。"
        find_and_set_singbox_cmd
        if [ -z "$SINGBOX_CMD" ]; then
            error "尝试查找后 Sing-box command 仍未设置。"
            return 1
        fi
    fi
    info "使用命令 '$SINGBOX_CMD' 生成 Reality UUID 和 Keypair..."
    
    info "执行: $SINGBOX_CMD generate uuid"
    REALITY_UUID_VAL=$($SINGBOX_CMD generate uuid)
    CMD_EXIT_CODE=$?
    if [ $CMD_EXIT_CODE -ne 0 ] || [ -z "$REALITY_UUID_VAL" ]; then
        error "执行 '$SINGBOX_CMD generate uuid' 失败 (退出码: $CMD_EXIT_CODE) 或输出为空。"
        error "UUID 命令输出: '$REALITY_UUID_VAL'"
        return 1
    fi
    info "生成的 UUID: $REALITY_UUID_VAL"
    LAST_REALITY_UUID="$REALITY_UUID_VAL"

    info "执行: $SINGBOX_CMD generate reality-keypair"
    KEY_PAIR_OUTPUT=$($SINGBOX_CMD generate reality-keypair)
    CMD_EXIT_CODE=$?
    if [ $CMD_EXIT_CODE -ne 0 ] || [ -z "$KEY_PAIR_OUTPUT" ]; then
        error "执行 '$SINGBOX_CMD generate reality-keypair' 失败 (退出码: $CMD_EXIT_CODE) 或输出为空。"
        error "Keypair 命令输出: '$KEY_PAIR_OUTPUT'"
        return 1
    fi
    info "原始 Keypair 输出:"
    echo "$KEY_PAIR_OUTPUT"
    
    # 从输出中提取 PrivateKey 和 PublicKey
    # 使用 awk 和 xargs 来确保正确提取和去除多余空格
    REALITY_PRIVATE_KEY_VAL=$(echo "$KEY_PAIR_OUTPUT" | awk -F': ' '/PrivateKey:/ {print $2}')
    REALITY_PUBLIC_KEY_VAL=$(echo "$KEY_PAIR_OUTPUT" | awk -F': ' '/PublicKey:/ {print $2}')
    
    REALITY_PRIVATE_KEY_VAL=$(echo "${REALITY_PRIVATE_KEY_VAL}" | xargs) # 去除可能存在的前后空格
    REALITY_PUBLIC_KEY_VAL=$(echo "${REALITY_PUBLIC_KEY_VAL}" | xargs)   # 去除可能存在的前后空格

    if [ -z "$REALITY_UUID_VAL" ] || [ -z "$REALITY_PRIVATE_KEY_VAL" ] || [ -z "$REALITY_PUBLIC_KEY_VAL" ]; then
        error "生成 Reality凭证失败 (UUID, Private Key, 或 Public Key 在解析后为空)."
        error "解析得到的 UUID: '$REALITY_UUID_VAL'"
        error "解析得到的 Private Key: '$REALITY_PRIVATE_KEY_VAL'"
        error "解析得到的 Public Key: '$REALITY_PUBLIC_KEY_VAL'"
        return 1
    fi
    success "Reality UUID: $REALITY_UUID_VAL"
    success "Reality Private Key: $REALITY_PRIVATE_KEY_VAL"
    success "Reality Public Key: $REALITY_PUBLIC_KEY_VAL"
    TEMP_REALITY_PRIVATE_KEY="$REALITY_PRIVATE_KEY_VAL" # 存储到临时变量，用于创建配置文件
    LAST_REALITY_PUBLIC_KEY="$REALITY_PUBLIC_KEY_VAL"   # 存储到全局变量，用于显示和保存
}

create_config_json() {
    local mode="$1" 
    local hy2_port="$2"
    local hy2_password="$3"
    local hy2_masquerade_cn="$4" # Hysteria2 的 SNI 和证书CN
    local reality_port="$5"
    local reality_uuid="$6"
    local reality_private_key="$7"
    local reality_sni="$8" # Reality 的目标 SNI

    if [ -z "$SINGBOX_CMD" ]; then
        error "Sing-box command (SINGBOX_CMD) 未设置。无法校验或格式化配置文件。"
        return 1
    fi

    info "正在创建配置文件: ${SINGBOX_CONFIG_FILE}"
    mkdir -p "$SINGBOX_CONFIG_DIR" # 确保配置目录存在

    local inbounds_json_array=()
    if [ "$mode" == "all" ] || [ "$mode" == "hysteria2" ]; then
        # 注意: Hysteria2 入站中的 masquerade 对于自签名证书不是严格必需的
        # 但某些客户端可能期望它或为将来的 ACME 集成。这里它更像 SNI。
        # 客户端实际的 SNI 在自签名情况下应与证书的CN匹配。
        inbounds_json_array+=( "$(cat <<EOF
        {
            "type": "hysteria2",
            "tag": "hy2-in",
            "listen": "::",
            "listen_port": ${hy2_port},
            "users": [
                {
                    "password": "${hy2_password}"
                }
            ],
            "masquerade": "https://placeholder.services.mozilla.com", 
            "up_mbps": 100,
            "down_mbps": 500,
            "tls": {
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "${HYSTERIA_CERT_PEM}",
                "key_path": "${HYSTERIA_CERT_KEY}",
                "server_name": "${hy2_masquerade_cn}" 
            }
        }
EOF
)" )
    fi

    if [ "$mode" == "all" ] || [ "$mode" == "reality" ]; then
        inbounds_json_array+=( "$(cat <<EOF
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "::",
            "listen_port": ${reality_port},
            "users": [
                {
                    "uuid": "${reality_uuid}",
                    "flow": "xtls-rprx-vision"
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "${reality_sni}",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "${reality_sni}",
                        "server_port": 443
                    },
                    "private_key": "${reality_private_key}",
                    "short_id": [
                        "${LAST_REALITY_SHORT_ID}" 
                    ]
                }
            }
        }
EOF
)" )
    fi

    local final_inbounds_json
    # 将数组元素用逗号连接起来
    final_inbounds_json=$(IFS=,; echo "${inbounds_json_array[*]}")

    cat > "$SINGBOX_CONFIG_FILE" <<EOF
{
    "log": {
        "level": "info",
        "timestamp": true
    },
    "inbounds": [
        ${final_inbounds_json}
    ],
    "outbounds": [
        {
            "type": "direct",
            "tag": "direct"
        },
        {
            "type": "block",
            "tag": "block"
        }
    ],
    "route": {
        "rules": [
            {
                "protocol": "dns",
                "outbound": "direct"
            }
        ]
    }
}
EOF

    info "正在校验配置文件..."
    if $SINGBOX_CMD check -c "$SINGBOX_CONFIG_FILE"; then
        success "配置文件语法正确。"
        info "正在格式化配置文件..."
        if $SINGBOX_CMD format -c "$SINGBOX_CONFIG_FILE" -w; then
            success "配置文件格式化成功。"
        else
            warn "配置文件格式化失败，但语法可能仍正确。"
        fi
    else
        error "配置文件语法错误。请检查 ${SINGBOX_CONFIG_FILE}"
        cat "${SINGBOX_CONFIG_FILE}" # 显示错误的配置文件内容
        return 1
    fi
}

create_systemd_service() {
    if [ -z "$SINGBOX_CMD" ]; then
        error "Sing-box command (SINGBOX_CMD) 未设置。无法创建 systemd 服务。"
        return 1
    fi
    info "创建/更新 systemd 服务: ${SINGBOX_SERVICE_FILE}"
    cat > "$SINGBOX_SERVICE_FILE" <<EOF
[Unit]
Description=Sing-Box Service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=${SINGBOX_CONFIG_DIR}
ExecStart=${SINGBOX_CMD} run -c ${SINGBOX_CONFIG_FILE}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box
    success "Systemd 服务已创建并设置为开机自启。"
}

start_singbox_service() {
    info "正在启动 Sing-box 服务..."
    systemctl restart sing-box
    sleep 2 # 等待服务启动
    if systemctl is-active --quiet sing-box; then
        success "Sing-box 服务启动成功。"
    else
        error "Sing-box 服务启动失败。"
        journalctl -u sing-box -n 20 --no-pager # 显示最近20条日志
        warn "请使用 'systemctl status sing-box' 或 'journalctl -u sing-box -e' 查看详细日志。"
        return 1
    fi
}

display_and_store_config_info() {
    local mode="$1"
    LAST_INSTALL_MODE="$mode" # 这个应该由调用它的安装函数设置

    # 修复问题1: 在开始时一次性检查 qrencode 的可用性
    local qrencode_is_ready=false
    if check_and_prepare_qrencode; then # 如果需要，这里会提示安装
        qrencode_is_ready=true
    fi

    echo -e "----------------------------------------------------"
    if [ "$mode" == "all" ] || [ "$mode" == "hysteria2" ]; then
        # 对于自签名证书, 需要 insecure=1。SNI 应该匹配证书的 CN。
        LAST_HY2_LINK="hy2://${LAST_HY2_PASSWORD}@${LAST_SERVER_IP}:${LAST_HY2_PORT}?sni=${LAST_HY2_MASQUERADE_CN}&alpn=h3&insecure=1#Hy2-${LAST_SERVER_IP}-$(date +%s)"
        echo -e "${GREEN}${BOLD} Hysteria2 配置信息:${NC}"
        echo -e "服务器地址: ${GREEN}${LAST_SERVER_IP}${NC}"
        echo -e "端口: ${GREEN}${LAST_HY2_PORT}${NC}"
        echo -e "密码/Auth: ${GREEN}${LAST_HY2_PASSWORD}${NC}"
        echo -e "SNI/主机名 (用于证书和客户端配置): ${GREEN}${LAST_HY2_MASQUERADE_CN}${NC}"
        echo -e "ALPN: ${GREEN}h3${NC}"
        echo -e "允许不安全 (自签证书): ${GREEN}是/True${NC}"
        echo -e "${CYAN}Hysteria2 导入链接:${NC} ${GREEN}${LAST_HY2_LINK}${NC}"
        
        # 检查 qrencode_is_ready 标志和 qrencode 命令是否存在
        if $qrencode_is_ready && command -v qrencode &>/dev/null; then
            echo "Hysteria2 二维码:"
            qrencode -t ANSIUTF8 "${LAST_HY2_LINK}"
        fi
        echo -e "----------------------------------------------------"
    fi

    if [ "$mode" == "all" ] || [ "$mode" == "reality" ]; then
        LAST_VLESS_LINK="vless://${LAST_REALITY_UUID}@${LAST_SERVER_IP}:${LAST_REALITY_PORT}?security=reality&sni=${LAST_REALITY_SNI}&fp=${LAST_REALITY_FINGERPRINT}&pbk=${LAST_REALITY_PUBLIC_KEY}&sid=${LAST_REALITY_SHORT_ID}&flow=xtls-rprx-vision&type=tcp#Reality-${LAST_SERVER_IP}-$(date +%s)"
        echo -e "${GREEN}${BOLD} Reality (VLESS) 配置信息:${NC}"
        echo -e "服务器地址: ${GREEN}${LAST_SERVER_IP}${NC}"
        echo -e "端口: ${GREEN}${LAST_REALITY_PORT}${NC}"
        echo -e "UUID: ${GREEN}${LAST_REALITY_UUID}${NC}"
        echo -e "传输协议: ${GREEN}tcp${NC}"
        echo -e "安全类型: ${GREEN}reality${NC}"
        echo -e "SNI (伪装域名): ${GREEN}${LAST_REALITY_SNI}${NC}"
        echo -e "Fingerprint: ${GREEN}${LAST_REALITY_FINGERPRINT}${NC}"
        echo -e "PublicKey: ${GREEN}${LAST_REALITY_PUBLIC_KEY}${NC}"
        echo -e "ShortID: ${GREEN}${LAST_REALITY_SHORT_ID}${NC}"
        echo -e "Flow: ${GREEN}xtls-rprx-vision${NC}"
        echo -e "${CYAN}VLESS Reality 导入链接:${NC} ${GREEN}${LAST_VLESS_LINK}${NC}"

        # 检查 qrencode_is_ready 标志和 qrencode 命令是否存在
        if $qrencode_is_ready && command -v qrencode &>/dev/null; then
            echo "Reality (VLESS) 二维码:"
            qrencode -t ANSIUTF8 "${LAST_VLESS_LINK}"
        fi
        echo -e "----------------------------------------------------"
    fi
    # 在显示后，将所有相关的 LAST_ 变量保存到持久化文件
    save_persistent_info
}


# --- 安装函数 ---
install_hysteria2_reality() {
    info "开始安装 Hysteria2 + Reality (共存)..."
    install_singbox_core || return 1
    get_server_ip # 设置 LAST_SERVER_IP

    read -p "请输入 Hysteria2 监听端口 (默认: ${DEFAULT_HYSTERIA_PORT}): " temp_hy2_port
    LAST_HY2_PORT=${temp_hy2_port:-$DEFAULT_HYSTERIA_PORT}
    read -p "请输入 Hysteria2 伪装域名/证书CN (默认: ${DEFAULT_HYSTERIA_MASQUERADE_CN}): " temp_hy2_masquerade_cn
    LAST_HY2_MASQUERADE_CN=${temp_hy2_masquerade_cn:-$DEFAULT_HYSTERIA_MASQUERADE_CN}

    read -p "请输入 Reality (VLESS) 监听端口 (默认: ${DEFAULT_REALITY_PORT}): " temp_reality_port
    LAST_REALITY_PORT=${temp_reality_port:-$DEFAULT_REALITY_PORT}
    read -p "请输入 Reality 目标SNI/握手服务器 (默认: ${DEFAULT_REALITY_SNI}): " temp_reality_sni
    LAST_REALITY_SNI=${temp_reality_sni:-$DEFAULT_REALITY_SNI}

    LAST_HY2_PASSWORD=$(generate_random_password)
    info "生成的 Hysteria2 密码: ${LAST_HY2_PASSWORD}"

    generate_self_signed_cert "$LAST_HY2_MASQUERADE_CN" || return 1
    generate_reality_credentials || return 1 # 设置 LAST_REALITY_UUID, TEMP_REALITY_PRIVATE_KEY, LAST_REALITY_PUBLIC_KEY

    create_config_json "all" \
        "$LAST_HY2_PORT" "$LAST_HY2_PASSWORD" "$LAST_HY2_MASQUERADE_CN" \
        "$LAST_REALITY_PORT" "$LAST_REALITY_UUID" "$TEMP_REALITY_PRIVATE_KEY" "$LAST_REALITY_SNI" \
        || return 1
    
    create_systemd_service
    start_singbox_service || return 1

    success "Hysteria2 + Reality 安装配置完成！"
    increment_install_count # 增加安装次数统计
    display_and_store_config_info "all" # 这也会调用 save_persistent_info
}

install_hysteria2_only() {
    info "开始单独安装 Hysteria2..."
    install_singbox_core || return 1
    get_server_ip

    read -p "请输入 Hysteria2 监听端口 (默认: ${DEFAULT_HYSTERIA_PORT}): " temp_hy2_port
    LAST_HY2_PORT=${temp_hy2_port:-$DEFAULT_HYSTERIA_PORT}
    read -p "请输入 Hysteria2 伪装域名/证书CN (默认: ${DEFAULT_HYSTERIA_MASQUERADE_CN}): " temp_hy2_masquerade_cn
    LAST_HY2_MASQUERADE_CN=${temp_hy2_masquerade_cn:-$DEFAULT_HYSTERIA_MASQUERADE_CN}

    LAST_HY2_PASSWORD=$(generate_random_password)
    info "生成的 Hysteria2 密码: ${LAST_HY2_PASSWORD}"

    generate_self_signed_cert "$LAST_HY2_MASQUERADE_CN" || return 1
    
    # 如果只安装 Hysteria2，则清除 Reality 相关信息
    LAST_REALITY_PORT=""
    LAST_REALITY_UUID=""
    LAST_REALITY_PUBLIC_KEY=""
    LAST_REALITY_SNI=""
    LAST_VLESS_LINK=""

    create_config_json "hysteria2" \
        "$LAST_HY2_PORT" "$LAST_HY2_PASSWORD" "$LAST_HY2_MASQUERADE_CN" \
        "" "" "" "" \
        || return 1

    create_systemd_service
    start_singbox_service || return 1

    success "Hysteria2 单独安装配置完成！"
    increment_install_count # 增加安装次数统计
    display_and_store_config_info "hysteria2"
}

install_reality_only() {
    info "开始单独安装 Reality (VLESS)..."
    install_singbox_core || return 1
    get_server_ip

    read -p "请输入 Reality (VLESS) 监听端口 (默认: ${DEFAULT_REALITY_PORT}): " temp_reality_port
    LAST_REALITY_PORT=${temp_reality_port:-$DEFAULT_REALITY_PORT}
    read -p "请输入 Reality 目标SNI/握手服务器 (默认: ${DEFAULT_REALITY_SNI}): " temp_reality_sni
    LAST_REALITY_SNI=${temp_reality_sni:-$DEFAULT_REALITY_SNI}

    generate_reality_credentials || return 1
    
    # 如果只安装 Reality，则清除 Hysteria2 相关信息
    LAST_HY2_PORT=""
    LAST_HY2_PASSWORD=""
    LAST_HY2_MASQUERADE_CN=""
    LAST_HY2_LINK=""

    create_config_json "reality" \
        "" "" "" \
        "$LAST_REALITY_PORT" "$LAST_REALITY_UUID" "$TEMP_REALITY_PRIVATE_KEY" "$LAST_REALITY_SNI" \
        || return 1
        
    create_systemd_service
    start_singbox_service || return 1

    success "Reality (VLESS) 单独安装配置完成！"
    increment_install_count # 增加安装次数统计
    display_and_store_config_info "reality"
}

show_current_import_info() {
    # load_persistent_info 在脚本开始时调用，所以如果文件存在，变量应该已填充
    if [ -z "$LAST_INSTALL_MODE" ]; then
        warn "尚未通过此脚本安装任何配置，或上次安装信息未保留。"
        info "请先执行安装操作 (选项 1, 2, 或 3)，或者确保 ${PERSISTENT_INFO_FILE} 文件存在且包含信息。"
        return
    fi
    info "显示上次保存的配置信息 (${LAST_INSTALL_MODE}模式):"
    # 重新调用 display_and_store_config_info 以重新生成链接 (时间戳) 和二维码
    display_and_store_config_info "$LAST_INSTALL_MODE"
}

uninstall_singbox() {
    warn "你确定要卸载 Sing-box 吗?"
    read -p "此操作将停止并禁用服务，删除可执行文件和相关配置文件目录。是否继续卸载? (y/N): " confirm_uninstall
    if [[ ! "$confirm_uninstall" =~ ^[Yy]$ ]]; then
        info "卸载已取消。"
        return
    fi

    info "正在停止 sing-box 服务..."
    systemctl stop sing-box &>/dev/null
    info "正在禁用 sing-box 服务..."
    systemctl disable sing-box &>/dev/null

    if [ -f "$SINGBOX_SERVICE_FILE" ]; then
        info "正在删除 systemd 服务文件: ${SINGBOX_SERVICE_FILE}"
        rm -f "$SINGBOX_SERVICE_FILE"
        systemctl daemon-reload
    fi

    local singbox_exe_to_remove=""
    # 首先检查 SINGBOX_CMD，因为它可能来自 `command -v`
    if [ -n "$SINGBOX_CMD" ] && [ -f "$SINGBOX_CMD" ]; then
        singbox_exe_to_remove="$SINGBOX_CMD"
    elif [ -f "$SINGBOX_INSTALL_PATH_EXPECTED" ]; then # 检查脚本预期的路径
        singbox_exe_to_remove="$SINGBOX_INSTALL_PATH_EXPECTED"
    fi
    
    # 也检查官方脚本是否将其安装到 /usr/local/bin/sing-box
    local official_install_path="/usr/local/bin/sing-box"
    if [ -f "$official_install_path" ]; then
        if [ -n "$singbox_exe_to_remove" ] && [ "$singbox_exe_to_remove" != "$official_install_path" ]; then
            # 如果通过其他方式找到了，并且与官方路径不同，也删除官方路径的
            info "正在删除 sing-box 执行文件: $official_install_path (官方脚本位置)"
            rm -f "$official_install_path"
        elif [ -z "$singbox_exe_to_remove" ]; then # 如果之前未找到
             singbox_exe_to_remove="$official_install_path"
        fi
    fi


    if [ -n "$singbox_exe_to_remove" ] && [ -f "$singbox_exe_to_remove" ]; then
        info "正在删除 sing-box 执行文件: $singbox_exe_to_remove"
        rm -f "$singbox_exe_to_remove"
    else
        warn "未找到明确的 sing-box 执行文件进行删除 (已检查 ${SINGBOX_INSTALL_PATH_EXPECTED} 和 ${official_install_path})。"
    fi
    
    # 询问是否删除配置目录，其中包含持久化信息文件
    read -p "是否删除配置文件目录 ${SINGBOX_CONFIG_DIR} (包含导入信息缓存)? (y/N): " delete_config_dir_confirm
    if [[ "$delete_config_dir_confirm" =~ ^[Yy]$ ]]; then
        if [ -d "$SINGBOX_CONFIG_DIR" ]; then
            info "正在删除配置目录 (包括 ${PERSISTENT_INFO_FILE})..."
            rm -rf "$SINGBOX_CONFIG_DIR"
        fi
    else
        info "配置文件目录 (${SINGBOX_CONFIG_DIR}) 已保留。"
    fi
    
    # 询问是否删除 Hysteria2 证书目录
    read -p "是否删除 Hysteria2 证书目录 ${HYSTERIA_CERT_DIR}? (y/N): " delete_cert_dir_confirm
     if [[ "$delete_cert_dir_confirm" =~ ^[Yy]$ ]]; then
        if [ -d "$HYSTERIA_CERT_DIR" ]; then
            info "正在删除 Hysteria2 证书目录..."
            rm -rf "$HYSTERIA_CERT_DIR"
        fi
    else
        info "Hysteria2 证书目录 (${HYSTERIA_CERT_DIR}) 已保留。"
    fi


    success "Sing-box 卸载完成。"
    # 清除内存中的变量
    LAST_INSTALL_MODE="" 
    SINGBOX_CMD=""
}

# --- 管理函数 ---
manage_singbox() {
    local action=$1
    if [ -z "$SINGBOX_CMD" ]; then
        warn "Sing-box command 未设置, 尝试查找..."
        find_and_set_singbox_cmd
        if [ -z "$SINGBOX_CMD" ]; then
            error "仍然无法找到 Sing-box command. 操作中止。"
            return 1
        fi
    fi

    case "$action" in
        start)
            systemctl start sing-box
            if systemctl is-active --quiet sing-box; then success "Sing-box 服务已启动。"; else error "Sing-box 服务启动失败。"; fi
            ;;
        stop)
            systemctl stop sing-box
            if ! systemctl is-active --quiet sing-box; then success "Sing-box 服务已停止。"; else error "Sing-box 服务停止失败。"; fi
            ;;
        restart)
            if [ -f "$SINGBOX_CONFIG_FILE" ]; then
                info "重启前检查配置文件..."
                if ! $SINGBOX_CMD check -c "$SINGBOX_CONFIG_FILE"; then
                    error "配置文件检查失败，无法重启。请先修复配置文件。"
                    return 1
                fi
                success "配置文件检查通过。"
            fi
            systemctl restart sing-box
            sleep 1
            if systemctl is-active --quiet sing-box; then success "Sing-box 服务已重启。"; else error "Sing-box 服务重启失败。"; fi
            ;;
        status)
            systemctl status sing-box --no-pager -l
            ;;
        log)
            journalctl -u sing-box -f --no-pager -n 50
            ;;
        view_config)
            if [ -f "$SINGBOX_CONFIG_FILE" ]; then
                info "当前配置文件 (${SINGBOX_CONFIG_FILE}):"
                cat "$SINGBOX_CONFIG_FILE"
            else
                error "配置文件不存在: ${SINGBOX_CONFIG_FILE}"
            fi
            ;;
        edit_config)
            if [ -f "$SINGBOX_CONFIG_FILE" ]; then
                if command -v nano &> /dev/null; then
                    nano "$SINGBOX_CONFIG_FILE"
                elif command -v vim &> /dev/null; then
                    vim "$SINGBOX_CONFIG_FILE"
                else
                    error "'nano' 或 'vim' 编辑器未安装。请手动编辑: ${SINGBOX_CONFIG_FILE}"
                    return
                fi
                read -p "配置文件已编辑，是否立即重启 sing-box 服务? (y/N): " restart_confirm
                if [[ "$restart_confirm" =~ ^[Yy]$ ]]; then
                    manage_singbox "restart"
                fi
            else
                error "配置文件不存在: ${SINGBOX_CONFIG_FILE}"
            fi
            ;;
        *)
            error "无效的管理操作: $action"
            ;;
    esac
}


# --- 主菜单 ---
show_menu() {
    clear 
    print_author_info

    echo -e "${GREEN}${BOLD}安装选项:${NC}"
    echo "  1. 安装 Hysteria2 + Reality (共存)"
    echo "  2. 单独安装 Hysteria2"
    echo "  3. 单独安装 Reality (VLESS)"
    echo "------------------------------------------------"
    echo -e "${YELLOW}${BOLD}管理选项:${NC}"
    echo "  4. 启动 Sing-box 服务"
    echo "  5. 停止 Sing-box 服务"
    echo "  6. 重启 Sing-box 服务"
    echo "  7. 查看 Sing-box 服务状态"
    echo "  8. 查看 Sing-box 实时日志"
    echo "  9. 查看当前配置文件"
    echo "  10. 编辑当前配置文件 (nano/vim)"
    echo "  11. 显示上次保存的导入信息 (含二维码)" # 措辞已更改
    echo "------------------------------------------------"
    echo -e "${RED}${BOLD}其他选项:${NC}"
    echo "  12. 更新 Sing-box 内核 (使用官方beta脚本)"
    echo "  13. 卸载 Sing-box"
    echo "  0. 退出脚本"
    echo "================================================"
    read -p "请输入选项 [0-13]: " choice

    case "$choice" in
        1) install_hysteria2_reality ;;
        2) install_hysteria2_only ;;
        3) install_reality_only ;;
        4) manage_singbox "start" ;;
        5) manage_singbox "stop" ;;
        6) manage_singbox "restart" ;;
        7) manage_singbox "status" ;;
        8) manage_singbox "log" ;;
        9) manage_singbox "view_config" ;;
        10) manage_singbox "edit_config" ;;
        11) show_current_import_info ;;
        12) install_singbox_core && manage_singbox "restart" ;; # 更新后重启服务
        13) uninstall_singbox ;;
        0) exit 0 ;;
        *) error "无效选项，请输入 0 到 13 之间的数字。" ;;
    esac
    echo "" # 在每次操作后留空一行，以便阅读
}

# --- 脚本入口点 ---
check_root
check_dependencies
find_and_set_singbox_cmd # 在脚本开始时尝试查找 sing-box
load_persistent_info     # 在脚本开始时加载持久化信息
load_install_count       # 加载安装次数统计

# 主循环
while true; do
    show_menu
    read -n 1 -s -r -p "按任意键返回主菜单 (或按 Ctrl+C 退出)..."
done
