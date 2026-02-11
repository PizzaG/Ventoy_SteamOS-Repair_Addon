## Tool Info
Allows You To Easily Use Ventoy USB With The SteamOS Repair Image.


## General & Support Info
- Requires Linux
- Supports Ventoy Fresh(Wipe) OR Existing Installs(NoWipe)
- Probably Only Supports GPT (MBR Untested by me)
- Requires 8gb Free Space On Ventoy Data Partition


## Install - Fresh Or Existing
- Download this Ventoy Addon
- Download the SteamOS Repair Image (.img format)
- Make sure the SteamOS repair image filename contains `repair`
- Download the Ventoy Linux Installer (NOT the livecd.iso)  
  https://www.ventoy.net/en/download.html
- Extract the Ventoy Installer
- Extract the Ventoy Addon
- Copy the files and folder from the extracted Ventoy Addon to the root of the extracted Ventoy Installer folder
- Copy the SteamOS repair image to the extracted Ventoy Installer folder
- Run:
  ```bash
  ./A-Team-Ventoy+SteamOS_Installer.sh
- Choose your desired Options
- ** If you chose Existing Option, you can use the supplied ventoy_grub.cfg in A-Team folder.
ventoy_grub.cfg goes into your Ventoy data partition inside a folder named: ventoy


## Boot SteamOS From Ventoy
- Boot Ventoy
- Select F6
- Select the SteamOS Repair / Install from the Menu Entry
- Relax & Enjoy
