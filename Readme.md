Boot de installer-stick, open een terminal en voer dit uit:

curl -L https://raw.githubusercontent.com/Edwinakamosez/dawo-werkplek/main/install.sh -o /tmp/install.sh && sudo bash /tmp/install.sh
 
Je krijgt dan het menu om het type laptop en de partner te kiezen. Wil je het menu overslaan, geef dan de naam mee:
sudo bash /tmp/install.sh laptop-sata-edwin
 
GitHub bewaart het bestand soms een paar minuten in de cache. Controleer na het downloaden dat je de nieuwste versie hebt:
 
grep -c "Kies het type laptop" /tmp/install.sh
 
Geeft dit 1, dan is het de nieuwe versie met het menu. Geeft het 0, wacht dan even en download opnieuw.
Zorg ook dat je de drvPath-controle voor alle vier de configuraties hebt gedaan (laptop-sata-edwin, laptop-nvme-edwin, laptop-sata-ruud, laptop-nvme-ruud) voordat je het script op een laptop gebruikt, want het script wist de schijf.
