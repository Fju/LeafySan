## Entwicklungsprozess

**17.05. Meilenstein 1:** Die erste Aufgabe, die im Zuge des ersten Meilensteins umgesetzt wurde, war das Erstellen der Projektplanung und einer Liste mit den benötigten Sensoren und Aktoren.

**27.05. Bauteilauswahl:** Danach wurde die Tauglichkeit der Komponenten mit dem Betreuer besprochen. Einige dieser Komponenten wurden dann online bestellt.

**03.06. Lieferung der Bauteile:** Zu diesem Zeitpunkt sind bereits fast alle bestellten Bauteile angekommen und es wurde mit der Verschaltung begonnen.

**04.06. Verschaltung:** Damit der Platin-Messwiderstand korrekt verstärkt wird, wurde die Instrumentationsverstärker-Schaltung mit dem Mentor besprochen und auf einem Breadboard reaslisiert, um den Thermistor zu kalibrieren bzw. die Umrechnung des eingelesenen Wertes zu ermitteln. An dieser Stelle entstand das erste Problem, da die Relais auf dem Relaismodul eine Spannung von 5 V benötigten, um zu schalten.

**15.06. Computernetzteil:** Die Lösung des oben angesprochenen Problems war die "Zweckentfremdung" eines alten Computernetzteils. Daraus kann man sowohl 5 V als auch 3,3 V und 12 V abgreifen. Die Versorgung der Relais sowie der zukünftigen Peripherie war ab diesem Punkt kein Problem mehr.

**18.06. Grundplatte:** Als Fundament für Heizplatte, Gewächshaus, Netzteil und Elektronik dient eine mehrschichtige Sperrholzplatte. Auf dieser wurde angefangen, die einzelnen elektronischen Komponenten, wie zum Beispiel das DE2-Board, der Raspberry Pi oder das Relaismodul, anzuordnen und auf Stelzen zu verschrauben. Außerdem wurde die Heizplatte installiert und in Betrieb genommen.

**20.06. Verbindungsplatine:** Da die Messelektronik bisher auf einem Breadboard zusammengesteckt wurde, erfolgte nun die Übertragung der Instrumentationsverstärker-Schaltung auf die Lochrasterplatine und  wurde verlötet. Später wurden auch die Steckplätze für den I²C Bus darauf verbunden und mit Pull-Up Widerständen bestückt.

**22.06. Probleme mit I²C:** Das Auslesen der digitalen Sensoren, die über I²C mit dem DE2-Board kommunizieren sollen, entpuppte sich als schwierige Angelegenheit. Deshalb wurde die Hilfe bezüglich des `i2c_master` Interfaces in Anspruch genommen.

**03.07. Konstruktion:** Das Gewächshausdach wird aus Polystyrolplatten und Metallschienen eigenhändig zusammengebaut. Mithilfe eines Holzgerüstes, welches von einem ortsansässigen Tischlers angefertigt wurde, konnte die Polystyrolplatte in Form gebracht werden. Leider erwies sich das Material als wenig geeignet, da es bei Belastung zur Rissbildung neigte.

**15.07. Neukonstruktion:** Nach Bestellung einer robusteren 2 mm Plexiglasplatte, wurde das "Glasdach" erneut konstruiert.

**18.07. Probleme mit den Sensoren:** Nachdem das DE2-Board während einer aktiven I²C Kommunikation ausgeschalten wurde, neigte der Feuchte-Sensor dazu, seine Adresse zu ändern. Dies erschwerte die Arbeit mit dem Sensor, da die Adresse mit einem Arduino Uno auf den Standardwert zurückgesetzt werden musste. Außerdem schwankten die eingelesenen Kanalwerte des Helligkeitssensors und die Kalkulation des Lux-Wertes gestaltete sich schwierig.

**25.07. Stabile Werte:** Die beiden digitalen Sensoren wurden voneinander getrennt, sodass der Helligkeitssensor auf einem anderen Bus als der Feuchte-Sensor kommunizierten. Des weiteren wurden die Widerstandsgrößen von 10 kOhm auf 4,7 kOhm verkleinert. Diese Maßnahmen führten dazu, dass beide Sensoren endlich stabile und realitätsnahe Werte lieferten. Später stellte sich heraus, dass die Werte des Feuchte-Sensor noch stabiler wurden, wenn man anstelle von 4,7 kOhm nur 1 kOhm Pull-Up Widerstände verwendete.

**02.08. Web Interface:** Aufgrund dessen, dass das Lesen der Sensorwerte endlich funktionierte, widmete man sich dem Erstellen des Web Interfaces und der Darstellung der Werte in einem Diagramm. Außerdem wurde der Raspberry Pi zu einem Access Point konfiguriert, sodass der HTTP-Server über WLAN erreicht werden konnte.

**25.08. Inbetriebnahme:** Freundlicherweise unterstützte mich die Creative Factory GmbH aus Großenhain bei der Konstruktion einer Aluwanne. Als diese fertig war, wurden alle Komponenten miteinander verkabelt. Damit konnte das gesamte System in Betrieb genommen werden.

**27.08. Temperaturmessung:** Da die Werte des Temperatursensors an der Heizung stark schwankten (aufgrund der guten Wärmeleitfähigkeit der Heizplatte), wurde die Temperaturmessung auf den internen Feuchte-Sensor übertragen, der die vorherrschende Temperatur innerhalb des Gewächshauses misst und diesen über I²C an das DE2-Board übertragen kann.

**28.08. Dokumentation:** Es wurde begonnen die Dokumentation über die Funktionsweise, den Aufbau und die Umsetzung des Projektes zu schreiben. Außerdem wurden auch Tests in der Natur durchgeführt, ein Video zur Demonstration der Funktionstüchtigkeit gedreht und zahlreiche Bilder erstellt.

**03.09. Abgabe**
