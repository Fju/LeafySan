## Architektur des FPGA-Chips

Mithilfe der Hardwarebeschreibungssprache VHDL wurde die Architektur des Chips auf dem DE2-Entwicklungsboards beschrieben. Als IDE wurde Altera's Quartus verwendet. Simulationen wurden mit dem Programm ModelSim durchgeführt. Im Ordner `src` findet man die entsprechenden Projektdateien sowie den Quellcode.

Folgendes Blockschaltbild verdeutlicht leicht vereinfacht den Datenaustausch der einzelnen Entities:

![Blockschaltbild](bilder/blockschaltbild.png)

Die zentrale Entity `invent_a_chip` steuert mithilfe der `gp_*` Signale die Peripherie über ein Relaismodul. Die Kommunikation über den Datenbus I²C findet auch über GPIO-Pins mithilfe der `gp_*` Signale statt. Dabei ist zu beachten, dass diese sowohl zum Schreiben als auch zum Lesen verwendet werden müssen, um die Sensoren richtig anzusteuern und auszulesen.



### 1. Auslesen der Sensoren

#### 1.1. Temperatursensor und CO2-Sensor

VHDL-Implementierung: [src/vhdl/modules/adc_sensors.vhdl](../src/vhdl/modules/adc_sensors.vhdl)

Sowohl Temperatur- als auch CO2-Sensor liefern dem DE2-Board einen analogen Wert, das heißt eine Spannung, die von dem Extension Board in einen digitalen Wert umgewandelt werden kann. Außerdem werden alle analog eingelesenen Werte über einen Zeitraum von fünf Sekunden addiert und daraus wird ein Mittelwert gebildet. Dadurch treten keine großen, ungewollten Schwankungen
auf.

**Temperatursensor**

Bei dem Temperatursensor handelt es sich um einen PT1000 Thermistor, welcher bei 0 °C einen Widerstand von 1 kOhm hat. Dieser Thermistor hat einen positiven Temperaturkoeffizienten, was bedeutet, dass bei einer Temperaturerhöhung sich der Widerstand des Messwiderstandes vergrößert. Diese Änderung des Widerstandes ist annähernd linear und kann mithilfe der folgenden Verschaltung ausgelesen werden.

![Schaltplan für das Auslesen des Platin-Messwiderstandes](bilder/schaltplan_adc.png)

