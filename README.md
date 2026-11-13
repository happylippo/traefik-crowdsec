# Traefik, CrowdSec und Basic Auth

Ein lokaler Docker-Compose-Stack für HTTPS-Routing, Traefik-Dashboard-Schutz und CrowdSec-Abwehr. Diese Light-Version enthält Traefik, CrowdSec und einen eingeschränkten Docker-Socket-Proxy. Authentifizierung erfolgt direkt über Traefik Basic Auth; Authentik und CrowdSec Manager sind nicht enthalten.

## Komponenten

| Komponente | Aufgabe |
| --- | --- |
| Traefik | HTTPS-Routing über TCP/UDP 443, Docker- und Dateiprovider, Basic Auth und CrowdSec-Bouncer |
| CrowdSec | Erkennung und Abwehr anhand von Traefik-Logs einschließlich AppSec/WAF |
| Socket-Proxy | Begrenzt den Docker-API-Zugriff für Traefik und CrowdSec |

## Voraussetzungen

- Docker Engine und Docker Compose v2 mit Unterstützung für Compose `include`
- Bash, OpenSSL und Python 3
- `curl`, falls Cloudflare-IP-Netze als vertrauenswürdige Forwarded Headers aktiviert werden
- Zugriff auf den Docker-Daemon sowie freie Ports 443/TCP und 443/UDP
- IPv6-Unterstützung für Docker-Bridge-Netzwerke

## Schnellstart

```bash
./first_install.sh
```

Der Installer fragt Zertifikatsresolver (Cloudflare, deSEC oder Let's Encrypt), E-Mail, Zertifikats- und Wildcard-Domain, Dashboard-Hostname und Basic-Auth-Benutzername und -Passwort ab. Das Passwort wird verdeckt eingelesen und als APR1-Hash in `data/traefik/.htpasswd` abgelegt. Außerdem können CrowdSec-AllowList-Einträge und vertrauenswürdige Cloudflare-Proxy-Netze festgelegt werden. DNS-API-Tokens werden bei Bedarf verdeckt abgefragt. `.env` und Passwortdatei sind nur für den Besitzer lesbar.

Leere Eingaben übernehmen Vorgaben, soweit angegeben. `traefik.localhost` eignet sich für lokale Tests, aber nicht als öffentlich gültiger TLS-Hostname. Für öffentliche Domains müssen DNS, Resolver und Zertifikatsnamen zusammenpassen. Let's Encrypt TLS-ALPN kann keine Wildcard-Zertifikate ausstellen.

## Basic Auth und Dashboard

Das Dashboard ist mit der Traefik-Middleware `basic-auth@file` geschützt. Der Installer erzeugt die Zugangsdaten; ändere sie erneut mit `./first_install.sh` oder erstelle die Hash-Zeile mit `htpasswd -nB BENUTZER` und aktualisiere `data/traefik/.htpasswd`. Die Datei enthält ausschließlich Hashes. Die Dashboard-Route ist zusätzlich auf die Netze in `data/traefik/dynamic_conf/lan-only.yml` beschränkt; passe diese Liste für dein Client-Netz an.

Weitere Dienste können das externe Compose-Netzwerk `proxy` verwenden und die Middleware `basic-auth@file` erhalten. Beispiel:

```yaml
services:
  app:
    image: example/app:latest
    networks: [proxy]
    labels:
      traefik.enable: "true"
      traefik.docker.network: proxy
      traefik.http.routers.app.rule: "Host(`app.example.com`)"
      traefik.http.routers.app.entrypoints: websecure
      traefik.http.routers.app.tls: "true"
      traefik.http.routers.app.middlewares: basic-auth@file
      traefik.http.services.app.loadbalancer.server.port: "8080"
networks:
  proxy:
    external: true
    name: proxy
```

## Verwaltung

```bash
./scripts/compose.sh ps
./scripts/compose.sh logs -f traefik
./scripts/compose.sh up -d
./scripts/compose.sh down
```

`down` löscht keine persistenten Daten. Für Backups sichere `.env`, `data/` und das CrowdSec-Datenverzeichnis.

## Struktur

- `compose/`: Compose-Fragmente
- `data/crowdsec/`: CrowdSec-Vorlagen und Laufzeitdaten
- `data/traefik/`: Traefik-Konfiguration, Zertifikate, Logs und Basic-Auth-Datei
- `scripts/`: Setup- und Compose-Hilfsskripte
- `first_install.sh`: Interaktive Erstinstallation

## CrowdSec-AllowList

Der Installer kann IP-Adressen und CIDR-Netze aufnehmen, die CrowdSec dauerhaft zulassen soll. Trenne Einträge durch Komma, Leerzeichen oder Semikolon. CrowdSec speichert diese Einträge persistent. Der Stack enthält außerdem eine CRS-Regel, die HTTP/3 in der Protokollprüfung erlaubt.

## Weiterführende Links

- [Traefik-Dokumentation](https://doc.traefik.io/traefik/)
- [CrowdSec-Dokumentation](https://docs.crowdsec.net/)
- [Ausgangsprojekt](https://github.com/happylippo/traefik-authentik-crowdsec)
