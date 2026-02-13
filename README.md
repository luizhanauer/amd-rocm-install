# Configurar o AMD ROCm 7.x e o Ollama (Ubuntu 24.04 e Ubuntu Server 24.04)
Necessário para o uso de IA local com a AMD GPU.

### 1. Preparação do Sistema

Como é uma instalação limpa do Ubuntu Server, primeiro atualizamos tudo e instalamos as dependências de build:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y binutils wget software-properties-common python3-pip

```

### 2. Instalação do Driver AMD e ROCm

Em 2026, a AMD simplificou o instalador. Vamos baixar o repositório oficial e instalar o stack completo para computação (omitindo os drivers de vídeo/GUI para economizar VRAM):

https://www.amd.com/en/support/download/linux-drivers.html#linux-for-radeon

```bash
# Baixar e instalar o instalador de repositório da AMD
wget https://repo.radeon.com/amdgpu-install/7.2/ubuntu/noble/amdgpu-install_7.2.70200-1_all.deb

sudo apt install ./amdgpu-install_7.2.70200-1_all.deb

# Instalar apenas o stack de computação (ROCm) para economizar recursos
sudo amdgpu-install --usecase=rocm --no-dkms -y

```

### 3. Configuração de Permissões

Para que o Ollama acesse a GPU sem precisar de `sudo`, adicione seu usuário aos grupos de vídeo e render:

```bash
sudo usermod -aG video $USER
sudo usermod -aG render $USER

```

*Importante: Reinicie o servidor ou faça logout/login para aplicar os grupos.*

### 4. O "Pulo do Gato" para a RX 6600 XT

A RX 6600 XT (arquitetura gfx1032) às vezes precisa que o ROCm "pense" que ela é uma placa mais potente para habilitar todas as bibliotecas de aceleração. Se o Ollama não detectar a GPU de primeira, adicione esta variável ao seu `.bashrc`:

```bash
echo 'export HSA_OVERRIDE_GFX_VERSION=10.3.0' >> ~/.bash_rc
source ~/.bash_rc

```

### 5. Instalação do Ollama (Otimizado para AMD)

O script oficial do Ollama já detecta o ROCm automaticamente se ele estiver instalado corretamente:

```bash
curl -fsSL https://ollama.com/install.sh | sh

```

### 6. Verificação e Teste

Para garantir que o Ollama está usando sua 6600 XT e não o processador:

1. **Verifique o ROCm:** `rocminfo` (deve listar sua GPU).
2. **Teste um modelo leve (Qwen3-Coder 7B):**
```bash
ollama run qwen3-coder:7b

```


3. **Monitore o uso da GPU em tempo real:**
Abra outro terminal e use: `watch -n 0.5 rocm-smi`

---
