#!/bin/bash

INSTALLSCRIPT=./install-script.sh
WOL_SCRIPT=./script-files/wol-script.sh

mkdir "script-files"

if test -f "$INSTALLSCRIPT"; then
  if test -f "$INSTALLSCRIPT.bak"; then
    rm "$INSTALLSCRIPT.bak"
  fi
  mv "$INSTALLSCRIPT" "$INSTALLSCRIPT.bak"
fi

cat >>$INSTALLSCRIPT <<EOF
#!/bin/bash

EOF

echo "O sistema alvo do script é com base arch ou debian? (arch/debian)"
read SISTEMA_ALVO

PRECISA_PPA=true
COMANDO_INSTALL='sudo apt install -y'

if [ "${SISTEMA_ALVO,,}" == "arch" ]; then
  cat >>$INSTALLSCRIPT <<EOF
# Adicionando o yay
sudo pacman -S git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd ..
rm -rf ./yay
yay

EOF
  PRECISA_PPA=false
  COMANDO_INSTALL='yay -S'
fi

if [ "$PRECISA_PPA" == true ]; then
  PRIMEIRO_ITEM=true
  PPA_TEMP=./temp-install-script.txt
  PPA_ARRAY=()

  cat >>$PPA_TEMP <<EOF
$(./files/listppas.sh)
EOF

  while read -r LINHA_PPA; do
    PPA_ARRAY+=("$LINHA_PPA")
  done <$PPA_TEMP

  rm $PPA_TEMP

  for PPA_REPO in "${PPA_ARRAY[@]}"; do
    echo "Você deseja adicionar o seguinte item ao script? (Y/n)"
    echo $PPA_REPO
    read PPA_ADICIONAR
    if [ "${PPA_ADICIONAR,,}" == "y" ]; then
      if [ "$PRIMEIRO_ITEM" == true ]; then
        cat >>$INSTALLSCRIPT <<EOF
# Adicionando PPAS

EOF
        PRIMEIRO_ITEM=false
      fi
      echo "$PPA_REPO" >>$INSTALLSCRIPT
    fi
  done

  cat >>$INSTALLSCRIPT <<EOF
sudo apt update

EOF
fi

echo "Quais pacotes serão instalados? Use espaço para separar um de outro, exemplo: (git firefox)"
echo "Obs.: Não incluir zsh."
read PACKAGES

if [ "$PACKAGES" != "" ]; then
  cat >>$INSTALLSCRIPT <<EOF
INSTALL_PACKAGES="wget curl unzip zip git $PACKAGES"

$COMANDO_INSTALL \$INSTALL_PACKAGES

EOF
fi

echo "Deseja adicionar o zsh ao script? (Y/n)"
read ADICIONAR_ZSH

if [ "${ADICIONAR_ZSH,,}" == "y" ]; then
  cat >>$INSTALLSCRIPT <<EOF
# Instalando o zsh 
$COMANDO_INSTALL zsh
sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

cat >> ~/.zshrc << FIM
alias editZsh='nano ~/.zshrc'
alias refresh='. ~/.zshrc'
FIM

# Adicionando a fonte necessaria para o tema
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip
unzip ./JetBrainsMono.zip -d ./JetBrainsTemp/
mkdir -p ~/.local/share/fonts
mv ./JetBrainsTemp/JetBrainsMonoNerdFont-* ~/.local/share/fonts/
fc-cache -f -v
rm -rf ./JetBrainsTemp

# Adicionando tema ao zsh
sed -i -e 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' ~/.zshrc
LUGAR_ATUAL=\`pwd\`
cd ~
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \${ZSH_CUSTOM:-\$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
cd \$LUGAR_ATUAL

# Adicionando o plugin zsh-syntax-highlighting
cd ~
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
echo "source \\\${(q-)PWD}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> \${ZDOTDIR:-\$HOME}/.zshrc
cd \$LUGAR_ATUAL

# Adicionando o plugin zsh-autosuggestions
cd ~
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
echo "source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc
cd \$LUGAR_ATUAL

EOF
fi

echo "Deseja adicionar o brew ao script? (Y/n)"
read ADICIONAR_BREW

if [ "${ADICIONAR_BREW,,}" == "y" ]; then
  cat >>$INSTALLSCRIPT <<EOF
# Instalando o homebrew
/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

EOF
  if [ "${ADICIONAR_ZSH,,}" == "y" ]; then
    cat >>$INSTALLSCRIPT <<EOF
echo "export PATH=\$PATH:/home/linuxbrew/.linuxbrew/bin" >> ~/.zshrc

EOF
  fi
fi

echo "Deseja adicionar um serviço para ativar o wakeonlan? (Y/n)"
read ADICIONAR_WOL

if [ "${ADICIONAR_WOL,,}" == "y" ]; then
  cat >>$WOL_SCRIPT <<EOF
#!/bin/bash

# Script Wake on lan

$COMANDO_INSTALL wakeonlan ethtool net-tools
NOME_REDE=\`sudo ifconfig -a | grep -Poi 'enp\ds\d'\`
sudo cat >> /root/wol_fix.sh << FIM
#!/bin/bash
ethtool -s \$NOME_REDE wol g
FIM

sudo chmod 755 /root/wol_fix.sh

sudo cat >> /etc/systemd/system/wol_fix.service << FIM
[Unit]
Description=Fix WakeOnLAN being reset to disabled on shutdown

[Service]
ExecStart=/root/wol_fix.sh
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
FIM

sudo systemctl daemon-reload
sudo systemctl enable wol_fix.service

EOF

  cat >>$INSTALLSCRIPT <<EOF
chmod 777 ./script-files/wol-script.sh
sudo "./script-files/wol-script.sh"
EOF
fi

echo "echo \"Reinicie sua sessão pra completar a execução do script.\"" >>$INSTALLSCRIPT

chmod u+x $INSTALLSCRIPT

cat $INSTALLSCRIPT
