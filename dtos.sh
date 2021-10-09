#!/usr/bin/env bash
#  ____ _____ ___  ____
# |  _ \_   _/ _ \/ ___|   Derek Taylor (DistroTube)
# | | | || || | | \___ \   http://www.youtube.com/c/DistroTube
# | |_| || || |_| |___) |  http://www.gitlab.com/dwt1/dtos
# |____/ |_| \___/|____/
#
# NAME: DTOS
# DESC: An installation and deployment script for DT's Xmonad desktop.
# WARNING: Run this script at your own risk.
# DEPENDENCIES: dialog

if [ "$(id -u)" = 0 ]; then
    echo "##################################################################"
    echo "This script MUST NOT be run as root user since it makes changes"
    echo "to the \$HOME directory of the \$USER executing this script."
    echo "The \$HOME directory of the root user is, of course, '/root'."
    echo "We don't want to mess around in there. So run this script as a"
    echo "normal user. You will be asked for a sudo password when necessary."
    echo "##################################################################"
    exit 1
fi

echo "################################################################"
echo "## Syncing the repos and installing 'dialog' if not installed ##"
echo "################################################################"
sudo pacman --noconfirm --needed -Sy dialog || error "Error syncing the repos."

error() { \
    clear; printf "ERROR:\\n%s\\n" "$1" >&2; exit 1;
}

welcome() { \
    dialog --colors --title "\Z5\ZbInstalling DTOS!" --msgbox "\Z2This is a script that will install what I sarcastically call \Z5DTOS (DT's operating system)\Zn\Z2. It's really just an installation script for those that want to try out my XMonad desktop.  We will add DTOS repos to Pacman and install the XMonad tiling window manager, the Xmobar panel, the Alacritty terminal, the Fish shell, Doom Emacs and many other essential programs needed to make my dotfiles work correctly.\\n\\n-DT (Derek Taylor, aka DistroTube)" 16 60

    dialog --colors --title "\Z5\ZbStay near your computer!" --yes-label "Continue" --no-label "Exit" --yesno "\Z2This script is not allowed to be run as root. But you will be asked to enter your sudo password at various points during this installation. This is to give PACMAN the necessary permissions to install the software." 8 60
}

welcome || error "User choose to exit."

lastchance() { \
    dialog --colors --title "\Z5\ZbInstalling DTOS!" --msgbox "\Z2WARNING! The DTOS installation script is currently in public beta testing. There are almost certainly errors in it; therefore, it is strongly recommended that you not install this on production machines. It is recommended that you try this out in either a virtual machine or on a test machine." 16 60

    dialog --colors --title "\Z5\ZbAre You Sure You Want To Do This?" --yes-label "Begin Installation" --no-label "Exit" --yesno "\Z2Shall we begin installing DTOS?" 8 60 || { clear; exit 1; }
}

lastchance || error "User choose to exit."

addrepo() { \
    echo "#########################################################"
    echo "## Adding the DTOS core repository to /etc/pacman.conf ##"
    echo "#########################################################"
    grep -qxF "[dtos-core-repo]" /etc/pacman.conf ||
        (echo "[dtos-core-repo]"; echo "SigLevel = Required DatabaseOptional"; echo "Server = https://gitlab.com/dwt1/\$repo/-/raw/main/\$arch") | sudo tee -a /etc/pacman.conf
}

addrepo || error "Error adding DTOS repo to /etc/pacman.conf."

addkeyserver() { \
    echo "#######################################################"
    echo "## Adding keyservers to /etc/pacman.d/gnupg/gpg.conf ##"
    echo "#######################################################"
    grep -qxF "keyserver hkp://keyserver.ubuntu.com:80" /etc/pacman.d/gnupg/gpg.conf || echo "keyserver hkp://keyserver.ubuntu.com:80" | sudo tee -a /etc/pacman.d/gnupg/gpg.conf
    grep -qxF "keyserver hkps://keyserver.ubuntu.com:443" /etc/pacman.d/gnupg/gpg.conf || echo "keyserver hkps://keyserver.ubuntu.com:443" | sudo tee -a /etc/pacman.d/gnupg/gpg.conf
}

