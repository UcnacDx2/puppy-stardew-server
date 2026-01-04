# （此片段替换你脚本中“设置分辨率 / set-resolution”相关位置）
# 尝试以多种方式设置目标分辨率，兼容不同的 mode 名称和缺失的 mode 情况
TARGET_W=1280
TARGET_H=720
TARGET_R=60
TARGET_MODE="${TARGET_W}x${TARGET_H}_${TARGET_R}.00"
SIMPLE_MODE="${TARGET_W}x${TARGET_H}"

# 找到第一个 connected output（如果你希望指定某个输出，也可以改这里）
OUTPUT=$(xrandr | awk '/ connected/ { print $1; exit }' 2>/dev/null || true)

if [ -n "$OUTPUT" ]; then
    echo "检测到输出: $OUTPUT，尝试设置分辨率为 ${SIMPLE_MODE} 或 ${TARGET_MODE}"

    # 优先直接尝试简单模式名（如 1280x720）
    if xrandr --output "$OUTPUT" --mode "$SIMPLE_MODE" >/dev/null 2>&1; then
        echo "✓ 已将 $OUTPUT 设置为 ${SIMPLE_MODE}"
    else
        # 再尝试带后缀的模式名（原脚本那种）
        if xrandr --output "$OUTPUT" --mode "$TARGET_MODE" >/dev/null 2>&1; then
            echo "✓ 已将 $OUTPUT 设置为 ${TARGET_MODE}"
        else
            # 若都失败，尝试使用 cvt 新建 mode（如果 cvt 存在）
            if command -v cvt >/dev/null 2>&1 && command -v xrandr >/dev/null 2>&1; then
                echo "尝试用 cvt 生成 modeline 并添加（需要可用的 cvt/xrandr）"
                MODELINE=$(cvt ${TARGET_W} ${TARGET_H} ${TARGET_R} 2>/dev/null | sed -n '2p' | sed 's/Modeline //')
                if [ -n "$MODELINE" ]; then
                    MODE_NAME=$(echo "$MODELINE" | awk '{print $1}' | tr -d \")
                    # 创建新模式并添加到输出
                    xrandr --newmode $MODELINE >/dev/null 2>&1 || true
                    xrandr --addmode "$OUTPUT" "$MODE_NAME" >/dev/null 2>&1 || true
                    # 最后尝试应用
                    if xrandr --output "$OUTPUT" --mode "$MODE_NAME" >/dev/null 2>&1; then
                        echo "✓ 已通过 cvt 新建并应用模式 $MODE_NAME 到 $OUTPUT"
                    else
                        echo "无法应用新建模式 $MODE_NAME，保持当前分辨率"
                    fi
                else
                    echo "cvt 未能生成 modeline（或 cvt 输出格式不可解析）"
                fi
            else
                echo "cvt 或 xrandr 不可用，无法创建自定义模式，保持当前分辨率"
            fi
        fi
    fi
else
    echo "未检测到已连接输出，跳过分辨率设置"
fi