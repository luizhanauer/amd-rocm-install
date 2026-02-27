#!/bin/bash

# ==============================================================================
# Setup Ollama + ROCm (Otimizado para RX 6600 XT no Ubuntu 24.04 Noble)
# ==============================================================================

set -e

# Configurações de Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}===> Iniciando Verificações de Integridade <===${NC}"

# 1. Validação de Privilégios
if [[ "$EUID" -ne 0 ]]; then 
    echo -e "${RED}Erro: Este script deve ser executado como root (sudo).${NC}"
    exit 1
fi

# 2. Validação de Versão do OS (Gatekeeper)
OS_CODENAME=$(lsb_release -c -s)
if [[ "$OS_CODENAME" != "noble" ]]; then
    echo -e "${RED}Erro Crítico: Detectado Ubuntu $OS_CODENAME. Este script requer o Ubuntu 24.04 (noble).${NC}"
    exit 1
fi

# 3. Validação de Hardware (AMD GPU)
if ! lspci | grep -i "VGA\|Display" | grep -iq "AMD"; then
    echo -e "${RED}Erro: Nenhuma GPU AMD detectada via lspci. Abortando instalação do driver.${NC}"
    exit 1
fi
echo -e "${GREEN}Hardware e OS validados com sucesso.${NC}"

# 4. Busca dinâmica da última versão do instalador AMD
echo -e "${YELLOW}Buscando versão mais recente do driver AMD para Noble...${NC}"
REPO_URL="https://repo.radeon.com/amdgpu-install/latest/ubuntu/noble/"
LATEST_DEB=$(curl -s $REPO_URL | grep -oP 'amdgpu-install_[\d.-]+_all\.deb' | head -1)

if [ -z "$LATEST_DEB" ]; then
    LATEST_DEB="amdgpu-install_7.2.70200-1_all.deb" 
    DOWNLOAD_URL="https://repo.radeon.com/amdgpu-install/7.2/ubuntu/noble/$LATEST_DEB"
else
    DOWNLOAD_URL="${REPO_URL}${LATEST_DEB}"
fi

# 5. Preparação do Sistema
echo -e "${YELLOW}Instalando dependências de build e utilitários...${NC}"
apt update && apt upgrade -y
apt install -y binutils wget software-properties-common python3-pip curl

# 6. Instalação do ROCm
echo -e "${YELLOW}Baixando instalador: $LATEST_DEB${NC}"
wget -q "$DOWNLOAD_URL" -O /tmp/amdgpu-install.deb
apt install -y /tmp/amdgpu-install.deb

echo -e "${YELLOW}Instalando stack ROCm (Usecase: Compute)...${NC}"
# --no-dkms é usado para simplificar a instalação em kernels padrão
amdgpu-install --usecase=rocm --no-dkms -y

# 7. Configuração de Permissões
echo -e "${YELLOW}Adicionando usuário $SUDO_USER aos grupos de hardware...${NC}"
usermod -aG video $SUDO_USER
usermod -aG render $SUDO_USER

# 8. Override do Systemd (O Pulo do Gato)
echo -e "${YELLOW}Configurando persistência da variável HSA para RX 6600 XT...${NC}"
OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
mkdir -p "$OVERRIDE_DIR"

cat <<EOF > "$OVERRIDE_DIR/override.conf"
[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=10.3.0"
EOF

# 9. Instalação do Ollama e Recarga de Serviços
echo -e "${YELLOW}Instalando Ollama e aplicando configurações...${NC}"
curl -fsSL https://ollama.com/install.sh | sh
systemctl daemon-reload
systemctl restart ollama

# 10. Card de Sucesso Final
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}   INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NC}"
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}Instalação finalizada para $SUDO_USER na RX 6600 XT!${NC}"
echo -e "Para testar, abra um novo terminal e rode:"
echo -e "${BLUE}ollama run qwen2.5-coder:7b${NC}"
echo -e "Monitore com: ${BLUE}watch -n 0.5 rocm-smi${NC}"