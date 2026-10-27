
DAWO werkplek
1. Installer-stick maken (op een bestaande NixOS-machine)
Eenmalig. De stick hoeft niet opnieuw gemaakt te worden als de repo verandert: het installatiescript komt bij elke installatie vers van GitHub. Alleen als installer/iso.nix verandert, maak je de stick opnieuw.

Steek de stick erin en zoek op hoe hij heet (kolom TRAN = usb, bijvoorbeeld sdb):

lsblk -o NAME,SIZE,TRAN,MODEL
Bouw de stick en schrijf hem weg. Vervang sdX door de naam van de stick. LET OP: dd vraagt niets, een verkeerde letter wist die schijf.

nix --extra-experimental-features 'nix-command flakes' build --refresh github:Edwinakamosez/dawo-werkplek#installer-iso && sudo dd if=$(echo result/iso/*.iso) of=/dev/sdX bs=4M status=progress conv=fsync
Klaar zodra dd stopt en de prompt terug is.

(Op Windows: bouw het ISO op een NixOS-machine of in WSL en zet result/iso/*.iso met Rufus in DD-modus op de stick.)

2. Laptop installeren
In de BIOS/UEFI: Secure Boot uit, opstarten van USB aan.
Stick erin, laptop aanzetten en opstarten van de stick (F12, F9 of Esc).
Het installatiescript start vanzelf:
geen kabel? Dan opent eerst een wifi-menu;
kies het type laptop en de partner;
typ JA om de schijf te wissen;
kies het LUKS-wachtwoord (zonder dit wachtwoord is er geen herstel).
Aan het eind: stick eruit, Enter, de laptop herstart.
Gestopt of mislukt? Opnieuw starten met:

sudo dawo-install
Menu overslaan: sudo dawo-install laptop-sata-edwin.

Meekijken naar geheugen en swap tijdens het installeren: Ctrl+Alt+F2, dan watch -n2 'free -h; swapon --show'. Terug met Ctrl+Alt+F1.

3. Zonder eigen stick
Start van een gewone NixOS-installer-stick, zorg voor internet en voer uit:

curl -sL https://raw.githubusercontent.com/Edwinakamosez/dawo-werkplek/main/install.sh | sudo bash
GitHub bewaart install.sh soms een paar minuten in de cache. Net iets aangepast? Wacht dan even.

Bijwerken van een geïnstalleerde laptop
Gaat vanzelf via comin. Handmatig (vervang de hostnaam):

sudo nixos-rebuild switch --refresh --flake github:Edwinakamosez/dawo-werkplek#laptop-sata-edwin
