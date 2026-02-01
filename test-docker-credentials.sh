#!/bin/bash
# Docker Credentials Validation Script
# 测试 Docker Hub 凭证验证脚本
#
# This script helps you verify your Docker Hub credentials before configuring
# them as GitHub secrets.
# 此脚本帮助您在将凭证配置为 GitHub secrets 之前验证 Docker Hub 凭证。
#
# Usage: ./test-docker-credentials.sh
# 用法：./test-docker-credentials.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "================================================"
echo "Docker Hub Credentials Validation Script"
echo "Docker Hub 凭证验证脚本"
echo "================================================"
echo ""

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    print_error "Docker 未安装或不在 PATH 中"
    exit 1
fi

print_success "Docker is installed"
print_success "Docker 已安装"
echo ""

# Read credentials
print_info "Please enter your Docker Hub credentials:"
print_info "请输入您的 Docker Hub 凭证："
echo ""

read -p "Docker Hub Username (用户名): " DOCKER_USERNAME
echo ""

# Read password/token silently
echo "Docker Hub Personal Access Token (个人访问令牌):"
echo "  (starts with dckr_pat_... NOT your password!)"
echo "  (以 dckr_pat_ 开头... 不是您的密码！)"
read -s -p "Token: " DOCKER_TOKEN
echo ""
echo ""

# Validate inputs
if [ -z "$DOCKER_USERNAME" ]; then
    print_error "Username cannot be empty"
    print_error "用户名不能为空"
    exit 1
fi

if [ -z "$DOCKER_TOKEN" ]; then
    print_error "Token cannot be empty"
    print_error "令牌不能为空"
    exit 1
fi

# Check if token looks like a Personal Access Token
if [[ ! "$DOCKER_TOKEN" =~ ^dckr_pat_ ]]; then
    print_warning "WARNING: Your token doesn't start with 'dckr_pat_'"
    print_warning "警告：您的令牌不是以 'dckr_pat_' 开头"
    print_warning "Docker Hub requires Personal Access Tokens (PATs) for authentication."
    print_warning "Docker Hub 需要个人访问令牌 (PAT) 进行身份验证。"
    print_warning "If you're using your password, this will likely fail."
    print_warning "如果您使用的是密码，这可能会失败。"
    echo ""
    read -p "Continue anyway? (y/n): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        print_info "Aborted. Please create a Personal Access Token at:"
        print_info "已中止。请在以下网址创建个人访问令牌："
        print_info "https://hub.docker.com/settings/security"
        exit 0
    fi
fi

echo ""
print_info "Testing Docker Hub login..."
print_info "测试 Docker Hub 登录..."
echo ""

# Test login
if echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USERNAME" --password-stdin 2>&1; then
    echo ""
    print_success "✅ Login successful!"
    print_success "✅ 登录成功！"
    echo ""
    print_info "Your credentials are correct. You can now configure them as GitHub secrets:"
    print_info "您的凭证正确。现在您可以将它们配置为 GitHub secrets："
    echo ""
    echo "  1. Go to your GitHub repository → Settings → Secrets and variables → Actions"
    echo "  2. Add/Update these secrets:"
    echo "     - DOCKER_USERNAME: $DOCKER_USERNAME"
    echo "     - DOCKER_PASSWORD: <your Personal Access Token>"
    echo ""
    print_info "For detailed instructions, see:"
    print_info "详细说明请参见："
    echo "  .github/workflows/SETUP_DOCKER_SECRETS.md"
    echo ""
    
    # Logout
    docker logout > /dev/null 2>&1 || true
    print_info "Logged out from Docker Hub"
    print_info "已从 Docker Hub 登出"
else
    echo ""
    print_error "❌ Login failed!"
    print_error "❌ 登录失败！"
    echo ""
    print_error "Possible reasons / 可能的原因："
    echo ""
    echo "  1. Username is incorrect / 用户名不正确"
    echo "     • Must match your Docker Hub username exactly (case-sensitive)"
    echo "     • 必须与您的 Docker Hub 用户名完全匹配（区分大小写）"
    echo ""
    echo "  2. Using password instead of Personal Access Token / 使用了密码而不是个人访问令牌"
    echo "     • Docker Hub requires PATs, not passwords"
    echo "     • Docker Hub 需要 PAT，而不是密码"
    echo "     • Create a PAT at: https://hub.docker.com/settings/security"
    echo "     • 在此创建 PAT：https://hub.docker.com/settings/security"
    echo ""
    echo "  3. Token has wrong permissions / 令牌权限错误"
    echo "     • Select 'Read & Write' when creating the token"
    echo "     • 创建令牌时选择'读写'权限"
    echo ""
    echo "  4. Token has expired or been revoked / 令牌已过期或被撤销"
    echo "     • Create a new token at Docker Hub"
    echo "     • 在 Docker Hub 创建新令牌"
    echo ""
    exit 1
fi
