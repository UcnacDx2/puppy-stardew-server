#!/bin/bash
# Puppy Stardew Server Entrypoint Script - v1.0.61
# 小狗星谷服务器启动脚本 - v1.0.61

# DO NOT use set -e - we need manual error handling
# 不使用 set -e - 需要手动错误处理

# Color codes for pretty logging
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Resolution environment variables with defaults
# 分辨率相关环境变量，带默认值；刷新率默认24
RESOLUTION_WIDTH=${RESOLUTION_WIDTH:-1280}
RESOLUTION_HEIGHT=${RESOLUTION_HEIGHT:-720}
REFRESH_RATE=${REFRESH_RATE:-24}

# Logging functions
log_info() {
    echo -e "${GREEN}[Puppy-Stardew]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[Puppy-Stardew]${NC} $1"
}

log_error() {
    echo -e "${RED}[Puppy-Stardew]${NC} $1"
}

log_step() {
    echo -e "${BLUE}${1}${NC}"
}

log_steam() {
    echo -e "${CYAN}$1${NC}"
}

# Function to download game via steamcmd
# 下载游戏函数
download_game_via_steam() {
    log_info "========================================="
    log_info "  Starting Steam download process"
    log_info "  开始 Steam 下载流程"
    log_info "========================================="
    log_info ""
    log_info "If Steam Guard is required, you will see a prompt."
    log_info "如果需要 Steam Guard，您会看到提示。"
    log_info ""
    log_info "To input Steam Guard code:"
    log_info "输入 Steam Guard 验证码："
    log_info "  1. You should already have run: docker attach puppy-stardew"
    log_info "  1. 您应该已经运行了：docker attach puppy-stardew"
    log_info "  2. Enter the code when prompted below"
    log_info "  2. 在下面提示时输入验证码"
    log_info "  3. Press ENTER"
    log_info "  3. 按回车"
    log_info ""
    log_info "After successful authentication, game will download (~708MB)"
    log_info "验证成功后，游戏将开始下载（约708MB）"
    log_info "========================================="
    log_info ""

    # Run steamcmd WITHOUT pipe - this preserves stdin!
    # 运行 steamcmd 不使用管道 - 保留stdin！
    /home/steam/steamcmd/steamcmd.sh \
        +force_install_dir /home/steam/stardewvalley \
        +login "$STEAM_USERNAME" "$STEAM_PASSWORD" \
        +app_update 413150 validate \
        +quit

    DOWNLOAD_EXIT_CODE=$?

    # Check result
    if [ -f "/home/steam/stardewvalley/StardewValley" ]; then
        log_info "✅ Game downloaded successfully!"
        log_info "✅ 游戏下载完成！"
        return 0
    else
        log_error "❌ Game download failed (exit code: $DOWNLOAD_EXIT_CODE)"
        log_error "❌ 游戏下载失败（退出码：$DOWNLOAD_EXIT_CODE）"
        log_error ""
        log_error "Common causes / 常见原因："
        log_error "  1. Steam Guard code incorrect / Steam Guard 验证码错误"
        log_error "  2. Network timeout / 网络超时"
        log_error "  3. Insufficient disk space / 磁盘空间不足"
        log_error "  4. Steam API rate limit / Steam API 速率限制"
        return 1
    fi
}

# =============================================
# GPU-related helper function
# 将使用 GPU 的逻辑封装为函数，供 root 阶段和 steam 阶段调用
# =============================================
start_gpu_xorg() {
    # 参数（可选）：$1 = context 描述（如 "root" 或 "steam"），仅用于日志
    local context=${1:-"unknown"}
    if [ "$USE_GPU" != "true" ]; then
        log_warn "USE_GPU != true，跳过 GPU 启动逻辑（context: $context）"
        return 3
    fi

    log_info "USE_GPU=true -> 在 ${context} 阶段尝试启动 Xorg :99 以使用核显（如果容器可访问 /dev/dri）"
    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null || true
    if [ -e /dev/dri/renderD128 ] || ls /dev/dri 2>/dev/null | grep -q .; then
        log_info "检测到 /dev/dri，准备启动 Xorg :99 (context: $context)"

        # 确保 X socket 目录存在且权限允许创建
        mkdir -p /tmp/.X11-unix
        chmod 1777 /tmp/.X11-unix

        # 确保 Xorg 日志目录存在（写入为 root）
        mkdir -p /home/steam/.local/share/xorg
        # 在 root 上设置目录拥有者为 root:root（在 steam 上不需要）
        if [ "$(id -u)" = "0" ]; then
            chown root:root /home/steam/.local/share/xorg 2>/dev/null || true
        fi

        # 以当前用户后台启动 Xorg，日志写入到 /home/steam/.local/share/xorg/Xorg.0.log
        Xorg -noreset +extension GLX +extension RANDR :99 -logfile /home/steam/.local/share/xorg/Xorg.0.log &
        sleep 2

        # 尝试设置 Xorg 分辨率为来自环境变量的值（刷新率使用 REFRESH_RATE）
        DISPLAY=:99 /home/steam/scripts/set-resolution.sh "${RESOLUTION_WIDTH}" "${RESOLUTION_HEIGHT}" "${REFRESH_RATE}" || {
            log_warn "设置分辨率失败（context: $context），将继续（可能使用当前 X server 大小）"
        }

        # 稍微等一会以确保分辨率生效
        sleep 1

        if pgrep -x Xorg >/dev/null 2>&1; then
            export DISPLAY=${DISPLAY:-:99}
            log_info "✓ Xorg started on :99 (context: $context)"
            if command -v glxinfo >/dev/null 2>&1; then
                log_info "OpenGL renderer:"
                glxinfo | grep -i "OpenGL renderer" | head -n 1 || true
            fi
            return 0
        else
            log_warn "Xorg 未能以 ${context} 启动，返回非零以便上层回退"
            return 2
        fi
    else
        log_warn "/dev/dri 未检测到或不可访问，跳过 Xorg 启动（context: $context）"
        return 1
    fi
}

