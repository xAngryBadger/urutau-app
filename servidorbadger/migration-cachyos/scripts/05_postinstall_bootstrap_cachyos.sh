#!/usr/bin/env bash
set -euo pipefail

echo "[1/5] Atualizando sistema"
sudo pacman -Syu --noconfirm

echo "[2/5] Instalando base de desenvolvimento"
sudo pacman -S --noconfirm --needed \
  base-devel git curl wget openssh neovim \
  docker docker-compose \
  nodejs npm python python-pip pipx \
  jdk-openjdk maven gradle \
  go rustup

echo "[3/5] Habilitando Docker"
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" || true

echo "[4/5] Ferramentas opcionais (AUR helper yay)"
if ! command -v yay >/dev/null 2>&1; then
  git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
  pushd /tmp/yay-bin >/dev/null
  makepkg -si --noconfirm
  popd >/dev/null
fi
yay -S --noconfirm --needed visual-studio-code-bin google-chrome discord slack-desktop zoom

echo "[5/5] Pos-instalacao"
echo "Reinicie a sessao para aplicar grupo docker."
echo "Depois restaure seus backups em: ~/.ssh ~/.gnupg ~/.config e repos."
