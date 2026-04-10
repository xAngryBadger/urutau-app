# Guia Operacional Completo - Windows -> CachyOS (Dual Boot + Hyprland + Rice)

Guia focado no seu caso real: Windows 10, RTX 3060 sem iGPU, dual boot, repos em `E:\gazella`, stack Flutter/Java e personalizacao pesada (incluindo lockscreen `qylock` Ninja Gaiden).

## 0) O que este guia resolve

- instalacao dual boot segura sem destruir Windows;
- setup NVIDIA correto para quem nao tem GPU integrada;
- primeira inicializacao em formato runbook (ordem exata);
- montar particoes NTFS do Windows no Linux;
- restaurar credenciais e ambiente dev;
- aplicar rice cedo (logo apos base estavel), incluindo `qylock`.

---

## 1) Pre-flight no Windows (obrigatorio)

### 1.1 Backup minimo (nao pular)

- `C:\Users\<usuario>\.ssh`
- `C:\Users\<usuario>\.gnupg`
- `C:\Users\<usuario>\.gitconfig`
- `E:\gazella` (repos criticos)
- `C:\migration-plan` (manifesto/plano)

### 1.2 Fast Startup e hibernacao

Execute como admin:

```powershell
powercfg /h off
powercfg /a
```

Status esperado: `Inicializacao Rapida` indisponivel.

### 1.3 BIOS/UEFI

- UEFI: ON
- AHCI: ON
- Secure Boot: preferencialmente OFF (facilita modulo NVIDIA proprietario)

---

## 2) Particionamento do SSD (resposta direta ao que voce perguntou)

Sim: **encolher o C: e deixar como Nao alocado**.

### 2.1 Metodo recomendado (GUI)

1. `Win + R` -> `diskmgmt.msc`
2. Clique em `C:`
3. `Diminuir volume...`
4. Reduza `409600 MB` (aprox. 400 GB) ou mais
5. Deixe como **Nao alocado**

Nao crie NTFS nesse espaco.

### 2.2 Metodo `diskpart` (alternativo)

```powershell
diskpart
list disk
select disk 0
list volume
select volume <numero-do-C>
shrink desired=409600
exit
```

---

## 3) Pendrive bootavel e instalacao CachyOS

### 3.1 Pendrive

- use 16 GB;
- grave ISO com Rufus/BalenaEtcher em GPT/UEFI.

### 3.2 Instalacao (manual partitioning)

No instalador CachyOS:

- mexa apenas no espaco nao alocado;
- nao toque na EFI do Windows, `C:` e recovery.

Layout recomendado (400 GB):

- `/` -> 140 GB (ext4)
- `/home` -> restante (ext4)
- `swap` -> 8 a 16 GB (opcional)

Bootloader: no mesmo disco UEFI do Windows.

---

## 4) Runbook do primeiro boot Linux (ordem exata)

### 4.1 Base critica (rede + update + GPU)

```bash
sudo pacman -Syu --noconfirm
sudo pacman -S --needed nvidia nvidia-utils lib32-nvidia-utils
reboot
```

Depois do reboot:

```bash
nvidia-smi
```

Se aparecer sua RTX 3060, a base de video esta OK.

### 4.2 Infra essencial (antes de rice)

```bash
sudo pacman -S --needed \
  base-devel git curl wget unzip zip openssh neovim \
  ntfs-3g pavucontrol networkmanager
sudo systemctl enable --now NetworkManager
```

### 4.3 Monte o disco do Windows (para puxar arquivos)

```bash
lsblk -f
sudo mkdir -p /mnt/windows_e
sudo mount -t ntfs3 /dev/<particao-ntfs-do-E> /mnt/windows_e
ls /mnt/windows_e
```

Persistencia:

```bash
sudo blkid
```

Adicione em `/etc/fstab`:

```fstab
UUID=<uuid-ntfs-e> /mnt/windows_e ntfs3 rw,uid=1000,gid=1000,umask=022,windows_names,noatime 0 0
```

Teste:

```bash
sudo mount -a
```

### 4.4 Restore de credenciais