# =============================================
# Phase 1: Root Initialization (Permission Fixes)
# 阶段1：Root 初始化（权限修复）
# =============================================

if [ "$(id -u)" = "0" ]; then
    log_step "================================================"
    log_step "  Phase 1: Root Initialization"
    log_step "  阶段1：Root 初始化"
    log_step "================================================"

    # Fix libcurl compatibility for SteamCMD
    log_info "Setting up libcurl compatibility..."
    if [ ! -f "/usr/lib/x86_64-linux-gnu/libcurl.so.4" ]; then
        rm -f /usr/lib/x86_64-linux-gnu/libcurl.so.4 2>/dev/null || true
        ln -sf /usr/lib/i386-linux-gnu/libcurl.so.4 /usr/lib/x86_64-linux-gnu/libcurl.so.4
        log_info "✅ libcurl symlink created"
    else
        log_info "✅ libcurl already configured"
    fi

    # Fix data directory permissions
    log_info "Checking and fixing file permissions..."
    DIRS_TO_CHECK=(
        "/home/steam/.config/StardewValley"
        "/home/steam/stardewvalley"
        "/home/steam/Steam"
        "/home/steam/.local/share/puppy-stardew/logs"
    )

    FIXED_COUNT=0
    for dir in "${DIRS_TO_CHECK[@]}"; do
        if [ -d "$dir" ]; then
            # Check if any files are not owned by steam user (UID 1000)
            WRONG_OWNER=$(find "$dir" ! -user steam 2>/dev/null | wc -l)
            if [ "$WRONG_OWNER" -gt 0 ]; then
                log_warn "Found $WRONG_OWNER file(s) with incorrect ownership in $dir"
                log_info "Fixing permissions..."
                chown -R steam:steam "$dir" 2>/dev/null || true
                FIXED_COUNT=$((FIXED_COUNT + WRONG_OWNER))
            fi
        fi
    done

    if [ "$FIXED_COUNT" -gt 0 ]; then
        log_info "✅ Fixed permissions for $FIXED_COUNT file(s)"
    else
        log_info "✅ All permissions correct"
    fi

    # 如果启用了 GPU 加速并且宿主 /dev/dri 已透传，尝试在 root 阶段启动 Xorg（以便 Xorg 可以访问 /dev/tty0 和创建 /tmp/.X11-unix）
    if [ "$USE_GPU" = "true" ]; then
        # 使用封装后的函数尝试启动 Xorg（root 上下文）
        start_gpu_xorg "root" || {
            log_warn "root 阶段 GPU 启动尝试未成功，将在 steam 阶段尝试回退逻辑"
        }
    fi

    log_info "Switching to steam user..."
    log_info "================================================"

    # Re-execute this script as steam user
    exec runuser -u steam -- env DISPLAY="$DISPLAY" "$0" "$@"
fi

# =============================================
# Phase 2: Steam User Operations
# 阶段2：Steam 用户操作
# =============================================

log_step "================================================"
log_step "  Puppy Stardew Server v1.0.61 Starting..."
log_step "  小狗星谷服务器 v1.0.61 启动中..."
log_step "================================================"

# Verify we're running as steam user
if [ "$(id -u)" != "1000" ]; then
    log_error "ERROR: Script must run as steam user (UID 1000)"
    log_error "错误：脚本必须以 steam 用户（UID 1000）运行"
    exit 1
fi

# Step 1: Validate Steam credentials
log_step "Step 1: Validating configuration..."

