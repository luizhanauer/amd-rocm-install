# Ollama + AMD ROCm 7.x no Ubuntu 24.04 (Noble)

Este guia documenta o setup otimizado para rodar o **Ollama** com aceleração de hardware em GPUs AMD, especificamente para a arquitetura RDNA 2 (como a **RX 6600 XT**).

Utilizamos o **ROCm 7.x** e uma configuração de persistência via **systemd** para garantir que a GPU seja detectada sem falhas de "runner crash".

## 🔗 Referências Oficiais

* **Drivers AMD para Linux:** [AMD Support - Linux Drivers for Radeon](https://www.amd.com/en/support/download/linux-drivers.html#linux-for-radeon)
* **Repositório de Pacotes:** `repo.radeon.com`

## 📋 Pré-requisitos

* **Sistema:** Ubuntu 24.04 LTS ou Ubuntu Server 24.04 (Noble Numbat).
* **Hardware:** GPU AMD Radeon (Otimizado para RX 6600 XT com 8GB VRAM).
* **Acesso:** Usuário com privilégios de `sudo`.
* **Memória:** Recomendado 16GB+ de RAM de sistema para lidar com modelos maiores.

---

## 🚀 Opção 1: Instalação One-Liner (Recomendado)

A forma mais rápida e fácil de instalar. Acesse a [página oficial do projeto](https://luizhanauer.github.io/amd-rocm-install/) ou simplesmente rode o comando abaixo no seu terminal. Ele fará o download do script dinâmico e executará todas as validações de hardware e sistema operacional automaticamente.

```bash
curl -fsSL https://luizhanauer.github.io/amd-rocm-install/get.sh | sudo bash
```

---
## 🚀 Opção 2: Instalação Automática

O script abaixo valida o sistema operacional, verifica a presença de hardware AMD e busca automaticamente a versão mais recente do driver no repositório oficial da AMD.

### Como usar:

1. Clone este repositório ou copie o código abaixo para um arquivo chamado `get.sh`.
2. Dê permissão de execução: `chmod +x get.sh`.
3. Execute com privilégios de root: `sudo ./get.sh`.

```bash
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

```

---

## 🛠️ Opção 3: Instalação Manual

Se preferir o controle total, siga estes passos baseados em princípios de **Domain Integrity** e proteção de fronteiras do sistema.

### 1. Preparação e Repositório AMD

Instale as dependências básicas e o gerenciador de repositório da AMD:

```bash
sudo apt update && sudo apt install -y binutils wget software-properties-common
wget https://repo.radeon.com/amdgpu-install/7.2/ubuntu/noble/amdgpu-install_7.2.70200-1_all.deb
sudo apt install ./amdgpu-install_7.2.70200-1_all.deb

```

### 2. Stack de Computação (ROCm)

Instale apenas o necessário para IA para economizar recursos de sistema:

```bash
sudo amdgpu-install --usecase=rocm --no-dkms -y
sudo usermod -aG video $USER
sudo usermod -aG render $USER

```

### 3. O "Pulo do Gato": Override do Systemd

GPUs RDNA 2 muitas vezes falham na descoberta automática. O override do systemd garante que a variável de ambiente seja persistente e isolada para o serviço do Ollama:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d/
sudo nano /etc/systemd/system/ollama.service.d/override.conf

```

Adicione o conteúdo:

```ini
[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=10.3.0"

```

### 4. Instalação do Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## 📊 Verificação de Performance

Após a instalação, verifique se a GPU está sendo utilizada de forma eficiente.

* **Verificar Driver:** `rocminfo` deve listar "Radeon RX 6600 XT".
* **Monitorar VRAM:** Use `watch -n 0.5 rocm-smi` durante a execução de um modelo.