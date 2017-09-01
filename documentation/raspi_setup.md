## Den Raspberry Pi als Access Point einrichten

Die folgenden Schritte wurden auf dem Raspberry Pi 3 mit dem Betriebssystem Raspbian "Jessie" getestet. Bei anderer Verwendung von Hard- und Software kann es sein, dass die Einrichtung nicht vollkommen gelingt.

### 1. Installation
Damit der Raspberry Pi als Access Point die Webseite mithile des NodeJS Frameworks darstellen kann müssen die Pakete `dnsmasq` und `hostapd` installiert sein.
Falls diese noch nicht vorhanden sind, können diese mit dem folgenden Befehl heruntergeladen werden:
```
sudo apt-get install dnsmasq hostap
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

### 2. Konfiguration



### 3. Webserver starten

Damit der Webserver gestartet werden kann, muss zunächst der Programmcode des Backends heruntergeladen werden. Dafür klonen Sie zuerst dieses Github-Repository auf ihrem Raspberry Pi und navigieren in das Verzeichnis des Quellcodes des Frontends mit den Befehlen:
```
git clone https://github.com/Fju/LeafySan/
cd LeafySan/frontend
```
Mithilfe des NodeJS Frameworks wird es uns ermöglicht, einen einfachen HTTP-Server auf dem Raspberry Pi aufzusetzen, den man über WLAN erreichen kann. Bevor allerdings der Server gestartet werden kann, müssen noch die "Node-Module" `ws`, `command-line-args` und `serialport` heruntergeladen werden. Dies erfolgt automatisch durch das Ausführen des Befehls
```
npm install
```
Die Module werden allerdings nur automatisch installiert, wenn sie sich im Verzeichnis `frontend/` befinden.

Schließlich kann der Server mithilfe des Befehls
```
node server.js
```
gestartet werden. Falls sie mit dem Raspberry Pi über WLAN verbunden sind, sollten Sie nun eine Webseite unter `http://192.168.2.1:8000` erreichen können.

### 4. Webserver-Optionen
Falls Sie Einstellungen an der Server Applikation vornehmen wollen, finden Sie hier eine vollständige Liste der Optionen.