Der Platin-Messwiderstand befindet sich in einer [Wheatstone'schen Messbrücke](https://de.wikipedia.org/wiki/Wheatstonesche_Messbr%C3%BCcke). Bei einer Temperatur von 0 °C beträgt die Spannungsdifferenz der Messbrücke 0 V. Insofern eine höhere Temperatur erreicht wird, erhöht sich die Spannungsdifferenz, welche durch den rechten Operationsverstärker aufgrund der Widerstandsanordnung (1 kOhm, 100 kOhm) hundertfach verstärkt wird. Die mittleren Operationsverstärker dienen zur [Impedanzwandlung](https://de.wikipedia.org/wiki/Impedanzwandler). Die Operationsverstärker werden mit einer gepufferten 3,3 V Spannung versorgt (ganz linkes Schaltbild).
Nach der hundertfachen Verstärkung durch einen Operationsverstärker kann die resultierende Spannung durch einen ADC (**A**nalog-to-**D**igital **C**onverter) in einen digitalen Wert umgewandelt werden. Die Auflösung dieses ADC sind 12-bit, das heißt bei Null-Potenzial beträgt der Wert 0, bei einer Eingangsspannung von 3,3 V ist der digitale Wert 4095. Nach einer Messung bei Zimmertemperatur wurde der lineare Zusammenhang zwischen digitalem Wert und Temperaturwert in Celsius ermittelt. Mithilfe dieses Codes wird der eingelesene digitale Wert in die Einheit Temperatur umgewandelt:
```vhdl
heating_temp_nxt <= resize(shift_right(unsigned(temp_value) * 74043 + 131072, 18), heating_temp'length);
-- Beispiel: temp_value = 1200
-- 1200 * 74043 + 131072 = 88982672
-- 88982672 >> 18 = 339 (enspricht der Division mit dem Divisor 2^18 [= 262144])
-- 339 entsprechen 33,9 °C
```

**CO2-Sensor**

Technische Details: [MH-Z14 Datasheet](http://www.futurlec.com/Datasheet/Sensor/MH-Z14.pdf)

Der CO2-Sensor hat einen Messbereich von 0-5000 ppm (**p**arts **p**er **m**illion). Dies entspricht einer Konzentration von 0 bis 0.5 Vol.-% Kohlenstoffdioxid in der Luft. In der Außenluft liegt dieser Wert bei ungefähr 350 ppm, in einem Wohnraum zwischen 1000 und 2000 ppm.
Da der CO2-Sensor eine analoge Spannung zwischen 0.4 V und 2.0 V ausgibt, wird der Wert wie folgt im FPGA umgerechnet:
```vhdl
co2_nxt <= resize(shift_right((unsigned(co2_value) - 496) * 82539, 15), co2'length);
```
Die Konzentration von CO2 in der Luft des Gewächshauses soll Rückschlüsse auf die Photosyntheseleistung der Pflanze ermöglichen, da bei diesem für die Pflanze lebenswichtigen Prozess Kohlenstoffdioxid benötigt wird. Bei einer guten Photosyntheseleistung müsste der Gehalt von CO2 innerhalb des abgeschlossenen Gewächshauses sinken. Damit wieder CO2 in die Luft des Gewächshauses gelangt, wird jede viertel Stunde "belüftet", um das Stattfinden der Photosynthese zu ermöglichen.

#### 1.2. Helligkeitssensor und Feuchte-Sensor

Sowohl der Helligkeitssensor als auch der Feuchte-Sensor kommunizieren über den weit verbreiteten seriellen Bus I²C. Dafür werden nur zwei Kabel (VCC und GND ausgenommen) benötigt, um die beidseitige Kommunikation vom Master (FPGA) zum Slave (Sensor) oder andersherum zu ermöglichen. Beide Sensoren kommunizieren über die Taktfrequenz 400 kHz (fast mode) und werden mit 3,3 V versorgt.
Außerdem muss der Clock- und Daten-Kanal mit einem Pull-Up Widerstand auf 3,3 V "gezogen" werden. Geeignete Widerstandsgrößen sind liegen ungefähr zwischen 2,2 kOhm und 10 kOhm. Folgender Schaltplan veranschaulicht die Verschaltung des Bus:

![Schaltplan für den I²C-Bus mit Pull-Up Widerständen](bilder/schaltplan_i2c.png)

**Helligkeitssensor**

Technische Details: [TSL2561 Datasheet](https://raw.githubusercontent.com/SeeedDocument/Grove-Digital_Light_Sensor/master/res/TSL2561T.pdf).
VHDL-Implementierung: [src/vhdl/modules/light_sensor.vhdl](../src/vhdl/modules/light_sensor.vhdl)


Der Helligkeitssensor besitzt die Slave-Addresse 0x29 und wird jede Sekunde ausgelesen. Damit der Sensor einen Wert zurückgeben kann, muss dieser zuerst "eingeschalten" werden. Daraufhin wird eine Einstellung für das Auslesen geschickt und einen Moment gewartet, bis der Lichtsensor einen sinnvollen Wert an das DE2-Board schicken kann. Insofern alle Werte ausgelesen wurden, wird der Sensor wieder ausgeschaltet, um Strom zu sparen.
Die Tabelle soll den Kommunikationsablauf näher verdeutlichen:

| Register (*Address-Byte*) | Kommando (*Daten-Byte*) | Beschreibung |
|----------|---------|--------------|
| REG_CONTROL (*0x80*)  | POWER_ON (*0x03*)  | aktiviert den Sensor |
|           -           | -                  | warte 400 ms, damit der Sensor booten kann |
| REG_TIMING (*0x81*)   | HIGH_GAIN, INT_101 (*0x11*) | setzt Verstärkung auf 16x und Integrationszeit auf 101ms |
| -                     | -                  | warte 800 ms, damit der Sensor liefern kann (Integrationszeit) |
| REG_CHANNEL0L (*0x8C*) | *kein Kommando-Byte* | Lesen des tiefen Bytes des ersten Kanals  |
| REG_CHANNEL0H (*0x8D*) | *kein Kommando-Byte* | Lesen des hohen Bytes des ersten Kanals   |
| REG_CHANNEL1L (*0x8E*) | *kein Kommando-Byte* | Lesen des tiefen Bytes des zweiten Kanals |
| REG_CHANNEL1H (*0x8F*) | *kein Kommando-Byte* | Lesen des hohen Bytes des zweiten Kanals  |
| -                     | -                  | Lux-Wert aus ausgelesenen Kanalwerten kalkulieren |
| REG_CONTROL (*0x80*)  | POWER_OFF (*0x00*)  | deaktiviert den Sensor |

Die Integrationszeit wird benötigt, damit der Helligkeitssensor aus den analogen Werten der Photowiderstände digitale Werte an das interne ADC-Register sendet, die integer sind. Außerdem müssen die Kanalwerte der unterschiedlich empfindlichen Photowiderstände in einen Lux-Wert umgewandelt werden, der Auskunft über die Helligkeit gibt - unabhängig von der Wellenlänge des Lichts.

![normalisierte Empfindlichkeit der Photowiderstände](bilder/spectral_responsivity.jpg)

Je nach Verhältnis der beiden Werte werden die einzelnen Kanalwerte, die zuvor je nach Integrationszeit mit einem Faktor (bei 101 ms Integrationszeit circa `3,975`) skaliert werden, mit unterschiedlichen Koeffizienten multipliziert.
Um einen kritischen Pfad auszuschließen, wird der Lux-Wert in einer eigenen Entity über fünf Taktzyklen berechnet.

**Feuchte-Sensor**

technische Details: [TSL2561 Datasheet](https://raw.githubusercontent.com/SeeedDocument/Grove-Digital_Light_Sensor/master/res/TSL2561T.pdf).
VHDL-Implementierung: [src/vhdl/modules/moisture_sensor.vhdl](../src/vhdl/modules/moisture_sensor.vhdl)

Der Feuchte-Sensor wird jede Sekunde von dem DE2-Board ausgelesen und gibt einen 16-bit Wert an den Master zurück, der für gewöhnlich zwischen 300 und 700 liegt. Leider gibt es keine vergleichbare Einheit, die eine Aussage über die Bodenfeuchte geben kann, weshalb der Nullpunkt bei dem Wert 370 angenommen wird und der höchste Wert bei 600 liegen soll, was 100 % entsprechen soll. Folgende Wertetabelle zeigt gemessene Referenzwerte:

| Zustand  | Werte (min.) | Werte (max.) |
|----------|---------|--------------|
| in Luft  | 300 | 320 |
| in trockener Erde | 365 | 375 |
| in normaler Erde | 400 | 440 |
| in feuchter Erde | 460 | 480 |
| in Trinkwasser | 590 | 600 |
| in gesättigter Kochsalz-Lösung | 670 | 680 |

Der Ablauf der Kommunikation zwischen Sensor und DE2-Board beginnt mit dem Senden eines Reset-Signales zur Initialisierung. Dieses Signal wird nur beim "ersten Start" oder nach Betätigen des Reset-Knopfes gesendet. Jede folgende Kommunikation besteht nur aus dem Senden des zu lesenden Registers (1 Byte) und das Empfangen des Registerwertes (2 Byte).
Da die Implementierung in der Hardwarebeschreibungssprache VHDL sich an den [vom Hersteller vorgeschlagenem Beispielcode](https://github.com/Miceuz/i2c-moisture-sensor/blob/master/README.md#arduino-example) für einen Arduino orientiert, wird zwischen dem Senden des Registerbytes und dem Empfangen des Wertes 20 ms gewartet siehe:

```c
unsigned int readI2CRegister16bit(int addr, int reg) {
  Wire.beginTransmission(addr);
  Wire.write(reg);
  Wire.endTransmission();
  delay(20);
  Wire.requestFrom(addr, 2);
  unsigned int t = Wire.read() << 8;
  t = t | Wire.read();
  return t;
}
```

### 2. Steuerung der Aktoren

Zum Ansteuern der Aktorik, die eine Spannung von 12 V benötigen, wurde eine Relaismodul mit vier steuerbaren Relais verwendet. Die Relais an sich benötigen eine Spannung von 5 V für den eingebauten Elektromagneten. Damit dies sich dennoch mit der Betriebsspannung des DE2-Boards 3,3 V verträgt, ist auf dem Modul der Relaisschaltkreis mit einem Optokoppler vom Steuerschaltkreis getrennt. Hier der Schaltplan:

![Schaltkreis der Relaiskarte](bilder/schaltplan_relais.png)

Der Schaltplan wurde aus den Angaben des Herstellers erstellt und enthält deshalb keine Widerstandsgrößen, weil keine Angaben in den dazugehörigen Datenblättern gefunden werden konnten. Damit der Elektromagnet im Relais anzieht, muss logisch '0' ausgegeben werden, bei logisch '1' öffnet das Relais. Die Steuerung ist somit invertiert.

VHDL-Implementierung: [src/vhdl/modules/peripherals.vhdl](../src/vhdl/modules/peripherals.vhdl)

#### 2.1. Beleuchtung

Die Beleuchtung umfasst zwei LED-Streifen mit einer Gesamtleistung von 2,25 W, wovon ein Streifen ausschließlich rotes und der andere nur blaues Licht aussendet. Es wurde auf weißes Licht verzichtet, da das in den Pflanzen befindliche Chlorophyll Licht aus dem roten und blauen Wellenlängenbereich benötigt (circa 680 nm und 450 nm).

Insofern der Helligkeitswert unter 400 lx fällt, wird die künstliche Beleuchtung eingeschalten, um ein gutes Pflanzenwachstum zu garantieren. Damit nicht jede Sekunde das Licht ein- und ausgeschalten wird, muss im eingeschaltenen Zustand, das heißt es wird gerade beleuchtet, der Helligkeitswert innerhalb eines fünf Sekunden langen Zyklus stets über dem Schwellwert von 400 lx sein, damit die Beleuchtung ausgeschaltet wird. Insofern die Beleuchtung sich im ausgeschaltenem Zustand befindet, muss der Helligkeitswert innerhalb eines fünf Sekunden langen Zyklus stets unter dem Schwellwert sein, damit die Beleuchtung angeschalten wird.
Das Zustandsdiagramm verdeutlicht den beschriebenen Ablauf:
![Zustandsdiagramm zur Steuerung der Beleuchtung](diagramme/zustandsdiagramm_beleuchtung.png)

Bei leicht bewölktem Himmel zur Mittagszeit wurde beispielsweise eine Helligkeit von 2100 ~ 2200 lx gemessen. In einem Wohnraum am Tag ohne Zimmerbeleuchtung von 100 ~ 200 lx.
Die Webseite [Zimmerpflanzenlexikon](http://www.zimmerpflanzenlexikon.info/artikel/lichtbedarf-von-pflanzen/) schreibt dazu:

> Pflanzen lassen sich in grob drei Kategorien unterteilen:
> Pflanzen mit hohem Lichtbedarf über 1.000 bis 1.500 Lux, Pflanzen mit mittlerem Lichtbedarf von 800 bis 1.000 Lux und Pflanzen mit geringem Lichtbedarf über 500 Lux. Unter 500 Lux findet keine Photosynthese mehr statt.

#### 2.2. Bewässerung

Bei der Steuerung der Bewässerung musste beachtet werden, dass sich das Wasser im Boden erst "verteilen" muss, bevor der Feuchte-Sensor einen aussagekräftigen Wert liefern kann. Deshalb wartet die FSM zur Steuerung der Bewässerungspumpe eine Minute, bevor der Messwert des Feuchte-Sensors berücksichtigt wird. Insofern dieser dann geringer als der gewünschte Schwellwert minus zehn ist, so wird die Bewässerung für maximal drei Minuten angeschalten. Falls während dieser drei Minuten der Bewässerung der Schwellwert überschritten wird, wechselt die FSM sofort in den ausgeschaltenen Zustand `S_WATERING_DELAY`.

![Zustandsdiagramm zur Steuerung der Bewässerung](diagramme/zustandsdiagramm_bewässerung.png)

#### 2.3. Belüftung

Die Belüftung besteht aus einem Elektromagneten, der ein Fenster öffnet und schließt, und einem kleinen Axial-Lüfter, der den Gasaustausch mit der Außenluft begünstigen soll. Beide Komponenten werden mit einem Relais gesteuert. Da dieser Mechanismus von keiner gemessenen Größe beeinflusst wird, basiert es auf einem zeitlich festgelegten Schließ-/Öffnungsablauf. Das heißt, dass die Belüftung immer aller 15 Minuten für 5 Minuten aktiv ist. Das Zustandsdiagramm ist demnach auch recht simpel:

![Zustandsdiagramm zur Steuerung der Belüftung](diagramme/zustandsdiagramm_belüftung.png)

#### 2.4 Heizung

Zwischen den beiden an der Heizplatte liegenden Heizfolien befindet sich der Temperatursensor. Dieser misst die aktuelle Temperatur der Heizplatte. Insofern die gemessene Temperatur mindestens um ein ganzes Grad Celsius niedriger ist als die gewünschte Temperatur, so ändert sich der Zustand der für die Steuerung der Heizung verantwortliche FSM zu `S_HEATING_ON` und es wird geheizt. Der Heizvorgang dauert solange, bis eine Temperatur von mindestens einem Grad Celsius über dem angestrebten Wert erreicht wird oder bereits drei Minuten ununterbrochen geheizt wurde. Dieser "Timeout" nach drei Minuten soll verhindern, dass permanent geheizt wird. Danach wechselt die FSM in den Zustand `S_HEATING_DELAY`, sodass fünf Sekunden gewartet wird, bis wieder der Zustand `S_HEATING_OFF` erreicht wird.

![Zustandsdiagramm zur Steuerung der Heizung](diagramme/zustandsdiagramm_heizung.png)

#### 2.5. Stromverbrauch

| Aktorik  | Stromstärke |
|----------|-------------|
| Lüfter und Elektromagnet | - |
| Heizfolien | 2 A |
| Pumpe | 700 mA |
| Beleuchtung | 188 mA |


Da die Pumpe zwar bei 12 V betrieben werden kann, jedoch manchmal nicht anläuft, wurde mithilfe dieses [Step-Up Converter](https://www.amazon.de/Spannung-10-32v-Converter-Step-Up-Adjustable/dp/B00HV43UOG/ref=pd_sbs_23_2?_encoding=UTF8&psc=1&refRID=S9RD24657F1FBKV7JMSC) auf 24 V erhöht. Damit gibt es keine Schwierigkeiten beim Anlaufen der Pumpe und eine zuverlässige Bewässerung ist garantiert.

### 3. Resourcennutzung

