#!/bin/bash
# Selkies Web Interface Diagnostic Script
# Selkies 网页界面诊断脚本

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "  Selkies Web Interface Diagnostic Tool"
echo "  Selkies 网页界面诊断工具"
echo "========================================"
echo ""

# 1. 检查容器是否运行
echo "[1/8] Checking container status..."
if ! docker ps | grep -q puppy-stardew; then
    echo -e "${RED}ERROR: Container not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Container is running${NC}"
echo ""

# 2. 检查 Web 远程访问环境变量
echo "[2/8] Checking web remote access environment variable..."
VNC_ENABLED=$(docker exec puppy-stardew env | grep ENABLE_VNC)
echo "ENABLE_VNC setting: $VNC_ENABLED"
if echo "$VNC_ENABLED" | grep -q "true"; then
    echo -e "${GREEN}✓ Web remote access is enabled${NC}"
else
    echo -e "${YELLOW}WARNING: Web remote access may not be enabled${NC}"
fi
echo ""

# 3. 检查Xorg/Xvfb进程
echo "[3/8] Checking Xorg/Xvfb (virtual display)..."
docker exec puppy-stardew ps aux | grep -E "Xorg|Xvfb" | grep -v grep
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ X server is running${NC}"
else
    echo -e "${RED}✗ X server is NOT running${NC}"
fi
echo ""

# 4. 检查 Selkies 进程
echo "[4/8] Checking Selkies process..."
docker exec puppy-stardew ps aux | grep -i selkies | grep -v grep
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Selkies is running${NC}"
else
    echo -e "${RED}✗ Selkies is NOT running${NC}"
    echo ""
    echo "Possible reasons:"
    echo "  1. Web remote access not enabled (set ENABLE_VNC=true in .env)"
    echo "  2. Selkies failed to start"
    echo "  3. X server not ready when Selkies started"
fi
echo ""

# 5. 检查端口监听
echo "[5/8] Checking if port 8080 is listening in container..."
docker exec puppy-stardew netstat -tuln 2>/dev/null | grep 8080
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Port 8080 is listening${NC}"
else
    echo -e "${RED}✗ Port 8080 is NOT listening${NC}"
fi
echo ""

# 6. 检查主机端口映射
echo "[6/8] Checking host port mapping..."
docker port puppy-stardew 8080 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Port 8080 is mapped${NC}"
else
    echo -e "${RED}✗ Port 8080 is NOT mapped${NC}"
    echo "Ensure docker-compose.yml has: -p 8080:8080/tcp"
fi
echo ""

# 7. 检查防火墙
echo "[7/8] Checking host firewall..."
if command -v ufw >/dev/null 2>&1; then
    ufw status | grep 8080
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Firewall rule exists${NC}"
    else
        echo -e "${YELLOW}WARNING: No firewall rule for port 8080${NC}"
        echo "Add with: sudo ufw allow 8080/tcp"
    fi
else
    echo "ufw not found, skipping firewall check"
fi
echo ""

# 8. 查看容器日志中的 Selkies 相关信息
echo "[8/8] Checking container logs for Selkies..."
docker logs puppy-stardew 2>&1 | grep -i selkies | tail -5
echo ""

echo "========================================"
echo "  Diagnostic Summary"
echo "========================================"
echo ""
echo "To test web interface connection from host:"
echo "  curl -I http://localhost:8080"
echo ""
echo "To access web interface in browser:"
echo "  http://your-server-ip:8080"
echo ""
echo "To view full container logs:"
echo "  docker logs puppy-stardew"
