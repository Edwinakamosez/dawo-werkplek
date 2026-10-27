
Stick maken (eenmalig)
Op een Linux-machine met Nix (bijvoorbeeld de test-VM):

nix --extra-experimental-features 'nix-command flakes' build github:Edwinakamosez/dawo-werkplek#installer-iso

Het ISO-bestand staat daarna in result/iso/. Zet het met Rufus (DD-modus) of balenaEtcher op een USB-stick. De stick hoeft niet opnieuw gemaakt te worden als de repo verandert: het script komt elke keer vers van GitHub.

Laptop installeren
Secure Boot uit, opstarten van USB aan.
Start de laptop van de stick. Het installatiescript start vanzelf. Geen kabel? Dan opent eerst een wifi-menu.
Kies het type laptop en de partner, typ JA, kies het LUKS-wachtwoord.
Aan het eind: stick eruit, Enter, de laptop herstart.
Gestopt of mislukt? Opnieuw starten met: sudo dawo-install

Zonder eigen stick
Start van een gewone NixOS-installer-stick, zorg voor internet en voer uit:

curl -sL https://raw.githubusercontent.com/Edwinakamosez/dawo-werkplek/main/install.sh | sudo bash

GitHub bewaart install.sh soms een paar minuten in de cache. Net iets aangepast? Wacht dan even.

