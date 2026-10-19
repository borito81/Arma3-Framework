# Arbeitsregeln für das Persistenzframework

Diese Datei hält stabile Regeln für Änderungen am Arma-3-SQF-Persistenzframework fest. Sie ist keine vollständige technische Dokumentation. Prüfe für konkrete Abläufe und Datenfelder den aktuellen Code sowie [`READ_THE_FUCKING_MANUAL.md`](READ_THE_FUCKING_MANUAL.md); der Code ist maßgeblich für den Implementierungsstand.

## Architektur und Änderungen

- Behalte die bestehende Modulstruktur, `CfgFunctions`-Registrierung in `description.ext` und die Einstiegs- und Initialisierungsabläufe bei.
- Prüfe vor einer Änderung die betroffenen Funktionen, ihre Aufrufer, Remote-Exec-Freigaben und Abhängigkeiten. Änderungen an zusammenhängenden Funktionen und Konfigurationen sind gemeinsam zu betrachten.
- Bewahre die Zuständigkeit von Server und lokalen Clients sowie die vorhandene Reihenfolge von Registrierung, Wiederherstellung und Freigabe. Wenn eine dafür wichtige Architekturentscheidung aus Code und Handbuch nicht eindeutig hervorgeht, frage nach, bevor du sie festlegst.
- Bevorzuge robuste, allgemeingültige und wartbare SQF-Lösungen. Führe keine unnötig fest codierten Werte oder unbelegten Annahmen ein.

## Identitäten und getrennte Systeme

- Gruppenidentitäten müssen die Seite berücksichtigen: Arma kann Gruppennamen auf verschiedenen Seiten wiederverwenden. Ältere Fraktionspräfixe für Gruppen dürfen nicht als allgemeine Voraussetzung für deren Registrierung angenommen werden.
- Normale Weltfahrzeuge und Spielerfahrzeuge sind getrennte Persistenzsysteme. Führe ihre Registrierung, Speicherbereiche oder Wiederherstellung nicht unbeabsichtigt zusammen.
- Erhalte bestehende Editor-Namenskonventionen: `player_` für persistente Spielerrollen, `pveh_` für Spielerfahrzeuge, `trg_persist_` für persistente Trigger und `mrk_persist_` für persistente Marker. Ändere Präfixe oder deren Bedeutung nur nach Prüfung aller abhängigen Funktionen und gespeicherten Daten.
- Achte bei Variablennamen auf die im Code und Handbuch beschriebene mögliche Abweichung zwischen `allVariables` und `vehicleVarName`. Registrierung und spätere Zugriffe müssen dieselbe Namensquelle und konsistente Schlüssel verwenden.

## Persistenzdaten

- Behandle `TAG_SaveData` und seine Schlüssel als gemeinsam verwendetes Speicherformat. Prüfe bei Änderungen alle betroffenen Lese-, Schreib- und Wiederherstellungsfunktionen sowie die Default-Struktur.
- Erfinde keine Migrationen und ändere das Speicherformat nicht ohne Prüfung der Auswirkungen auf bestehende Spielstände. Falls eine Migrationsentscheidung erforderlich ist, kläre sie zuerst.
- Die Erweiterung der zentralen SaveData-HashMap um missionsspezifische Daten ist ein vorgemerktes zukünftiges Feature, keine fertige API. Reserviere oder erfinde dafür keine Schlüssel oder Schnittstellen.
- Einzelne Systeme können eigene Registrierung, Aktualisierung und Speicherung haben. Ändere ihren Umfang oder ihre Zuständigkeit nicht aufgrund bloßer Ähnlichkeit mit einem anderen Modul.

## Diagnose und Verifikation

