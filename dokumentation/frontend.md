## Frontend

Die folgenden Schritte wurden auf dem Raspberry Pi 3 mit dem Betriebssystem Raspbian "Jessie" getestet, um den Mikrocomputer als Access Point einzurichten und das Frontend zu hosten.

### 1. Installation

Damit der Raspberry Pi als Access Point die Webseite mithilfe des NodeJS Frameworks darstellen kann, müssen die Pakete `dnsmasq` und `hostapd` installiert sein.
Falls diese noch nicht vorhanden sind, können diese mit dem folgenden Befehl heruntergeladen werden:
```
sudo apt-get install dnsmasq hostapd
```

Das `node` Paket kann auch mithilfe des `apt` Paketmanagers heruntergeladen und installiert werden. Allerdings wird eine relativ neue Version des NodeJS Frameworks (>= 4.0.0) benötigt, weshalb man das `node` wie folgt installieren sollte:
```
wget http://node-arm.herokuapp.com/node_latest_armhf.deb
sudo dpkg -i node_latest_armhf.deb
```
Quelle: ["Raspberry Pi + Node JS" von Pieter Beulque](http://weworkweplay.com/play/raspberry-pi-nodejs/)

Der sogenannte Node-Paket-Manager (kurz `npm`) dient später zur Installation der NodeJS spezifischen "Module". Diese ermöglichen das Programmieren eines einfachen HTTP-Servers sowie die Datenübertragung über WebSockets. Zur Installation dieses Paketes reicht der Befehl:
```
sudo apt-get install npm
```

### 2. Konfiguration als "Access Point"

Wenn die Serveranwendung läuft, sollte man auch auf den HTTP Server über ein mobiles Gerät zugreifen können. Deshalb wird der Raspberry Pi als Access Point, also eine Art WLAN Router konfiguriert. Auf diesem Access Point kann man sich wie in einen normalen WiFi-Hotspot oder heimischen WLAN Router mit dem richtigen Kennwort einloggen. Der Unterschied liegt jedoch darin, dass man nach dem Verbinden mit dem Access Point keinen Zugriff auf das Internet hat, sondern einzig und allein die Webseite erreichen kann, die vom Raspberry Pi selbst gehostet wird.
Für diese Konfiguration wurde dieses [Tutorial "Using your new Raspberry Pi 3 as a WiFi Access Point" von Phil Martins](https://frillip.com/using-your-raspberry-pi-3-as-a-wifi-access-point-with-hostapd/) verwendet.

### 3. Webserver starten

Den Quelltext für die Serverapplikation befindet sich im Ordner `frontend/`. Mithilfe des NodeJS Frameworks wird es ermöglicht, einen einfachen HTTP-Server auf dem Raspberry Pi aufzusetzen, den man über WLAN erreichen kann. Bevor allerdings der Server gestartet werden kann, müssen noch die sogenannten "node modules" namens `ws`, `command-line-args` und `serialport` heruntergeladen werden. Dies erfolgt automatisch durch das Ausführen des Befehls
``` bash
npm install
```

Schließlich kann der Server mithilfe des Befehls
``` bash
node server.js
```
gestartet werden. Falls sie mit dem Raspberry Pi über WLAN verbunden sind, sollte man nun eine Webseite unter `http://192.168.2.1:8000` erreichen können, insofern die statische IP-Adresse des Raspberry Pi auf `192.168.2.1` gesetzt wurde.

### 4. Adress-Manipulation

Da das Aufrufen der Website über die IP-Adresse und den Port 8000 umständlich ist, wurde der Namensauflösung von `dnsmasq` manipuliert, sodass bei einer Anfrage von `leafy.san` nach der Adresse des Pi's aufgelöst wird. Um dies umzusetzen muss die folgende Zeile in die Datei `etc/dnsmasq.conf` eingefügt werden:

``` bash
address=/leafy.san/192.168.2.1
```

Außerdem ist es der NodeJS Anwendung nicht "erlaubt" auf dem HTTP Standart Port 80 zu "lauschen", weshalb man eine "Umleitung" einbauen muss, sodass die Anwendung zwar auf dem Port 8000 (oder einem beliebigen anderen, noch nicht belegten Port) arbeitet, Anfragen von außen auf dem Port 80 auf den Port der NodeJS Anwendung weitergeleitet werden. Um dies zu erreichen kann man das Skript `redirect.sh` als super-user ausführen oder folgende Zeile in die Datei `/etc/rc.local` einfügen:

``` bash
iptables -t nat -A PREROUTING -i wlan0 -p tcp --dport 80 -j REDIRECT --to-port 8000
```

Damit wird automatisch nach erfolgreichem Hochfahren der Befehl ausgeführt und die Umleitung eingerichtet. Zum Bearbeiten der `rc.local` Datei sind gegebenfalls Adminrechte erforderlich.

Wenn alles richtig ausgeführt wurde, kann man das Frontend bequem über das Eingeben der URL `leafy.san` im Web-Browser erreichen.

### 5. Webserver-Optionen

Beim Starten der Server-Applikation können folgende Einstellungen vorgenommen werden:

**--list-serial-ports, -l**
Mit diesem Befehl können alle verfügbaren Serial Ports angezeigt werden. Dies dient dazu den richtigen zum Auslesen des Datenstroms zu finden. Wenn diese Option nicht angegeben wird, erfolgt keine Auflistung der verfügbaren Ports.
``` bash
node server.js --list-serial-ports
# oder
node server.js -l
```

**--serial-port=[port], -s=[port]**
Insofern der richtige serielle Port gefunden wurde, kann mit diesem Befehl der Applikation mitgeteilt werden, dass sie von diesem Port den Datenstrom auslesen soll. Der Standardwert ist `/dev/ttyUSB0`, was in den meisten Fällen der richtige Port sein sollte.
``` bash
node server.js --serial-port="/dev/ttyUSB1"
# oder
node server.js -s="/dev/ttyUSB1"
```

**--write-data, -d**
Die Applikation kann die ausgelesenen Sensorwerte in einer CSV Datei archivieren, damit man später darauf zugreifen kann, um die Entwicklung und den Verlauf der Sensorwerte in einem Diagramm darzustellen. Damit solche Dateien geschrieben werden, muss die `write-data` Option angegeben werden. Wenn diese Option nicht angegeben wird, werden keine Dateien erstellt.
``` bash
node server.js --write-data
# oder
node server.js -d
```

**--http-port=[zahl], -h=[zahl]**
Der HTTP-Server kommuniziert über einen bestimmten Port. Für HTTP-Server ist dieser meistens 80, allerdings wird dieser in den meisten Fällen blockiert, um den Computer zu schützen. Bei dieser Option kann eine beliebige Zahl als Port verwendet werden. Wenn man zum Beispiel den Port 2134 verwenden möchte, nutzt man folgenden Befehl, um den Server zu starten:
``` bash
node server.js --http-port=2134
# oder
node server.js -h=2134
```
Damit kann der Server unter der Addresse `http://localhost:2134` auf dem eigenen Computer erreicht werden. Falls folgende Fehlermeldung auftreten sollte, ist der Port blockiert und man muss einen anderen wählen.
```
events.js:160
      throw er; // Unhandled 'error' event
      ^

Error: listen EACCES 0.0.0.0:80
    at Object.exports._errnoException (util.js:1020:11)
    at exports._exceptionWithHostPort (util.js:1043:20)
    at Server._listen2 (net.js:1245:19)
    at listen (net.js:1294:10)
    at Server.listen (net.js:1390:5)
    at Object.<anonymous> (/home/fju/LeafySan/frontend/server.js:119:8)
    at Module._compile (module.js:570:32)
    at Object.Module._extensions..js (module.js:579:10)
    at Module.load (module.js:487:32)
    at tryModuleLoad (module.js:446:12)
```