if [ -z "$STEAM_USERNAME" ] || [ -z "$STEAM_PASSWORD" ]; then
    log_error "STEAM_USERNAME or STEAM_PASSWORD not set!"
    log_error "STEAM_USERNAME 或 STEAM_PASSWORD 未设置！"
    log_error "Please configure .env file."
    log_error "请配置 .env 文件。"
    exit 1
fi

log_info "Steam username: $STEAM_USERNAME"

# Step 2: Download game if needed
if [ ! -f "/home/steam/stardewvalley/StardewValley" ]; then
    log_step "Step 2: Downloading Stardew Valley..."
    log_warn "Game files not found. Downloading from Steam..."
    log_warn "未找到游戏文件。正在从 Steam 下载..."
    log_warn "This will take 5-10 minutes depending on your connection."
    log_warn "根据网络情况，此过程需要 5-10 分钟。"
    log_warn ""

    # Clean up any existing Steam cache
    log_info "Cleaning Steam cache..."
    rm -rf /home/steam/Steam/config/* 2>/dev/null || true
    rm -rf /home/steam/Steam/logs/* 2>/dev/null || true
    rm -rf /tmp/steam* 2>/dev/null || true

    # Download game (handles Steam Guard automatically)
    if ! download_game_via_steam; then
        log_error "Failed to download game. Container will exit."
        log_error "游戏下载失败。容器将退出。"
        exit 1
    fi
else
    log_step "Step 2: Game files found, skipping download"
    log_info "✓ Stardew Valley already downloaded"
    log_info "✓ 星露谷物语已下载"
fi

# Step 3: Install SMAPI
log_step "Step 3: Installing SMAPI mod loader..."

if [ ! -f "/home/steam/stardewvalley/StardewModdingAPI" ]; then
    log_info "Installing SMAPI..."
    cd /home/steam
    echo "1" | dotnet smapi/SMAPI*/internal/linux/SMAPI.Installer.dll --install --game-path /home/steam/stardewvalley

    if [ $? -ne 0 ]; then
        log_error "Failed to install SMAPI!"
        log_error "SMAPI 安装失败！"
        exit 1
    fi

    log_info "✓ SMAPI installed successfully!"
else
    log_info "✓ SMAPI already installed"
fi

# Step 4: Install mods
log_step "Step 5: Installing mods..."

mkdir -p /home/steam/stardewvalley/Mods

