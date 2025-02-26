# Skripti Nõuded

- **Operatsioonisüsteem:** Windows Server 2022  
- **Administreerimisõigused:** Käivita skript administraatori õigustes.  
- **PowerShelli versioon:** Windows PowerShell 5.1 või uuem.  
- **Võrguadapter:** Skript eeldab võrgu liidest nimega "Ethernet0". Kohanda vastavalt oma süsteemile.  
- **Staatiline IP-konfiguratsioon:** Veendu, et skriptis määratud võrgusseaded (IP, lüüs, DNS) vastaksid sinu keskkonnale.  
- **Active Directory domeeniteenused:** Skript installib AD DS-i ja konfigureerib uue metsa. Kontrolli oma domeeni parameetreid.  
- **Varundamise seadistus:** Varundamiseks kasutatakse ketast number 1; veendu, et see oleks saadaval ja mitte kasutusel.  
- **Taaskäivitamise nõue:** Skript sisaldab süsteemi taaskäivitamist lõpus. Veendu, et kõik salvestamata andmed oleksid varundatud enne käivitamist.

Tagada, et need nõuded oleksid täidetud skripti edukaks käivitamiseks.