addkeyserver || error "Error adding keyservers to /etc/pacman.d/gnupg/gpg.conf"

receive_key() { \
    echo "#####################################"
    echo "## Adding PGP key C71486C31555B12E ##"
    echo "#####################################"
    sudo pacman-key --recv-key C71486C31555B12E
    sudo pacman-key --lsign-key C71486C31555B12E
}

receive_key || error "Error receiving PGP key C71486C31555B12E"

# Let's install each package listed in the pkglist.txt file.
sudo pacman --needed -S - < pkglist.txt

echo "#########################################################"
echo "## Installing Doom Emacs. This may take a few minutes. ##"
echo "#########################################################"
[ -d ~/.emacs.d ] && mv ~/.emacs.d ~/.emacs.d.bak.$(date +"%Y%m%d_%H%M%S")
[ -f ~/.emacs ] && mv ~/.emacs ~/.emacs.bak.$(date +"%Y%m%d_%H%M%S")
git clone --depth 1 https://github.com/hlissner/doom-emacs ~/.emacs.d
~/.emacs.d/bin/doom install

echo "################################################################"
echo "## Copying DTOS configuration files from /etc/dtos into \$HOME ##"
echo "################################################################"
[ ! -d /etc/dtos ] && sudo mkdir /etc/dtos
[ -d /etc/dtos ] && mkdir ~/dtos-backup-$(date +%Y.%m.%d-%H%M) && cp -Rf /etc/dtos ~/dtos-backup-$(date +%Y.%m.%d-%H%M)
[ ! -d ~/.config ] && mkdir ~/.config
[ -d ~/.config ] && mkdir ~/.config-backup-$(date +%Y.%m.%d-%H%M) && cp -Rf ~/.config ~/.config-backup-$(date +%Y.%m.%d-%H%M)
cd /etc/dtos && cp -Rf . ~ && cd -

# Change all scripts in .local/bin to be executable.
find $HOME/.local/bin -type f -print0 | xargs -0 chmod 775

cp /etc/dtos/.xmonad/pacman-hooks/recompile-xmonad.hook /etc/pacman.d/hooks/
cp /etc/dtos/.xmonad/pacman-hooks/recompile-xmonadh.hook /etc/pacman.d/hooks/

xmonad_recompile() { \
    echo "########################"
    echo "## Recompiling XMonad ##"
    echo "########################"
    xmonad --recompile
}

xmonad_recompile || error "Error recompiling Xmonad!"

xmonadctl_compile() { \
    echo "####################################"
    echo "## Compiling the xmonadctl script ##"
    echo "####################################"
    ghc -dynamic "$HOME"/.xmonad/xmonadctl.hs
}

xmonadctl_compile || error "Error compiling the xmonadctl script!"

PS3='Set default user shell (enter number): '
shells=("fish" "bash" "zsh" "quit")
select choice in "${shells[@]}"; do
    case $choice in
         fish)
            sudo chsh $USER -s /bin/fish && \
            echo "$choice has been set as your default USER shell.\n
                  Logging out is required for this take effect."
            ;;
         bash)
            sudo chsh $USER -s /bin/bash && \
            echo "$choice has been set as your default USER shell.\n
                  Logging out is required for this take effect."
            ;;
         zsh)
            sudo chsh $USER -s /bin/zsh && \
            echo "$choice has been set as your default USER shell.\n
                  Logging out is required for this take effect."
	          break
            ;;
         quit)
	          echo "User requested exit"
	          exit
	          ;;
         *)
            echo "invalid option $REPLY"
            ;;
    esac
done

loginmanager() { \
    dialog --colors --title "\Z5\ZbInstallation Complete!" --msgbox "\Z2Now logout of your current desktop environment or window manager and choose XMonad from your login manager.  ENJOY!" 10 60
}

loginmanager && echo "DTOS has been installed!"