- Verwende für schaltbare Debug-Ausgaben `TAG_fnc_debugLog` und die vorhandenen Debug-Schalter. Entferne oder unterdrücke wichtige Fehler- und Warnmeldungen nicht stillschweigend.
- Beschreibe Verifikation präzise: Statische Codeprüfung ist keine Ausführung; eine Skriptausführung ist kein In-Game-Test. Behaupte nicht, Code sei getestet worden, wenn lediglich eine statische Analyse erfolgt ist.
- Prüfe vor einer Änderung, welche Verifikationsmöglichkeiten im Repository tatsächlich vorhanden sind. Erfinde keine Testinfrastruktur oder Projektregeln, wenn sie nicht belegt sind.

## Technische Quellen und Belege

Wähle technische Dokumentation passend zur Frage:

- Für Verhalten der Arma-3-Engine, SQF-Befehle und Syntax, Event-Handler, Multiplayer-Verhalten und Initialisierungsreihenfolgen ist die offizielle [Bohemia Interactive Community Wiki](https://community.bistudio.com/wiki/) die bevorzugte Quelle.
- Für ACE3-Funktionen, ACE-spezifisches Verhalten und öffentliche Schnittstellen ist die offizielle [ACE3-Dokumentation](https://ace3.acemod.org/wiki/) die bevorzugte Quelle.
- Für CBA_A3-Funktionen, Extended Event Handlers, CBA-Events, Makros und andere CBA-Schnittstellen sind das [CBA_A3 Wiki](https://github.com/CBATeam/CBA_A3/wiki) und die [CBA_A3 Funktionsdokumentation](https://cbateam.github.io/CBA_A3/docs/files/overview-txt.html) die bevorzugten Quellen.

Bei der Verwendung technischer Dokumentation gelten diese Regeln:

- Nutze die Quelle, die zur konkreten technischen Frage passt. Öffne bei Bedarf die konkrete Seite zur verwendeten Funktion oder zum Befehl; stütze dich nicht allein auf eine Startseite oder Suchergebnis-Auszüge.
- Berücksichtige mögliche Unterschiede zwischen der dokumentierten und der im Projekt verwendeten Version. Behaupte nicht, dass ein beschriebenes Verhalten für die Projektversion gilt, wenn das nicht ausreichend belegt ist.
- Dokumentation belegt technisches Verhalten, aber nicht die korrekte Verwendung durch dieses Framework. Prüfe dafür weiterhin den tatsächlichen Projektcode einschließlich Aufrufern, Registrierungen, Konfigurationen und Ausführungsumgebung.
- Wenn Projektcode und Dokumentation scheinbar widersprechen, untersuche den Unterschied und benenne ihn ausdrücklich. Rate nicht, welche Erklärung zutrifft.
- Foren, Reddit, fremde Projekte und andere Community-Beiträge sind nur ergänzende Quellen, falls die bevorzugte Dokumentation die Frage nicht ausreichend beantwortet. Kennzeichne solche Hinweise als nicht offiziell und übertrage sie nicht ungeprüft auf das Framework.
- Ist eine relevante Dokumentationsseite nicht erreichbar oder enthält sie keine eindeutige Aussage, sage das ausdrücklich, statt Inhalte zu erfinden.
- Trenne nachvollziehbar belegte Feststellungen von Schlussfolgerungen und offenen Fragen. Behaupte keine Ausführung oder Tests, die nicht tatsächlich stattgefunden haben.

## Umfang und offene Entscheidungen

- Ändere keine bestehenden Funktionen, Dateien oder Speicherstrukturen allein zur Verbesserung der Dokumentation. Bei einer reinen Dokumentationsaufgabe bearbeite nur die dafür angeforderten Dokumentationsdateien.
- Dokumentation kann Implementierungsdetails beschreiben, ersetzt aber nicht die Prüfung des aktuellen Codes. Kennzeichne Widersprüche und nicht belegte Punkte, statt eine fehlende Entscheidung selbst zu erfinden.
- Frage nach, wenn eine wichtige Architektur- oder Kompatibilitätsentscheidung aus dem Bestand nicht eindeutig hervorgeht. Diese Datei legt insbesondere keine allgemeine SaveData-Migrationsstrategie und keine API für missionsspezifische SaveData-Erweiterungen fest.