if [ -d "/home/steam/preinstalled-mods" ]; then
    if [ -d "/home/steam/stardewvalley/Mods/AutoHideHost" ]; then
        log_info "✓ Mods already installed"
    else
        log_info "Installing mods..."
        cp -r /home/steam/preinstalled-mods/* /home/steam/stardewvalley/Mods/
        log_info "✓ Mods installed successfully!"
    fi

    log_info "Installed mods:"
    ls -1 /home/steam/stardewvalley/Mods/ | while read mod; do
        log_info "  ✓ $mod"
    done
fi

# Step 5: Setup virtual display
log_step "Step 6: Starting virtual display..."

# 首选：如果有已经运行的 Xorg（root 或宿主），使用它；否则在 steam 阶段按需回退到 Xvfb
START_XVFB_FALLBACK=false

# 如果 root 阶段已经成功启动了 Xorg，则此处会发现 Xorg 进程并使用 :99
if pgrep -x Xorg >/dev/null 2>&1; then
    export DISPLAY=${DISPLAY:-:99}
    log_info "检测到 Xorg 进程，使用 DISPLAY=${DISPLAY}"
    if command -v glxinfo >/dev/null 2>&1; then
        log_info "OpenGL renderer:"
        glxinfo | grep -i "OpenGL renderer" | head -n 1 || true
    fi
else
    # 否则在 steam 阶段尝试使用 /dev/dri（若可用）再启动 Xorg（少数环境可能需要这样启动）
    if [ "$USE_GPU" = "true" ]; then
        log_warn "steam 阶段 Xorg 启动失败或不可用，回退到 Xvfb（软件渲染）"
        START_XVFB_FALLBACK=true
    else
        START_XVFB_FALLBACK=true
    fi
fi

# 回退：启动 Xvfb（软件渲染）以保证兼容性
if [ "$START_XVFB_FALLBACK" = "true" ]; then
    log_info "启动 Xvfb（软件渲染后备）..."
    rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null || true
    Xvfb :99 -screen 0 "${RESOLUTION_WIDTH}x${RESOLUTION_HEIGHT}x24" -ac +extension GLX +render -noreset &
    export DISPLAY=${DISPLAY:-:99}
    sleep 3
    log_info "✓ Virtual display started on ${DISPLAY} (${RESOLUTION_WIDTH}x${RESOLUTION_HEIGHT})"
fi

# Step 6: Start VNC server (optional)
if [ "$ENABLE_VNC" = "true" ]; then
    log_step "Step 7: Starting VNC server..."
    echo "DISPLAY is set to: $DISPLAY"
    VNC_PASSWORD=${VNC_PASSWORD:-"stardew1"}

    if [ ${#VNC_PASSWORD} -gt 8 ]; then
        log_warn "VNC password > 8 chars, truncating to: ${VNC_PASSWORD:0:8}"
        VNC_PASSWORD="${VNC_PASSWORD:0:8}"
    fi
restart
    # Wait a bit for X server (Xorg 或 Xvfb) to be fully ready
    sleep 2

    # Start x11vnc 指向当前 DISPLAY（:0 或 :99）
    log_info "Starting x11vnc on display ${DISPLAY} (port 5900)..."
    x11vnc -display "${DISPLAY}" -forever -shared -passwd "$VNC_PASSWORD" -rfbport 5900 -noxdamage -bg 2>&1 | grep -v "^$"

    # Wait for x11vnc to start
    sleep 2

    # Verify VNC is running
    if pgrep -x "x11vnc" >/dev/null; then
        log_info "✓ VNC server started successfully on port 5900"
        log_info "  Password: $VNC_PASSWORD"
        log_info "  Connect to: your-server-ip:5900"
        # Start VNC monitor to keep it alive
        if [ -f "/home/steam/scripts/vnc-monitor.sh" ]; then
            log_info "Starting VNC health monitor..."
            /home/steam/scripts/vnc-monitor.sh &
            log_info "✓ VNC monitor started (30s check interval)"
        fi
    else
        log_error "✗ VNC server failed to start"
        log_error "Check logs above for errors"
    fi
else
    log_step "Step 7: VNC disabled (set ENABLE_VNC=true to enable)"
fi

# Step 7: Setup optimized game config for VNC display
# 步骤 7.5：为VNC显示设置优化的游戏配置
log_step "Step 7.5: Configuring game display settings..."

CONFIG_DIR="/home/steam/.config/StardewValley"
CONFIG_FILE="$CONFIG_DIR/startup_preferences"
TEMPLATE="/home/steam/startup_preferences.template"

# Create config directory if not exists
mkdir -p "$CONFIG_DIR"

# Copy optimized config template if startup_preferences doesn't exist yet
# 如果startup_preferences还不存在，复制优化的配置模板
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "$TEMPLATE" ]; then
        cp "$TEMPLATE" "$CONFIG_FILE"
        log_info "✓ Applied optimized display config (fullscreen mode for VNC)"
        log_info "✓ 已应用优化的显示配置（VNC全屏模式）"
    else
        log_warn "⚠ Template not found, game will use default settings"
    fi
else
    log_info "✓ Game config already exists, keeping user settings"
fi

# Step 8: Start log monitoring (optional)
if [ "$ENABLE_LOG_MONITOR" = "true" ]; then
    log_step "Step 8: Starting log monitoring..."

    if [ -f "/home/steam/scripts/log-monitor.sh" ]; then
        /home/steam/scripts/log-monitor.sh &
        log_info "✓ Log monitoring started"
    fi
else
    log_step "Step 8: Log monitoring disabled"
fi

# Step 9: Start game server
log_step "Step 9: Starting game server..."
log_info "================================================"
log_info "  Server is starting!"
log_info "  服务器启动中！"
log_info "================================================"
log_info ""
log_info "To create/load a save:"
log_info "要创建/加载存档："
log_info "  1. Connect via VNC: localhost:5900 (password: $VNC_PASSWORD)"
log_info "  1. 通过 VNC 连接：localhost:5900（密码：$VNC_PASSWORD）"
log_info "  2. Click CO-OP → Start new co-op farm"
log_info "  2. 点击 CO-OP → 开始新的联机农场"
log_info ""
log_info "Players connect via:"
log_info "玩家连接方式："
log_info "  1. Open Stardew Valley → CO-OP → Join LAN Game"
log_info "  1. 打开星露谷物语 → CO-OP → 加入局域网游戏"
log_info "  2. Server will appear automatically, or enter server IP directly"
log_info "  2. 服务器会自动出现，或直接输入服务器IP"
log_info "  3. No port number needed (default: 24642/UDP)"
log_info "  3. 无需输入端口号（默认：24642/UDP）"
log_info "================================================"
log_info ""

cd /home/steam/stardewvalley

# Start auto-enable script in background
log_info "Starting auto-enable Always On Server script..."
/home/steam/scripts/auto-enable-server.sh &

# Start auto-handle ReadyCheckDialog script in background
log_info "Starting auto-handle ReadyCheckDialog script..."
/home/steam/scripts/auto-handle-readycheck.sh &

# Run game server (this runs in foreground)
exec ./StardewModdingAPI --server