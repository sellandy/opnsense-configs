# opnsense-configs
All OPNsense configuration files and scripts that cannot be set via the GUI.

# OPNsense Unbound Setup

Dieses Repository enthält Skripte zur Konfiguration von **Unbound** auf OPNsense unter Verwendung des Template-Mechanismus. Die Skripte ermöglichen erweiterte Einstellungen, insbesondere zur Sicherheit und zur Integration von privaten Domains.

## Funktionen des Setup-Skripts

Das Skript **setup_unbound.sh** führt folgende Aufgaben aus:
- Es nutzt den **OPNsense-Template-Mechanismus**, um Konfigurationsdateien für Unbound zu generieren.
- Es erstellt eine **SOA (Start of Authority) für private Domains**.
- Es fügt **Sicherheitsoptimierungen** hinzu.
- Es ermöglicht **Einstellungen für die Nutzung von Tor** über Unbound.
- Es setzt eine **benutzerdefinierte Domain**, die als Argument übergeben werden kann.

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
   - Erstellt eine **SOA für private Domains** in der Datei `private_domains.conf`.
   - Die Domain wird aus dem übergebenen Argument gesetzt.

3. **Erweiterte Sicherheitseinstellungen für Unbound:**
   - Optimierungen für **EDNS-Puffergrößen**, **DNSSEC** und **Glue-Trust**.

4. **Tor-Integration:**
   - Erlaubt das Setzen von `.onion` als private Domain.

5. **Unbound neu starten:**
   - Nach den Änderungen wird die Konfiguration geprüft und der Dienst neugestartet.

## Beispiel für die generierte Konfiguration
Nach dem Skriptlauf generiert Unbound die folgenden Dateien:
### `private_domains.conf`
```yaml
server:
  local-data: "example.com. 3600 IN SOA ns1.dynu.com. administrator.dynu.com. 44196965 1800 300 86400 1800"
```

### `expert.conf`
```yaml
server:
  local-zone: "onion." nodefault
  edns-buffer-size: 1232
  use-caps-for-id: no
  harden-glue: yes
```

## Lizenz
Dieses Projekt ist unter der **MIT-Lizenz** veröffentlicht. Siehe die Datei `LICENSE` für weitere Details.


