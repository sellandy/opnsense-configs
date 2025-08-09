# opnsense-configs
Alle OPNsense-Konfigurationsdateien und Skripte, die nicht über die GUI eingestellt werden können.

# OPNsense Unbound Setup

Dieses Repository enthält Skripte zur Konfiguration von **Unbound** auf OPNsense unter Verwendung des Template-Mechanismus. Die Skripte ermöglichen erweiterte Einstellungen, insbesondere zur Sicherheit und zur Integration von privaten Domains.

## Funktionen des Setup-Skripts

Das Skript **setup.sh** führt folgende Aufgaben aus:
- Es nutzt den **OPNsense-Template-Mechanismus**, um Konfigurationsdateien für Unbound zu generieren.
- Es fügt **Sicherheitsoptimierungen** hinzu für Unbound.
- Es ermöglicht **Einstellungen für die Nutzung von Tor** über Unbound.
- Es setzt eine **benutzerdefinierte Domain**, die als Argument übergeben werden kann.
  Die (lokale) Domain wollen wir später Autoritativ über BIND verwalten lassen.
- Es wird ein **IPv6 Dynamic Address Assignment** Update-Skript für den KEA DHCP bereitgestellt.
  Dieses muss in **/var/etc/dhcp6c_wan_script.sh** aufgerufen werden (trigger)

## Installation
Falls `git` nicht auf OPNsense installiert ist, kann es mit folgendem Befehl hinzugefügt werden:
```sh
pkg install git
```
Dann das Repository klonen:
```sh
cd /usr/local/
git clone https://github.com/sellandy/opnsense-configs.git
cd opnsense-configs
```

## Nutzung des Skripts

Das Skript muss mit **Root-Rechten** ausgeführt werden. Es erwartet eine **Domain als Argument**:
```sh
sudo ./setup_unbound.sh example.com
```
Falls keine Domain übergeben wird, gibt das Skript eine Fehlermeldung aus.

## Was macht das Skript im Detail?

1. **OPNsense Template-Mechanismus aktivieren:**
   - Erstellt die Datei `/usr/local/opnsense/service/templates/OPNsense/Unbound/+TARGETS`.
   - Weist Unbound an, Konfigurationsdateien aus einem spezifischen Verzeichnis zu laden.

2. **Private Domain einfügen:**
   - Die Domain wird aus dem übergebenen Argument gesetzt.

3. **Erweiterte Sicherheitseinstellungen für Unbound:**
   - Optimierungen für **EDNS-Puffergrößen**, **DNSSEC** und **Glue-Trust**.

4. **Tor-Integration:**
   - Erlaubt das Setzen von `.onion` als private Domain.
   - Weitere Informationen zur sicheren Nutzung von Tor mit OPNsense findest du in diesem Blogpost: [Sicherer Zugriff auf .onion-Seiten mit OPNsense und Tor](https://sellandy.de/sicherer-zugriff-auf-onion-seiten-mit-opnsense-und-tor)

5. **Unbound neu starten:**
   - Nach den Änderungen wird die Konfiguration geprüft und der Dienst neugestartet.

6. **Bereitstellen eines Kea-update-Skripts**
   - Das Shell Scrikpt macht ersmal gar nichts. Es muss entsprechend eingebunden werden um einen Trigger zu erhalten.
     Empfehlung **/var/etc/dhcp6c_wan_script.sh**. Achtung dieses File wird nach einem OPNsense Update ersetzt!

## Lizenz
Dieses Projekt ist unter der **MIT-Lizenz** veröffentlicht. Siehe die Datei `LICENSE` für weitere Details.