```bash
mkdir -p ~/.ssh ~/.gnupg
cp -r /mnt/windows_e/<backup>/.ssh/* ~/.ssh/
cp -r /mnt/windows_e/<backup>/.gnupg/* ~/.gnupg/
cp /mnt/windows_e/<backup>/.gitconfig ~/
chmod 700 ~/.ssh ~/.gnupg
chmod 600 ~/.ssh/* ~/.gnupg/*
```

---

## 5) Rice cedo (sim, pode ser o primeiro bloco apos base estavel)

Voce perguntou se pode ser logo no inicio: **sim**, desde que faca depois de `nvidia-smi` e `mount -a` ok.

## 5.1 Instalar Hyprland e stack visual

```bash
sudo pacman -S --needed \
  hyprland waybar rofi dunst kitty thunar \
  xdg-desktop-portal-hyprland qt5-wayland qt6-wayland \
  wl-clipboard grim slurp swaybg swww \
  polkit-gnome network-manager-applet \
  sddm
sudo systemctl enable sddm
```

No `~/.config/hypr/hyprland.conf` use:

```ini
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = GBM_BACKEND,nvidia-drm
```

---

## 6) qylock (Ninja Gaiden) sem distoar do plano

Repositorio: [Darkkal44/qylock](https://github.com/Darkkal44/qylock?tab=readme-ov-file)

### 6.1 Dependencias principais (baseado no README)

Para SDDM themes:

```bash
sudo pacman -S --needed \
  sddm qt6-declarative qt6-5compat qt6-svg \
  qt6-multimedia qt6-multimedia-ffmpeg \
  gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly \
  fzf
```

Para quickshell lockscreen:

```bash
sudo pacman -S --needed \
  quickshell qt6-declarative qt6-5compat \
  qt6-multimedia qt6-multimedia-ffmpeg \
  gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly \
  fzf
```

### 6.2 Instalar qylock

```bash
git clone https://github.com/Darkkal44/qylock.git ~/Downloads/qylock
cd ~/Downloads/qylock
chmod +x sddm.sh quickshell.sh
./sddm.sh
./quickshell.sh
```

### 6.3 Selecionar tema Ninja Gaiden

- abra o diretorio de temas instalado;
- selecione o tema `Ninja Gaiden` no SDDM (ou no quickshell lockscreen conforme script);
- se o tema pedir assets/font, coloque em `themes/<tema>/font/` como descrito no README.

### 6.4 Atalho de lockscreen no Hyprland

No README do `qylock`, o lock pode apontar para:

```bash
~/.local/share/quickshell-lockscreen/lock.sh
```

No Hyprland, crie um bind para esse script.

---

## 7) Ambiente dev (Flutter/Java etc.)

```bash
sudo pacman -S --needed \
  docker docker-compose \
  nodejs npm \
  python python-pip pipx \
  jdk21-openjdk gradle maven \
  go rustup \
  flutter dart android-tools
```

Docker:

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Relogue e valide:

```bash
flutter doctor
java -version
gradle -v
docker --version
```

---

## 8) Perifericos (Razer Kraken, teclado mecanico, Fifine)

- Kraken: audio deve funcionar; efeitos proprietarios podem nao acompanhar.
- Fifine USB: normalmente plug-and-play.
- Teclado mecanico: uso base OK; RGB/macros dependem de suporte.

Opcional Razer:

```bash
sudo pacman -S --needed openrazer-daemon polychromatic
```

---

## 9) O que fica de fora no Linux (expectativa real)

- Synapse e suites proprietarias Windows-only;
- utilitarios de fabricante de placa-mae;
- alguns jogos com anti-cheat restritivo;
- partes de audio/RGB proprietarias.

---

## 10) Checklist final (feito = pronto)

- [ ] `powercfg /a` sem Fast Startup
- [ ] 400 GB+ como nao alocado
- [ ] CachyOS instalado sem tocar no Windows
- [ ] `nvidia-smi` OK
- [ ] `/mnt/windows_e` montando via `fstab`
- [ ] `.ssh`, `.gnupg`, `.gitconfig` restaurados
- [ ] Hyprland iniciando
- [ ] `qylock` instalado com Ninja Gaiden ativo
- [ ] Flutter/Java/Gradle/Docker validados
- [ ] Repos de `E:\gazella` acessiveis no Linux
