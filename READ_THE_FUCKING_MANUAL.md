# Arma 3 Persistenzframework – README für Missionsbauer

**Projekt:** Stratis_Persistenz  
**Zielgruppe:** Missionsbauer, Missionsentwickler und Framework-Entwickler  
**Status:** Dokumentation des aktuellen Entwicklungsstands

## 1. Zweck und Grundprinzipien

Das Arma-3-Persistenzframework ermöglicht es, ausgewählte Zustände einer Mission über Missionsneustarts hinweg zu speichern und wiederherzustellen. Es ist als wiederverwendbares Framework aufgebaut, das in Missionsverzeichnisse integriert werden kann.

Die zentralen Aufgaben sind die Speicherung und Wiederherstellung von Spielerzuständen, Gruppen, Fahrzeugen, Missionsfortschritt und weiteren ausdrücklich unterstützten Spielzuständen.

### 1.1 Server und Clients

Die Persistenz ist grundsätzlich serverseitig organisiert. Der Server verwaltet den gemeinsamen Kampagnenspielstand, registriert persistente Objekte, lädt gespeicherte Zustände und führt die zentralen Speicher- und Wiederherstellungsfunktionen aus.

Spielerbezogene Abläufe werden zusätzlich lokal auf den Clients ausgeführt. Dazu gehören beispielsweise die Anforderung der eigenen Zustandswiederherstellung sowie die Verarbeitung bestimmter Diary- und Task-Funktionen.

Die Kommunikation zwischen Server und Clients erfolgt bei dafür vorgesehenen Funktionen über `remoteExec` beziehungsweise `remoteExecCall`. Welche Funktionen auf welchen Maschinen ausgeführt werden dürfen, wird durch die bestehende `CfgRemoteExec`-Konfiguration festgelegt.

### 1.2 Einbindung und Aktivierung

Das Framework besitzt keinen globalen Ein-/Ausschalter. Eine Mission verwendet das Framework, indem sie dessen benötigte Dateien, Funktionsregistrierungen und Initialisierungsaufrufe integriert.

Missionsspezifische Einstellungen und Skripte können in den dafür vorgesehenen Bereichen der Initialisierungsdateien ergänzt werden. Die ausdrücklich als Framework-Bestandteile gekennzeichneten Aufrufe und Konfigurationen müssen dabei erhalten bleiben.

Missionen, die das Framework nicht benötigen, müssen seine Struktur nicht einbinden.

### 1.3 Speicherung des Spielstands

Der zentrale Laufzeitspeicher ist die Missionsvariable `TAG_SaveData`. Sie enthält die verschiedenen gespeicherten Datenbereiche des Frameworks.

Die Funktion `TAG_fnc_loadCampaign` lädt den vorhandenen Spielstand. Die Funktion `TAG_fnc_saveCampaign` schreibt den aktuellen Datenbestand in den `missionProfileNamespace` und ruft `saveMissionProfileNamespace` auf.

Damit ist der Spielstand an das jeweilige Missionsprofil gebunden. Eine Speicherung im Profil ersetzt keine separate Sicherung der Missionsdateien oder des Profils.

## 2. Integration in eine Mission

Das Framework wird über die üblichen Missionsdateien von Arma 3 eingebunden. Die zentrale Integration besteht aus den beiden Initialisierungsdateien und der Konfiguration in `description.ext`.

### 2.1 `initServer.sqf`

`initServer.sqf` enthält den serverseitigen Einstiegspunkt für das Framework.

Der Aufruf

`[] call TAG_fnc_initializeServerPersistence;`

startet die zentrale serverseitige Initialisierung. Das Skript beendet sich zuvor auf Maschinen, die nicht der Server sind.

Missionsspezifische serverseitige Einstellungen und Skripte können im dafür vorgesehenen Bereich ergänzt werden. Dabei müssen Abhängigkeiten zur Reihenfolge der Framework-Initialisierung berücksichtigt werden.

### 2.2 `initPlayerLocal.sqf`

`initPlayerLocal.sqf` enthält den lokalen Einstiegspunkt für die Spielerinitialisierung.

Die Funktion erhält die Parameter `_player` und `_didJIP` und ruft anschließend

`[_player, _didJIP] call TAG_fnc_initializePlayerPersistence;`

auf.

Die lokale Initialisierung wartet unter anderem auf die benötigte Debug-Konfiguration und auf das Signal `TAG_PersistenceReady`. Erst nachdem der Server seine Initialisierung abgeschlossen hat und die lokale Spielereinheit verfügbar ist, wird die Anforderung zur Wiederherstellung des Spielerzustands ausgelöst.

Die Spielerrolle wird anhand des Editor-Variablennamens erkannt. Für die vorgesehene persistente Rollenverwaltung muss dieser mit `player_` beginnen.

Zusätzlich startet die lokale Initialisierung die vorgesehenen Task-Tracking- und Task-Wiederherstellungsabläufe, stößt zeitversetzt die Diary-Wiederherstellung an und registriert den Respawn-Handler für die Ticket-Speicherung.

### 2.3 `description.ext`

Die `description.ext` enthält sowohl missionsspezifische Einstellungen als auch die für das Framework erforderliche Funktionsregistrierung und Remote-Exec-Freigaben.

Missionsspezifische Einstellungen wie Respawn-Modus, Respawn-Templates und Respawn-Verzögerung bleiben Bestandteil der jeweiligen Mission. Das Framework benötigt dafür keine zweite, separate `description.ext`.

**CfgFunctions**

`CfgFunctions` registriert die SQF-Funktionen des Frameworks. Die Unterkategorien verweisen über ihre `file`-Einträge auf die entsprechenden Unterverzeichnisse. Die einzelnen Funktionsklassen werden anhand der tatsächlichen Dateistruktur und Dateinamen zugeordnet.

Neue Framework-Funktionen müssen in der passenden Kategorie registriert werden. Missionsspezifische Funktionen können in einer eigenen Kategorie ergänzt werden, sofern die Struktur entsprechend eingerichtet wird.

**CfgRemoteExec**

`CfgRemoteExec` begrenzt die Funktionen und Befehle, die über Remote-Aufrufe ausgeführt werden dürfen.

Die aktuelle Konfiguration verwendet `mode = 1`. Damit sind nur ausdrücklich freigegebene Funktionen beziehungsweise Befehle zugelassen. `allowedTargets` beschränkt die vorgesehenen Zielmaschinen; `jip = 0` aktiviert keine allgemeine JIP-Wiederholung der Remote-Aufrufe.

Neue Remote-Aufrufe müssen in die vorhandene Konfiguration integriert werden. `CfgFunctions` und `CfgRemoteExec` dürfen nicht unkoordiniert mehrfach als separate Klassen definiert werden.

## 3. Serverinitialisierung und Ablauf

Die Funktion `TAG_fnc_initializeServerPersistence` zentralisiert die serverseitige Initialisierung. Sie führt die notwendigen Schritte in einer festgelegten Reihenfolge aus, bevor sie den Clients die Bereitschaft des Frameworks signalisiert.

### 3.1 Grundeinstellungen

Zu Beginn wird `TAG_PersistenceReady` auf `false` gesetzt. Damit wird signalisiert, dass die serverseitige Initialisierung noch läuft.

Die aktuelle Implementierung legt folgende Einstellungen fest:

| Variable | Aktueller Wert | Bedeutung |
|---|---:|---|
| `TAG_AutoSaveInterval` | 300 Sekunden | Intervall für automatische Speicherungen |
| `TAG_VehicleStateInterval` | 60 Sekunden | Intervall für die laufende Erfassung von Fahrzeugzuständen |
| `TAG_SaveLoadoutOnDeath` | `true` | Spieler-Loadout beim Tod speichern |
| `TAG_RestoreLoadoutOnRespawn` | `true` | Gespeichertes Loadout beim Respawn wiederherstellen |

Die Loadout-Einstellungen werden über `publicVariable` veröffentlicht. `TAG_fnc_configurePersistence` setzt und veröffentlicht anschließend die beiden Speicherintervalle sowie die Diary-Präfixe.

### 3.2 Kampagnendaten und Tickets

Danach lädt `TAG_fnc_loadCampaign` den vorhandenen Spielstand.

Gespeicherte Respawn-Tickets werden aus `TAG_SaveData` unter dem Schlüssel `RespawnTickets` gelesen und an `TAG_fnc_restoreRespawnTickets` übergeben.

Fehlende oder ungültige Ticketwerte können Warnungen auslösen. Die erforderlichen Ticket-Einstellungen hängen auch von der missionsseitigen Respawn-Konfiguration ab.

### 3.3 Task-System

Die Task-Initialisierung erfolgt über die Funktionen `TAG_fnc_registerTaskDefinitions` und `TAG_fnc_syncTaskRegistry`.

Damit werden die Task-Definitionen registriert und mit dem gespeicherten Task-Register abgeglichen. Die Initialisierung protokolliert anschließend die Anzahl der veröffentlichten Task-Definitionen und Task-Zustände.

### 3.4 Registrieren und Wiederherstellen der Weltzustände

Nach der Einrichtung des Task-Systems werden die persistenten Objekte und Trigger registriert. Anschließend werden die gespeicherten Weltzustände in der vorgesehenen Reihenfolge angewendet.

Der aktuelle Ablauf umfasst:

1. Persistente Trigger registrieren.
2. Spielerrollen und Spielerfahrzeuge registrieren.
3. Gruppen und normale Weltfahrzeuge registrieren.
4. Zerstörte Gruppen berücksichtigen.
5. Dynamische Gruppen wiederherstellen.
6. Fehlende dynamische Fahrzeuge erzeugen und registrieren.
7. Zerstörte Fahrzeuge anwenden
8. Gespeicherte Besatzungszuordnungen dynamischer Fahrzeuge wiederherstellen.
9. Gespeicherte Zustände intakter Fahrzeuge anwenden.
10. Spielerfahrzeuge und Kartenmarker wiederherstellen.

Die Reihenfolge ist relevant, da spätere Schritte bereits vorhandene Laufzeitobjekte und registrierte IDs voraussetzen können.

Bei Tests der Gruppenpersistenz ist ausdrücklich darauf zu achten, dass die Gruppen durch die Vernichtung als besiegt gekennzeichnet werden. Der Test von Triggern oder ähnlichem durch Löschen der Gruppen per Zeus ist keine gültige Maßnahme die Gruppen als besiegt zu markieren. Die Gruppen werden nach dem Neustart der Mission wiederhergestellt!

### 3.5 Laufende Überwachung und Freigabe

Nach der Wiederherstellung werden die ereignisbasierte Überwachung zerstörter Gruppen und Fahrzeuge sowie die laufende Fahrzeugzustandserfassung gestartet. Außerdem wird die automatische Speicherung über `TAG_fnc_autoSave` gestartet.

Erst am Ende setzt der Server `TAG_PersistenceReady` auf `true` und veröffentlicht diesen Wert. Die lokale Spielerinitialisierung kann darauf warten, bevor sie die Wiederherstellung eines Spielerzustands anfordert.

## 4. Abgrenzung missionsspezifischer Einstellungen

Das Framework ist nicht dafür vorgesehen, sämtliche Missionslogik zu übernehmen. Missionsbauer können die vorgesehenen Bereiche verwenden, um beispielsweise eigene serverseitige Logik, lokale Spielereinstellungen, Respawn-Konfigurationen oder weitere missionsspezifische Parameter zu ergänzen.

Die Framework-Aufrufe, ihre Funktionsregistrierungen sowie benötigte Remote-Exec-Freigaben müssen dabei erhalten bleiben. Änderungen an der Initialisierungsreihenfolge sollten nur vorgenommen werden, wenn die Abhängigkeiten der betroffenen Funktionen berücksichtigt werden.

## 4. Kampagnendaten und Speicherstruktur

Das Framework verwaltet den persistenten Spielstand zentral über die Missionsvariable `TAG_SaveData`. Die Datenstruktur ist eine HashMap, deren Schlüssel verschiedene Bereiche des Missionszustands repräsentieren.

########################################################################################################################################
Das Erweitern der vorhandenen Hashmap erfolgt auf eigene Gefahr, ist aber grundsätzlich möglich.
########################################################################################################################################

### 4.1 Standard-Spielstand

Die Funktion `TAG_fnc_createDefaultSaveData` erstellt die Ausgangsstruktur, wenn im `missionProfileNamespace` noch kein Eintrag mit dem Namen `TAG_SaveData` existiert.

Der Standard-Spielstand enthält derzeit folgende Einträge:

| Schlüssel | Datentyp | Zweck |
|---|---|---|
| `SaveVersion` | Zahl | Kennzeichnung der Datenversion; aktuell `1` |
| `CampaignInitialized` | Boolean | Kennzeichnet den initialen Kampagnenzustand |
| `DestroyedGroups` | Array | Kennungen zerstörter Gruppen |
| `DestroyedVehicles` | Array | Kennungen zerstörter Weltfahrzeuge |
| `DynamicGroups` | HashMap | Gespeicherte Zustände dynamischer Gruppen |
| `Vehicles` | HashMap | Gespeicherte Zustände normaler Weltfahrzeuge |
| `POIs` | HashMap | Datenbereich für Points of Interest |
| `CompletedEvents` | Array | Datenbereich für abgeschlossene Ereignisse |
| `TriggerStates` | HashMap | Datenbereich für persistente Triggerzustände |
| `Tasks` | HashMap | Datenbereich für Aufgaben |
| `TaskDefinitions` | HashMap | Datenbereich für Task-Definitionen |
| `MarkerStates` | HashMap | Gespeicherte Markerzustände |
| `DiaryEntries` | HashMap | Gespeicherte Diary-Einträge |
| `Players` | HashMap | Gespeicherte Spielerzustände |
| `RespawnTickets` | HashMap | Gespeicherte Respawn-Ticketstände |

Die einzelnen Systeme verwenden die für sie vorgesehenen Datenbereiche. Neue persistente Systeme müssen ihre Speicherstruktur mit der zentralen Kampagnenverwaltung abstimmen.

### 4.2 Laden des Spielstands

Die Funktion `TAG_fnc_loadCampaign` liest den Eintrag `TAG_SaveData` aus dem `missionProfileNamespace`.

Existiert dieser Eintrag nicht, wird die zuvor erzeugte Standardstruktur als Ausgangswert verwendet. Der geladene Spielstand wird anschließend der globalen Missionsvariable `TAG_SaveData` zugewiesen.

Die Funktion protokolliert unter anderem die gespeicherte Datenversion, vorhandene Ticketdaten und die registrierten Kennungen dynamischer Gruppen.

Ein vorhandener Spielstand wird dabei nicht automatisch mit sämtlichen fehlenden Schlüsseln der aktuellen Standardstruktur ergänzt. Die einzelnen Funktionen müssen fehlende Einträge deshalb gegebenenfalls selbst über Standardwerte abfangen.

### 4.3 Speichern des Spielstands

Die Funktion `TAG_fnc_saveCampaign` schreibt die aktuelle HashMap `TAG_SaveData` in den `missionProfileNamespace`. Anschließend ruft sie `saveMissionProfileNamespace` auf, damit die Änderungen dauerhaft im Missionsprofil gespeichert werden.

Existiert `TAG_SaveData` nicht, wird der Speichervorgang mit einer Fehlermeldung abgebrochen.

Die zentrale Speicherfunktion bildet den gemeinsamen Abschluss der unterschiedlichen Persistenzsysteme. Einzelne Speicherfunktionen können sie zusätzlich selbst aufrufen, wenn sie Änderungen unmittelbar sichern müssen.

### 4.4 Datenversion und Kompatibilität

Die Standardstruktur enthält derzeit `SaveVersion = 1`.

Das Framework implementiert keine allgemeine Migration älterer Spielstände auf ein neues Datenformat. Bei Änderungen an der Struktur müssen die betroffenen Speicher- und Wiederherstellungsfunktionen deshalb gemeinsam angepasst werden.

Für die Weiterentwicklung gilt: Neue Schlüssel müssen zum jeweiligen System passen, und Änderungen an bestehenden Schlüsseln dürfen nicht unabhängig von den zugehörigen Lese- und Schreibfunktionen vorgenommen werden.

## 5. Autosave und laufende Speicherung

Die Funktion `TAG_fnc_autoSave` organisiert die regelmäßige automatische Speicherung der unterstützten Kampagnenzustände. Sie wird ausschließlich auf dem Server ausgeführt.

### 5.1 Speicherintervall

Das Intervall wird aus der Missionsvariable `TAG_AutoSaveInterval` gelesen. Ist diese Variable nicht gesetzt, verwendet die Funktion einen Standardwert von 300 Sekunden.

Werte unter einer Sekunde werden abgelehnt; in diesem Fall bricht der Autosave mit einer Fehlermeldung ab.

Bei der regulären Initialisierung setzt `TAG_fnc_configurePersistence` `TAG_AutoSaveInterval` auf 300 Sekunden und veröffentlicht den Wert an die Clients.

Der erste reguläre Autosave-Zyklus beginnt nach Ablauf des Intervalls, da die Funktion vor der Ausführung des ersten Speicherzyklus wartet.

### 5.2 Ablauf eines Autosave-Zyklus

Der aktuelle Autosave ruft die Speicherfunktionen in folgender Reihenfolge auf:

1. `TAG_fnc_savePlayers` – aktuelle Zustände besetzter Spielerrollen speichern.
2. `TAG_fnc_savePlayerVehicles` – Zustände persistenter Spielerfahrzeuge speichern.
3. `TAG_fnc_saveDynamicGroups` – Zustände dynamischer Gruppen einschließlich ihrer Einheiten und Wegpunkte speichern.
4. `TAG_fnc_saveRespawnTickets` – Respawn-Ticketstände erfassen.
5. `TAG_fnc_saveMarkerStates` – persistente Markerzustände speichern.
6. `TAG_fnc_saveDiaryEntries` – Diary-Einträge asynchron erfassen und speichern.
7. `TAG_fnc_saveCampaign` – den zentralen Kampagnenspielstand abschließend sichern.

Der Diary-Speichervorgang wird mit `spawn` gestartet und läuft deshalb unabhängig vom restlichen Autosave-Zyklus. Die Diary-Funktion führt nach ihrer eigenen Verarbeitung ebenfalls eine Kampagnenspeicherung aus.

### 5.3 Laufende Fahrzeugzustandserfassung

Die Initialisierung startet zusätzlich `TAG_fnc_trackVehicleStates`. Diese Funktion läuft unabhängig vom regulären Autosave und verwendet das Intervall `TAG_VehicleStateInterval`.

Bei der aktuellen Konfiguration beträgt dieses Intervall 60 Sekunden. Damit können Fahrzeugzustände zwischen zwei regulären Autosave-Zyklen aktualisiert werden.

Der Tracker ruft `TAG_fnc_saveVehicleStates` sofort beim Start und danach alle 60 Sekunden auf. Diese Funktion aktualisiert die Fahrzeugdaten und speichert selbst den Kampagnenspielstand. Der Autosave-Zyklus erfasst normale Weltfahrzeuge nicht erneut.

## 6. Gruppenpersistenz

Die Gruppenpersistenz verwaltet registrierte KI-Gruppen, speichert die Zustände dynamischer Gruppen und verhindert, dass bereits vollständig vernichtete Gruppen nach einem Missionsneustart erneut erscheinen.

Die Gruppenverwaltung verwendet zwei zentrale HashMaps:

| Variable | Aufgabe |
|---|---|
| `TAG_PersistentGroups` | Enthält registrierte Gruppen, die für die Persistenz und insbesondere die Zerstörungserkennung berücksichtigt werden |
| `TAG_DynamicGroups` | Enthält dynamische Gruppen, deren vollständiger Gruppen- und Einheitenzustand durch die Gruppenpersistenz gespeichert wird |

Die Kennung einer Gruppe wird aus ihrer Seite und ihrer Gruppenbezeichnung gebildet:

`<SIDE>_<CALLSIGN>`

Ein Beispiel aus der Entwicklung ist `WEST_Alpha 1-4`. Die Kennung wird intern verwendet, um den Gruppenstatus über Missionsneustarts hinweg zuzuordnen.

### 6.1 Gruppen registrieren

Die Funktion `TAG_fnc_registerGroups` initialisiert beide Registrierungs-HashMaps und registriert Event Handler für neue Gruppen und Einheiten.

**Bereits vorhandene Gruppen**

Beim Missionsstart durchläuft die Funktion `allGroups`. Gruppen ohne Spielereinheiten werden in `TAG_PersistentGroups` aufgenommen. Dadurch können sie von der ereignisbasierten Zerstörungserkennung erfasst werden.

**Neu erzeugte Gruppen**

Der `GroupCreated`-Event-Handler trägt neu erstellte Gruppen sowohl in `TAG_PersistentGroups` als auch in `TAG_DynamicGroups` ein. Die erste Registrierung kann erfolgen, bevor die Gruppe ihre Einheiten erhalten hat.

**Besatzungen dynamischer Fahrzeuge**

Der `EntityCreated`-Event-Handler erkennt neu erzeugte KI-Einheiten. Nach einer kurzen Verzögerung prüft er, ob die Einheit bereits zu einer Gruppe gehört und in einem dynamischen Fahrzeug mit einer ID nach dem Schema `DYNVEH_<laufende-ID>` sitzt.

Wird eine solche Besatzung erkannt, wird ihre Gruppe anhand der aktuellen Gruppenkennung in beiden HashMaps registriert. Vorläufige Registrierungsschlüssel derselben Gruppe werden entfernt, damit die Gruppe nicht unter mehreren Kennungen geführt wird.

Gruppen mit Spielereinheiten werden von der KI-Gruppenpersistenz ausgeschlossen.

### 6.2 Dynamische Gruppen speichern

Die Funktion `TAG_fnc_saveDynamicGroups` speichert die Gruppen, die in `TAG_DynamicGroups` registriert sind. Gruppen ohne Einheiten werden übersprungen. Ihre bereits gespeicherten Zustände werden dadurch nicht automatisch gelöscht.

Für jede berücksichtigte Gruppe werden folgende Informationen erfasst:

- **Gruppenparameter:** Seite, Gruppenbezeichnung, Verhalten, Kampfmodus, Geschwindigkeitsmodus und Formation.
- **Einheiten:** Klasse, persistente `UnitID`, Lebensstatus, Position, Ausrichtung, Loadout, Schaden, Trefferzonenschäden, Rang und Skill.
- **Wegpunkte:** Position, Typ, Verhalten, Kampfmodus, Geschwindigkeit, Formation, Abschlussradius, Timeout und Statements.

Gespeicherte Einheitenkennungen folgen dem Schema `<Gruppenkennung>_unit_<laufende-Nummer>`. Die zugehörige Objektvariable lautet `TAG_DynamicUnitUID`; zusätzlich erhält die Einheit mit `TAG_DynamicGroupID` die Kennung ihrer Gruppe.

Bereits vorhandene Einheitenkennungen werden nach Möglichkeit wiederverwendet. Fehlt eine Kennung, versucht die Speicherfunktion zunächst, einen passenden gespeicherten Eintrag anhand der Einheitenklasse und des bisherigen Lebensstatus zuzuordnen. Andernfalls wird eine neue Kennung vergeben.

Frühere Einheiteneinträge bleiben grundsätzlich erhalten, auch wenn die betreffende Einheit nicht mehr in der aktuellen Gruppeneinheitenliste vorkommt. Solche Einträge werden beim Speichern als nicht lebend markiert.

Gespeichert werden nur der aktuelle Wegpunkt und die nachfolgenden Wegpunkte. Nach der Aktualisierung des Bereichs `DynamicGroups` wird `TAG_fnc_saveCampaign` aufgerufen, damit die Kampagnendaten dauerhaft gesichert werden.

### 6.3 Dynamische Gruppen wiederherstellen

Die Funktion `TAG_fnc_restoreDynamicGroups` rekonstruiert die gespeicherten dynamischen Gruppen anhand ihrer gespeicherten Kennungen.

Bevor eine Gruppe verändert wird, prüft die Funktion, ob die Gruppe als zerstört gespeichert ist, ob ein gültiger Gruppendatensatz vorliegt und ob die benötigten Einheitenklassen verfügbar sind.

Die Wiederherstellung umfasst:

1. Die Gruppe unter ihrer gespeicherten Kennung finden oder neu erstellen.
2. Die Gruppenbezeichnung wiederherstellen und vorläufige Registrierungsschlüssel derselben Gruppe entfernen.
3. Gespeicherte Einheiten anhand der Klassen mit vorhandenen Einheiten abgleichen oder fehlende Einheiten neu erstellen.
4. Die persistente `UnitID` jeder rekonstruierten Einheit setzen.
5. Loadout, Rang, Skill, Position und Ausrichtung anwenden.
6. Die Gruppeneinstellungen wiederherstellen.
7. Vorhandene Wegpunkte entfernen und die gespeicherten Wegpunkte erneut anlegen.
8. Die wiederhergestellte Gruppe in `TAG_PersistentGroups` und `TAG_DynamicGroups` registrieren.

**Besonderheit beim Lebensstatus:** Die Wiederherstellungsfunktion setzt rekonstruierte Einheiten grundsätzlich auf volle Gesundheit. Der beim Speichern erfasste Schaden und die Trefferzonenschäden werden nicht wieder angewendet. Gespeicherte Einheiten eines nicht vollständig vernichteten Gruppenverbands können daher auch dann wieder erscheinen, wenn sie zuvor gefallen waren.

Die gespeicherte Kennung einer vernichteten Gruppe hat dagegen Vorrang: Gruppen, deren Kennung in `DestroyedGroups` enthalten ist, werden nicht rekonstruiert.

### 6.4 Vernichtete Gruppen erkennen

Die Funktion `TAG_fnc_trackDestroyedGroups` verwendet einen `EntityKilled`-Mission-Event-Handler anstelle eines permanenten Prüfzyklus.

Wird eine Einheit getötet, ermittelt der Handler ihre Gruppe und sucht diese in `TAG_PersistentGroups`. Anschließend prüft er, wie viele Einheiten dieser Gruppe noch leben.

Sobald keine lebende Einheit mehr vorhanden ist, wird die Gruppenkennung in `TAG_SaveData` unter `DestroyedGroups` eingetragen und der Kampagnenspielstand unmittelbar gespeichert.

Damit kann eine vollständig vernichtete Gruppe über einen Missionsneustart hinweg als vernichtet behandelt werden.

### 6.5 Vernichtete Gruppen anwenden

Die Funktion `TAG_fnc_applyDestroyedGroups` liest die Kennungen aus `DestroyedGroups` aus und sucht die jeweiligen Gruppen in `TAG_PersistentGroups`.

Wird eine Gruppe gefunden, werden ihre Einheiten entfernt und die Gruppe gelöscht. So erscheinen vollständig vernichtete Gruppen beim erneuten Laden der Mission nicht wieder.

Kann eine gespeicherte Gruppe nicht gefunden werden, wird eine Warnung protokolliert.

### 6.6 Grenzen der Gruppenpersistenz

Die Gruppenpersistenz ist auf registrierte KI-Gruppen ausgelegt. Gruppen mit Spielereinheiten werden nicht als persistente KI-Gruppen verwaltet.

Die vollständige Speicherung des Gruppen- und Einheitenzustands ist von der Registrierung zur Zerstörungserkennung zu unterscheiden. Insbesondere durchlaufen die zum Missionsstart über `allGroups` gefundenen Gruppen in der aktuellen Implementierung zunächst nur die Registrierung in `TAG_PersistentGroups`. Die vollständige Zustandsspeicherung über `TAG_fnc_saveDynamicGroups` iteriert dagegen `TAG_DynamicGroups`.

Dynamisch erzeugte Gruppen und erkannte dynamische Fahrzeugbesatzungen werden zusätzlich in `TAG_DynamicGroups` registriert. Die genaue Abgrenzung zwischen Editor-Gruppen und dynamischen Gruppen sollte bei der Missionsplanung berücksichtigt werden.

## 7. Fahrzeugpersistenz

Die Fahrzeugpersistenz verwaltet persistente Editor-Fahrzeuge und dynamisch erstellte Fahrzeuge. Sie speichert deren Zustand, stellt fehlende dynamische Fahrzeuge nach einem Missionsneustart wieder her und hält zerstörte Fahrzeuge als Wracks fest.

Spielerfahrzeuge mit dem Präfix `pveh_` sind davon ausgenommen. Sie werden ausschließlich durch das separate Spielerfahrzeugsystem verwaltet.

### 7.1 Registrierung und Fahrzeug-IDs

Die zentrale Registrierung erfolgt über `TAG_fnc_registerVehicles`. Sie erfasst bereits vorhandene Fahrzeuge und registriert neu erzeugte Fahrzeuge automatisch über den Mission Event Handler `EntityCreated`.

Für persistente Fahrzeuge gelten folgende IDs:

| Fahrzeugtyp | ID-Schema | Vergabe |
|---|---|---|
| Editor-Fahrzeug | `EDEN_<Eden-ID>` | Stabile ID aus der Eden-Editor-Entität |
| Dynamisches Fahrzeug | `DYNVEH_<Nummer>` | Laufende Nummer, beispielsweise `DYNVEH_1` |
| Spielerfahrzeug | `pveh_<Name>` | Wird vom separaten Spielerfahrzeugsystem verwaltet |

Dynamische IDs werden anhand der bereits gespeicherten Fahrzeugzustände, Wrackdaten und Einträge in `DestroyedVehicles` fortgeführt. Dadurch sollen bereits verwendete IDs nach einem Neustart nicht erneut vergeben werden.

Bei der Registrierung wird geprüft, ob eine ID bereits durch ein anderes Fahrzeug belegt ist. Eine Kollision bei dynamischen IDs führt zur Vergabe einer neuen Nummer. Eine doppelte Eden-ID wird dagegen als Fehler protokolliert und das betroffene Fahrzeug nicht unter dieser ID registriert.

Alle registrierten Fahrzeuge werden in der serverseitigen HashMap `TAG_PersistentVehicles` abgelegt. Ihr Schlüssel ist die persistente Fahrzeug-ID. Zusätzlich erhält jedes Objekt die Variable `TAG_PersistentVehicleID`; dynamische Fahrzeuge erhalten außerdem `TAG_DynamicVehicleID`.

Spieler, Einheiten (`Man`) und simulierte Waffenhalter (`WeaponHolderSimulated`) werden nicht als persistente Fahrzeuge registriert.

**Wichtig: Spielerfahrzeuge müssen zwingend das Präfix `pveh_` besitzen.**

Jedes Fahrzeug, das durch das separate Spielerfahrzeugsystem verwaltet werden soll, muss im Eden-Editor einen Variablennamen erhalten, der mit `pveh_` beginnt, beispielsweise `pveh_fahrzeug_01`.

Das Präfix ist erforderlich, damit `TAG_fnc_registerVehicles` das Fahrzeug vom allgemeinen Fahrzeugpersistenzsystem ausschließt. Fehlt das Präfix, wird das Fahrzeug als normales persistentes Fahrzeug registriert: Editor-Fahrzeuge erhalten eine `EDEN_<Eden-ID>`, dynamisch erzeugte Fahrzeuge eine `DYNVEH_<Nummer>`.

**Die korrekte Benennung ist daher Voraussetzung für die Trennung der beiden Persistenzsysteme.** Die Ausnahme erfolgt nicht automatisch anhand des Fahrzeugtyps, seiner Besatzung oder seiner Verwendung als Spielerfahrzeug.

### 7.2 Speichern des Fahrzeugzustands

Die Funktion `TAG_fnc_saveVehicleStates` speichert die Zustände registrierter Fahrzeuge in der HashMap `Vehicles` innerhalb von `TAG_SaveData`.

Berücksichtigt werden registrierte Fahrzeuge, die noch existieren, leben und nicht bereits in `DestroyedVehicles` aufgeführt sind.

Gespeichert werden:

| Datenfeld | Inhalt |
|---|---|
| `Class` | Fahrzeugklasse |
| `Position` | Position in ATL-Koordinaten |
| `VectorDirAndUp` | Ausrichtung und Aufwärtsvektor |
| `Damage` | Gesamtschaden |
| `HitPoints` | Gespeicherte Trefferpunkt-Schäden |
| `Fuel` | Treibstoffstand |
| `TurretMagazines` | Turmmagazine einschließlich Turmpfad und Restmunition |
| `PylonMagazines` | Pylonen, Magazin-Klassen und Restmunition |
| `WeaponCargo` | Waffen im Laderaum |
| `MagazineCargo` | Magazine im Laderaum |
| `ItemCargo` | Gegenstände im Laderaum |
| `BackpackCargo` | Rucksäcke im Laderaum |

Für dynamische Fahrzeuge werden zusätzlich die aktuellen Besatzungsplätze unter `Crew` gespeichert. Ein Besatzungsdatensatz enthält:

- `UnitID`: stabile ID der dynamischen Einheit
- `Role`: Besatzungsrolle
- `CargoIndex`: Index eines Cargo-Sitzplatzes
- `TurretPath`: Pfad des Turmplatzes
- `PersonTurret`: Kennzeichnung eines Person-Turmsitzes

Die Zuordnung wird über `fullCrew` ermittelt. Einheiten ohne `TAG_DynamicUnitUID` können nicht in den gespeicherten Besatzungsdatensatz übernommen werden; hierfür wird eine Warnung ausgegeben.

Auch eine vollständig leere Besatzung wird explizit gespeichert. Wenn Einheiten vor dem Speichern aussteigen, gelten sie somit nicht länger als Besatzung dieses Fahrzeugs. Die Einheit selbst wird weiterhin durch die dynamische Gruppenpersistenz verwaltet.

Nach dem Speichern der Fahrzeugzustände wird `TAG_fnc_saveCampaign` aufgerufen, um den Kampagnenspielstand zu sichern.

### 7.3 Wiederherstellen dynamischer Fahrzeuge

Die Funktion `TAG_fnc_restoreDynamicVehicles` erstellt dynamische Fahrzeuge, die im gespeicherten Spielstand vorhanden, aber aktuell nicht registriert sind.

Dabei werden zwei Fälle unterschieden:

**Überlebende dynamische Fahrzeuge:** Die Funktion liest Fahrzeugklasse, Position und Ausrichtung aus `Vehicles` und erzeugt fehlende Fahrzeuge mit derselben ID. Der übrige gespeicherte Zustand wird anschließend durch `TAG_fnc_applyVehicleStates` angewendet.

**Zerstörte dynamische Fahrzeuge:** Für IDs aus `DestroyedVehicles` werden vorhandene Wrackdaten aus `VehicleWrecks` herangezogen. Sofern entsprechende Daten vorhanden sind, wird ein Fahrzeugobjekt für die anschließende Wrackwiederherstellung bereitgestellt.

Vor der Erstellung wird geprüft, ob das Fahrzeug unter seiner ID bereits existiert. Dadurch soll verhindert werden, dass beim Wiederherstellen doppelte Objekte erzeugt werden. Ungültige oder in der aktuellen Konfiguration nicht vorhandene Fahrzeugklassen werden protokolliert und nicht erstellt.

Die dynamische Fahrzeugregistrierung wird während der gezielten Erstellung unterdrückt. Die Wiederherstellungsfunktion trägt das neue Objekt anschließend selbst unter seiner gespeicherten ID in `TAG_PersistentVehicles` ein.

Editor-Fahrzeuge werden nicht auf diesem Weg neu erstellt. Sie sind bereits durch die Missionsdefinition vorhanden und werden über ihre Registrierung wiedergefunden. Spielerfahrzeuge verbleiben im separaten System.

### 7.4 Anwenden gespeicherter Fahrzeugzustände

Die Funktion `TAG_fnc_applyVehicleStates` wendet die Daten aus `Vehicles` auf registrierte, nicht zerstörte Fahrzeuge an.

Sie stellt Position, Ausrichtung, Gesamtschaden, Trefferpunkt-Schäden und Treibstoff wieder her. Der Laderaum wird geleert und anhand der gespeicherten Inventardaten neu aufgebaut.

Für Turmmunition werden die gespeicherten Magazine zunächst an den betroffenen Türmen entfernt und anschließend mit den gespeicherten Munitionsständen wieder hinzugefügt. Sind die betreffenden Türme auf dem Server nicht lokal, wird die Wiederherstellung der Turmmunition übersprungen und eine Warnung ausgegeben.

Pylonenmunition wird nur angewendet, wenn das aktuell am jeweiligen Pylon vorhandene Magazin mit der gespeicherten Magazin-Klasse übereinstimmt. Bei Abweichungen wird eine Warnung ausgegeben.

Die Funktion arbeitet mit der zentralen Registrierung und beschränkt sich daher nicht auf dynamische Fahrzeuge. Auch registrierte Editor-Fahrzeuge können einen gespeicherten Fahrzeugzustand erhalten. Zerstörte Fahrzeuge werden bei diesem Schritt ausgelassen.

### 7.5 Besatzung dynamischer Fahrzeuge

Die Sitzplatzpersistenz wird durch `TAG_fnc_restoreDynamicVehicleCrew` umgesetzt. Sie betrifft ausschließlich dynamische Fahrzeuge und verwendet die gespeicherten `Crew`-Daten aus `Vehicles`.

Die Funktion erzeugt keine neuen Besatzungsmitglieder. Stattdessen sucht sie vorhandene Einheiten anhand ihrer `TAG_DynamicUnitUID` und ordnet sie den gespeicherten Sitzplätzen zu. Fehlt eine Einheit, ist sie ein Spieler oder kann sie auf dem Server nicht lokal gesteuert werden, wird die Zuordnung nicht vorgenommen und gegebenenfalls eine Warnung protokolliert.

Vor der Sitzplatzzuweisung werden die gefundenen Einheiten aus ihren bisherigen Fahrzeugen gelöst. Anschließend werden Fahrer-, Cargo- und Turmplätze anhand der gespeicherten Rolle, des Cargo-Index beziehungsweise des Turmpfads zugewiesen.

Die Funktion überprüft danach, ob die tatsächliche Besatzungsposition mit der gespeicherten Zuordnung übereinstimmt. Eine erfolgreiche Sitzplatzzuweisung wird protokolliert; nicht bestätigte Plätze werden als Fehler erfasst.

Befinden sich dynamische KI-Einheiten in einem Fahrzeug, obwohl sie laut gespeichertem Besatzungsdatensatz nicht mehr dazugehören, werden sie aus dem Fahrzeug gelöst. Falls für ihre `UnitID` eine gespeicherte Position und Ausrichtung aus `DynamicGroups` verfügbar ist, werden diese Werte erneut angewendet.

Fehlt das Feld `Crew` bei einem gespeicherten Fahrzeugzustand vollständig, wird keine explizite Sitzplatzwiederherstellung für dieses Fahrzeug durchgeführt. Ein vorhandenes, leeres `Crew`-Array stellt dagegen einen gespeicherten Zustand ohne Besatzung dar.

### 7.6 Zerstörte Fahrzeuge und Wracks

Die Fahrzeugzerstörung wird ereignisbasiert durch `TAG_fnc_trackDestroyedVehicles` überwacht. Der Mission Event Handler `EntityKilled` erkennt, ob das zerstörte Objekt in `TAG_PersistentVehicles` registriert ist.

Für ein zerstörtes Fahrzeug werden folgende Daten in `VehicleWrecks` gesichert:

- `VehicleClass`: ursprüngliche Fahrzeugklasse
- `WreckClass`: in der Fahrzeugkonfiguration hinterlegte Wrackklasse
- `Position`: Position in ATL-Koordinaten
- `VectorDirAndUp`: Ausrichtung und Aufwärtsvektor

Die Fahrzeug-ID wird in `DestroyedVehicles` eingetragen. Gleichzeitig wird der zuvor gespeicherte intakte Fahrzeugzustand aus `Vehicles` entfernt. Anschließend wird der Kampagnenspielstand gespeichert.

Die Funktion `TAG_fnc_applyDestroyedVehicles` stellt zerstörte, registrierte Fahrzeuge nach der Wiederherstellung als Wracks dar. Sie deaktiviert dafür vor der Zerstörung die ACE-Cook-off-Variable `ace_cookoff_enable`, wendet die gespeicherte Position und Ausrichtung an und setzt den Schaden auf `1`.

Zerstörte Fahrzeuge werden somit nicht als intakte Fahrzeuge mit dem alten Zustand wiederhergestellt. Die Wrackposition und -ausrichtung bleiben erhalten, sofern entsprechende Wrackdaten vorhanden sind. Eine automatische Bereinigung der Wracks ist in diesen Funktionen nicht vorgesehen.

### 7.7 Zugehörige Speicherfelder

Die Fahrzeugpersistenz verwendet die folgenden Einträge von `TAG_SaveData`:

| Schlüssel | Zweck |
|---|---|
| `Vehicles` | Zustände intakter Fahrzeuge und gegebenenfalls Besatzungszuordnungen |
| `VehicleWrecks` | Klassen- und Positionsdaten zerstörter Fahrzeuge |
| `DestroyedVehicles` | IDs zerstörter Fahrzeuge |

`VehicleWrecks` wird bei Bedarf als HashMap angelegt. Bei der Registrierung werden seine Schlüssel berücksichtigt, damit dynamische Fahrzeug-IDs auch nach einer Zerstörung nicht erneut vergeben werden.

Die Fahrzeugfunktionen schreiben Diagnosen über die zentrale Debug-Funktion und ergänzen damit die RPT-Ausgabe um Registrierungs-, Speicher- und Wiederherstellungsinformationen.

## 8. Spielerpersistenz

Die Spielerpersistenz speichert und restauriert den Zustand definierter Spielereinheiten. Jede persistente Spielerrolle wird über ihren Eden-Variablennamen identifiziert. Dadurch bleibt der gespeicherte Zustand an die jeweilige Rolle gebunden und nicht an ein bestimmtes Spieler-Konto.

Das System speichert die Position, Ausrichtung und Ausrüstung lebender Spieler. Bei einem erneuten Beitritt werden diese Daten wiederhergestellt. Beim Respawn bleibt dagegen die von der Mission festgelegte Spawnposition erhalten.

### 8.1 Persistente Spielerrollen registrieren

Die Funktion `TAG_fnc_registerPlayers` registriert die persistenten Spielerrollen bei der Serverinitialisierung.

Dazu durchsucht sie die Variablen der `missionNamespace` nach Namen, die mit `player_` beginnen. Der zugehörige Wert muss eine gültige Objektreferenz auf eine Einheit der Klasse `CAManBase` sein.

Die Registrierung wird in der serverseitigen HashMap `TAG_PersistentPlayers` gespeichert. Der Variablenname bildet dabei den Schlüssel, die zugehörige Einheit den Wert.

**Wichtig: Das Präfix `player_` ist für persistente Spielerrollen zwingend erforderlich.**

Beispiele:

| Eden-Variablenname | Bedeutung |
|---|---|
| `player_squadleader` | Persistente Spielerrolle |
| `player_rifleman_01` | Persistente Spielerrolle |
| `squadleader` | Wird nicht als persistente Spielerrolle registriert |

Die Namen müssen mit dem Präfix `player_` beginnen. Groß- und Kleinschreibung sowie der vollständige Variablenname sind relevant, da das Präfix direkt mit dem Zeichenfolgenvergleich geprüft wird.

Die Rolle muss als benannte Einheit im Eden-Editor vorhanden sein. Bei der Wiederherstellung wird der aktuelle Beitritt beziehungsweise Respawn anhand derselben Rollenkennung zugeordnet.

### 8.2 Gespeicherter Spielerzustand

Die dauerhaften Spielerdaten werden in der HashMap `Players` innerhalb von `TAG_SaveData` abgelegt.

Jede Rolle besitzt einen eigenen Datensatz mit folgenden Feldern:

| Datenfeld | Inhalt |
|---|---|
| `Position` | Position in ATL-Koordinaten |
| `VectorDirAndUp` | Ausrichtung und Aufwärtsvektor |
| `Loadout` | Gespeicherte Ausrüstung einschließlich Waffen, Magazinen, Munition und Ausrüstungsslots |

Die Funktion `TAG_fnc_savePlayers` aktualisiert den Zustand registrierter Rollen, deren Einheiten vorhanden, lebendig und aktuell einem Spieler zugewiesen sind.

Nicht gespeicherte oder momentan nicht gültige Rollen werden übersprungen. Ein zuvor gespeicherter Datensatz bleibt dabei erhalten, sodass ein vorübergehend nicht besetzter oder gestorbener Spieler nicht automatisch aus der persistenten Speicherung entfernt wird.

Nach der Aktualisierung wird `TAG_fnc_saveCampaign` aufgerufen, um die Änderungen dauerhaft in `missionProfileNamespace` zu sichern.

### 8.3 Wiederherstellung beim Beitritt und Respawn

Die Funktion `TAG_fnc_requestRestorePlayer` prüft Wiederherstellungsanfragen serverseitig und übermittelt den gespeicherten Zustand an den zuständigen Client.

Vor der Wiederherstellung werden mehrere Bedingungen geprüft:

- Die Einheit muss gültig sein.
- Der angefragte Rollenname muss mit `vehicleVarName` der Einheit übereinstimmen.
- Die Rollenkennung muss mit `player_` beginnen.
- Die Rolle muss in `TAG_PersistentPlayers` registriert sein.
- Der aufrufende Client darf nur die ihm zugehörige Einheit anfragen.
- Ein gültiger dauerhafter Spielerzustand muss vorhanden sein.

Bei einem Respawn erkennt die Funktion, dass die neu übermittelte Einheit nicht mehr mit der bisher registrierten Einheit identisch ist. Eine gültige neue Spielereinheit ersetzt dann die bisherige Einheit in `TAG_PersistentPlayers`.

Für die anschließende Wiederherstellung gelten zwei unterschiedliche Fälle:

**Erster Beitritt beziehungsweise Wiederbeitritt ohne erkannten Respawn:** Die gespeicherte Position und Ausrichtung werden wiederhergestellt.

**Respawn:** Die aktuelle Spawnposition der Mission bleibt erhalten. Die gespeicherte Position und Ausrichtung werden nicht angewendet.

In beiden Fällen wird ein geeignetes Loadout ausgewählt und die Wiederherstellung an den Client übergeben. Beim lokal gesteuerten Host-Spieler erfolgt der Funktionsaufruf direkt; ansonsten wird `TAG_fnc_restorePlayer` per Remote Execution auf dem besitzenden Client ausgeführt.

### 8.4 Lokale Wiederherstellung auf dem Client

Die Funktion `TAG_fnc_restorePlayer` führt die eigentliche Wiederherstellung auf dem Client aus, auf dem die Spielereinheit lokal gesteuert wird.

Sie überprüft die Gültigkeit und Lokalität der Einheit sowie den Spielereinheiten-Typ. Zusätzlich muss ein nicht leeres Loadout vorhanden sein.

Anschließend werden – sofern vorgesehen – Position und Ausrichtung angewendet. Danach wird das ausgewählte Loadout mit `setUnitLoadout` restauriert.

Zum Abschluss wird der Schaden der Einheit auf `0` gesetzt. Gespeicherte Verletzungen werden somit nicht übernommen; die wiederhergestellte Spielereinheit hat wieder volle Gesundheit.

### 8.5 Verhalten beim Respawn und Loadout-Auswahl

Die Loadout-Auswahl wird durch die Missionsvariable `TAG_RestoreLoadoutOnRespawn` gesteuert.

Ist die Variable auf `false` gesetzt, wird beim Respawn ausschließlich das dauerhaft gespeicherte Loadout verwendet. Ein gegebenenfalls vorhandenes temporäres Death-Loadout wird ignoriert.

Ist die Variable auf `true` gesetzt und existiert ein gültiger Eintrag in `TAG_DeathLoadouts`, wird das temporäre Death-Loadout beim Respawn verwendet. Ist kein gültiger Eintrag vorhanden, greift das System auf das dauerhaft gespeicherte Loadout zurück.

**Das temporäre Death-Loadout ermöglicht eine bewusste Bestrafung des Spielertodes durch den Missionsbauer.** Der Spieler kann beim Respawn beispielsweise nur mit seiner zuletzt getragenen Ausrüstung zurückkehren, statt automatisch sein älteres, vollständig ausgestattetes Loadout zu erhalten.

Wird das temporäre Death-Loadout beim Respawn angewendet, speichert die Funktion `TAG_fnc_restorePlayer` diese Ausrüstung zunächst nur auf der Spielereinheit. Beim nächsten Autosave übernimmt `TAG_fnc_savePlayers` das aktuell getragene Loadout in den dauerhaften Spielerdatensatz unter `TAG_SaveData["Players"]`.

Damit wird das nach dem Respawn tatsächlich verwendete Loadout zum neuen persistenten Ausrüstungsstand. Der Mechanismus funktioniert ohne eine direkte Änderung am dauerhaften Spielerdatensatz beim Speichern des Death-Loadouts.

### 8.6 Temporäre Speicherung des Death-Loadouts

Die Funktion `TAG_fnc_savePlayerDeathLoadout` nimmt das Loadout einer gestorbenen persistenten Spielereinheit entgegen und speichert es unter ihrer Rollenkennung in der serverseitigen HashMap `TAG_DeathLoadouts`.

Vor dem Speichern werden die Rollenkennung, die Einheit und bei Remote-Aufrufen der Besitzer der Einheit überprüft.

Das Death-Loadout wird ausschließlich im Arbeitsspeicher in `TAG_DeathLoadouts` abgelegt. Das Speichern selbst verändert weder `TAG_SaveData["Players"]` noch den dauerhaften Kampagnenspielstand.

Erst wenn das temporäre Loadout beim Respawn tatsächlich angewendet wurde, kann es durch den nächsten Autosave zum neuen dauerhaften Loadout werden. Ob das temporäre Loadout beim Respawn verwendet wird, hängt von `TAG_RestoreLoadoutOnRespawn` ab.

Das temporäre Death-Loadout bleibt bis zu einer Überschreibung durch einen weiteren Speichervorgang innerhalb der Mission verfügbar. Dadurch entscheidet der Missionsbauer über die gewünschte Konsequenz des Todes, ohne dass dafür die dauerhafte Speicherung beim Tod unmittelbar verändert werden muss.

### 8.7 Zugehörige Speicherfelder und Funktionen

Die Spielerpersistenz verwendet folgende Strukturen:

| Struktur | Zweck |
|---|---|
| `TAG_PersistentPlayers` | Registrierte persistente Spielerrollen und ihre aktuellen Einheiten |
| `TAG_SaveData["Players"]` | Dauerhaft gespeicherte Spielerzustände |
| `TAG_DeathLoadouts` | Temporäre Loadouts nach dem Tod |
| `TAG_RestoreLoadoutOnRespawn` | Steuert die Verwendung temporärer Death-Loadouts beim Wiederherstellen |

Die zugehörigen Funktionen sind:

- `TAG_fnc_registerPlayers`: Registriert persistente Spielerrollen.
- `TAG_fnc_requestRestorePlayer`: Prüft die Anfrage, ermittelt den Zustand und veranlasst die Wiederherstellung.
- `TAG_fnc_restorePlayer`: Stellt den Zustand lokal auf dem Client wieder her.
- `TAG_fnc_savePlayers`: Speichert die dauerhaften Spielerzustände.
- `TAG_fnc_savePlayerDeathLoadout`: Speichert ein temporäres Loadout beim Tod.

Die Spielerpersistenz arbeitet unabhängig von der Persistenz der Spielerfahrzeuge. Die Fahrzeug- und Sitzplatzwiederherstellung wird durch die dafür vorgesehenen Fahrzeugfunktionen abgewickelt.

### 8.8 Verhalten beim Tod einer Spielereinheit

Die Funktion `TAG_fnc_onPlayerKilledPersistence` wird beim Tod einer Spielereinheit auf dem Client ausgeführt. Sie ermittelt die persistente Rollenkennung anhand des Eden-Variablennamens und liest das aktuelle Loadout der verstorbenen Einheit aus.

Das Speichern beim Tod wird durch die Missionsvariable `TAG_SaveLoadoutOnDeath` gesteuert.

Ist die Variable auf `false` gesetzt, wird kein temporäres Death-Loadout erfasst. Ist sie auf `true` gesetzt, wird das aktuelle Loadout an den Server übermittelt und durch `TAG_fnc_savePlayerDeathLoadout` unter der jeweiligen Rollenkennung in `TAG_DeathLoadouts` gespeichert.

Die temporäre Speicherung verändert den dauerhaften Spielerzustand in `TAG_SaveData["Players"]` nicht. Sie dient ausschließlich als mögliche Grundlage für die anschließende Loadout-Wiederherstellung beim Respawn.

Voraussetzung ist eine erkannte persistente Spielerrolle mit dem Präfix `player_`. Einheiten ohne dieses Präfix werden nicht durch diesen Mechanismus berücksichtigt.

### 8.9 Verhalten beim Respawn

Die Funktion `TAG_fnc_onPlayerRespawnPersistence` stößt nach dem Respawn die Wiederherstellung des persistenten Spielerzustands an.

Sie wartet zunächst, bis die neue Spielereinheit lokal verfügbar ist und die serverseitige Persistenzinitialisierung mit `TAG_PersistenceReady` abgeschlossen wurde. Anschließend prüft sie, ob die Einheit einer persistenten Spielerrolle mit dem Präfix `player_` zugeordnet ist.

Danach fordert sie über `TAG_fnc_requestRestorePlayer` die Wiederherstellung des Spielerzustands beim Server an. Bei einem lokal gesteuerten Host-Spieler erfolgt der Aufruf direkt; bei anderen Clients wird er per Remote Execution an den Server übermittelt.

Die Funktion selbst entscheidet nicht, welches Loadout verwendet wird. Diese Entscheidung trifft `TAG_fnc_requestRestorePlayer` anhand von `TAG_RestoreLoadoutOnRespawn` und dem vorhandenen temporären Death-Loadout.

Dabei gilt:

- Ist `TAG_RestoreLoadoutOnRespawn` aktiviert und ein gültiges temporäres Death-Loadout vorhanden, wird dieses bevorzugt.
- Andernfalls wird das dauerhaft gespeicherte Loadout verwendet.

Die Respawn-Funktion fordert die Wiederherstellung in beiden Fällen an. Die Auswahl des Loadouts bleibt zentral in der Spielerwiederherstellung geregelt.

### 8.10 Zusammenspiel der Tod- und Respawn-Einstellungen

Die Einstellungen `TAG_SaveLoadoutOnDeath` und `TAG_RestoreLoadoutOnRespawn` erfüllen unterschiedliche Aufgaben:

| Einstellung | Aufgabe |
|---|---|
| `TAG_SaveLoadoutOnDeath` | Steuert, ob das Loadout beim Tod temporär erfasst wird. |
| `TAG_RestoreLoadoutOnRespawn` | Steuert, ob beim Respawn ein vorhandenes temporäres Death-Loadout bevorzugt wird. |

Durch diese Trennung kann der Missionsbauer unabhängig festlegen, ob das Loadout beim Tod erfasst wird und ob es beim Respawn tatsächlich verwendet werden soll.

Wird das temporäre Death-Loadout beim Respawn angewendet, kann der nächste reguläre Autosave das tatsächlich getragene Loadout in den dauerhaften Spielerzustand übernehmen. Damit lässt sich ein Ausrüstungsverlust nach dem Tod auch über weitere Missionsneustarts hinweg beibehalten.

## 9. Persistente Trigger

Das Trigger-System ermöglicht es, einmalige Editor-Trigger über Missionsneustarts hinweg als abgeschlossen zu speichern. Bereits abgeschlossene Trigger werden beim nächsten Missionsstart deaktiviert, sodass ihre Aktivierungsaktion nicht erneut ausgeführt wird.

Die Persistenz wird über den Variablennamen des Triggers gesteuert.

### 9.1 Zwingende Namenskonvention

**Wichtig: Ein Trigger ist nur dann persistent, wenn sein Eden-Variablenname mit `trg_persist_` beginnt.**

Beispiele:

| Variablenname | Verhalten |
|---|---|
| `trg_persist_gasstation` | Wird als persistenter Trigger registriert |
| `trg_persist_checkpoint_01` | Wird als persistenter Trigger registriert |
| `trg_gasstation` | Keine Triggerpersistenz |
| `gasstation_trigger` | Keine Triggerpersistenz |

Das Präfix ist zwingend erforderlich. Trigger ohne dieses Präfix werden vom Persistenzsystem ignoriert und behalten ihr normales Missionsverhalten bei. **Wenn ihre Aktivierungsbedingungen beim Missionsstart erfüllt sind, können sie ihre Aktivierungsaktion erneut ausführen**, auch wenn diese Aktion bereits in einem vorherigen Missionsdurchlauf ausgeführt wurde.

Wer eine einmalige Missionsaktion dauerhaft gegen eine erneute Ausführung absichern möchte, muss den Trigger daher entsprechend benennen und als nicht wiederholbar konfigurieren.

### 9.2 Voraussetzungen und Registrierung

Die Funktion `TAG_fnc_registerPersistentTriggers` durchsucht die vorhandenen `EmptyDetector`-Objekte nach Triggern, deren Eden-Variablenname mit `trg_persist_` beginnt.

Wiederholbare Trigger werden ignoriert. Bei den übrigen Triggern wird der gespeicherte Abschlussstatus aus `TriggerStates` geprüft.

Bereits abgeschlossene Trigger werden deaktiviert, indem ihre Aktivierungsbedingung auf `false` gesetzt und ihre Aktivierungs- und Deaktivierungsaktionen geleert werden. Dadurch können sie nach einem Missionsneustart nicht erneut auslösen.

Noch offene Trigger behalten ihre ursprüngliche Aktivierungsbedingung und Deaktivierungsaktion. Ihre Aktivierungsaktion wird um die zentralen Persistenzfunktionen ergänzt.

### 9.3 Verhalten beim Auslösen eines Triggers

Bei der Aktivierung eines registrierten Triggers wird zunächst der Abschluss über `TAG_fnc_completePersistentTrigger` gespeichert. Anschließend wird die ursprüngliche Aktivierungsaktion ausgeführt und um weitere Speicherfunktionen ergänzt.

Dabei werden die Respawn-Tickets und Markerzustände gesichert. Außerdem wird nach einer Verzögerung von einer Sekunde die Synchronisierung der Aufgabenregistrierung gestartet.

Der gespeicherte Abschlussstatus sorgt dafür, dass der Trigger beim nächsten Missionsstart deaktiviert wird und seine ursprüngliche Aktivierungsaktion nicht erneut ausgeführt werden kann.

### 9.4 Speichern des Triggerabschlusses

Die Funktion `TAG_fnc_completePersistentTrigger` übernimmt das dauerhafte Speichern eines Triggerabschlusses.

Sie erwartet als Parameter den Variablennamen des Triggers. Der Aufruf muss auf dem Server erfolgen. Zusätzlich werden ein leerer Triggername und ein nicht initialisierter Spielstand abgefangen.

Der Abschlussstatus wird in der HashMap `TriggerStates` unter dem Triggernamen abgelegt:

- `true`: Der Trigger wurde als abgeschlossen gespeichert.
- `false` beziehungsweise kein gespeicherter Eintrag: Es ist kein Abschluss hinterlegt.

Ist ein Trigger bereits als abgeschlossen gespeichert, wird kein erneuter Abschluss geschrieben. Bei einem neuen Abschluss wird zunächst `TriggerStates` aktualisiert und anschließend `TAG_fnc_saveCampaign` aufgerufen.

Damit bleibt der Abschluss über einen Missionsneustart hinweg erhalten.

### 9.5 Grenzen und Hinweise für den Missionsbauer

Die Triggerpersistenz speichert den Abschluss anhand des Variablennamens. Deshalb müssen persistente Trigger eindeutig benannt werden. Wird ein Name geändert, sucht das System beim nächsten Missionsstart nach dem neuen Namen und findet den alten Abschluss unter diesem neuen Schlüssel nicht automatisch wieder.

Die Persistenz ersetzt außerdem nicht die fachliche Konfiguration des Triggers. Der Missionsbauer muss weiterhin sicherstellen, dass die ursprüngliche Bedingung und Aktivierungsaktion korrekt eingerichtet sind.

Zusammengefasst gelten folgende Regeln:

- Für persistente Einmal-Trigger muss das Präfix `trg_persist_` verwendet werden.
- Der Trigger muss als nicht wiederholbar konfiguriert sein.
- Der Variablenname muss über Missionsdurchläufe hinweg stabil bleiben.
- Trigger ohne das Präfix werden nicht durch das Persistenzsystem verwaltet und können beim Missionsstart erneut auslösen, wenn ihre Bedingungen erfüllt sind.

### 9.6 Zugehörige Speicherfelder und Funktionen

| Struktur oder Funktion | Zweck |
|---|---|
| `TAG_SaveData["TriggerStates"]` | Speichert abgeschlossene Trigger |
| `TAG_fnc_registerPersistentTriggers` | Registriert persistente Editor-Trigger und deaktiviert bereits erledigte Trigger |
| `TAG_fnc_completePersistentTrigger` | Speichert einen neuen Triggerabschluss |
| `TAG_fnc_saveRespawnTickets` | Sichert den Respawn-Ticketstand nach der Aktivierung |
| `TAG_fnc_saveMarkerStates` | Sichert Markerzustände nach der Aktivierung |
| `TAG_fnc_syncTaskRegistry` | Synchronisiert die Aufgabenregistrierung nach einer kurzen Verzögerung |

## 10. Aufgabenpersistenz (Tasks)

Die Aufgabenpersistenz speichert den Status von Missionsaufgaben und stellt ihn nach einem Missionsneustart wieder her. Zusätzlich können gespeicherte Task-Definitionen verwendet werden, um zuvor erstellte Aufgaben erneut anzulegen, falls sie beim Missionsstart noch nicht vorhanden sind.

Das System unterscheidet zwischen zwei Datenbereichen:

- `Tasks`: Speichert die aktuellen Zustände der Aufgaben.
- `TaskDefinitions`: Speichert die Informationen, die zur Rekonstruktion von Aufgaben benötigt werden.

Die eigentlichen Aufgaben werden durch die Mission beziehungsweise deren Task-Erstellungsmodule angelegt. Die Persistenz ergänzt dieses System um Registrierung, Statusspeicherung und Wiederherstellung.

### 10.1 Task-Definitionen registrieren

Die Funktion `TAG_fnc_registerTaskDefinitions` durchsucht die Missionsobjekte nach Eden-Task-Erstellungsmodulen vom Typ `ModuleTaskCreate_F`.

Für jedes gefundene Modul werden die Task-ID, der Titel, die Beschreibung, der Owner, der initiale Status und gegebenenfalls die Zielposition ausgelesen.

Automatisch unterstützt werden folgende Owner-Werte:

| Eden-Owner-Wert | Bedeutung |
|---|---|
| `1` | Eine oder mehrere Gruppen |
| `3` | Alle spielbaren Einheiten |

Bei Owner `1` ermittelt das System die mit dem Modul synchronisierten Einheiten und deren Gruppen. Die zugehörigen Gruppenvariablen müssen eindeutig über das Präfix `player_grp_` aufgelöst werden können. Sind mehrere Gruppen beteiligt, werden ihre Kennungen gemeinsam in der Definition gespeichert.

Bei Owner `3` wird die Aufgabe für alle spielbaren Einheiten definiert.

Fehlende Task-IDs, fehlende Titel, nicht unterstützte Owner-Werte oder nicht eindeutig auflösbare Gruppenzuordnungen führen dazu, dass die betreffende Definition übersprungen wird.

Die automatische Suche erzeugt selbst keine Aufgaben. Sie übergibt die gefundenen Informationen an `TAG_fnc_registerTaskDefinition`, welche die Definition zentral in `TAG_SaveData["TaskDefinitions"]` speichert.

### 10.2 Gespeicherte Task-Definitionen

Jede Task-Definition wird anhand ihrer Task-ID identifiziert und enthält folgende Informationen:

| Feld | Bedeutung |
|---|---|
| `OwnerType` | Typ des Aufgabenbesitzers |
| `OwnerId` | Kennung des Besitzers |
| `OwnerIds` | Liste der Gruppenkennungen bei mehreren Gruppen |
| `Description` | Titel, Kurzbeschreibung und Langbeschreibung |
| `Destination` | Zielposition oder leeres Array ohne Ziel |
| `InitialState` | Vorgesehener Ausgangsstatus |
| `Created` | Gibt an, ob die Aufgabe bereits erstellt wurde |

Bei einer erneuten Registrierung werden vorhandene Laufzeitinformationen, insbesondere `Created`, übernommen. Die Definition kann somit aktualisiert werden, ohne den bereits gespeicherten Erstellungsstatus zurückzusetzen.

Nach der Registrierung wird der Kampagnenspielstand gesichert.

### 10.3 Task-Register synchronisieren

Die Funktion `TAG_fnc_syncTaskRegistry` gleicht die tatsächlich vorhandenen Aufgaben mit den gespeicherten Kampagnendaten ab.

Hierzu ermittelt sie existierende Task-IDs aus den entsprechenden Task-Variablen im `missionNamespace` und prüft sie mit `BIS_fnc_taskExists`.

Für neu erkannte Aufgaben wird der aktuelle Status mit `BIS_fnc_taskState` gelesen und in `Tasks` eingetragen, sofern für diese Aufgabe noch kein gespeicherter Status vorhanden ist. Ein vorhandener gespeicherter Status wird dabei nicht durch den neu ermittelten Status überschrieben.

Existiert für eine Aufgabe bereits eine Definition in `TaskDefinitions`, wird deren Feld `Created` auf `true` gesetzt, sobald die Aufgabe als tatsächlich vorhanden erkannt wurde.

Anschließend veröffentlicht das System die aktuellen Task-Zustände und Definitionen für die Clients. Neu hinzugekommene Task-IDs werden ebenfalls erfasst, damit die Statusüberwachung sie später berücksichtigen kann.

Die Synchronisierung speichert somit sowohl Aufgabenstatus als auch den Erstellungsstand bekannter Task-Definitionen.

### 10.4 Statusänderungen überwachen und speichern

Die Funktion `TAG_fnc_trackTaskStates` läuft auf den Clients und beginnt ihre Überwachung erst, nachdem die Task-Wiederherstellung abgeschlossen wurde.

Sie prüft die bekannten Aufgaben regelmäßig auf Statusänderungen. Neu erkannte Task-IDs werden berücksichtigt, ohne ihren aktuellen Zustand zurückzusetzen.

Stimmt ein neu erkannter Task-Status nicht mit dem gespeicherten Zustand überein, meldet der Client den tatsächlichen Status an den Server. Dasselbe gilt für Statusänderungen, die während der laufenden Mission erkannt werden.

Der Server verarbeitet diese Meldungen über `TAG_fnc_reportTaskState`. Dabei werden der Task-Status und die Existenz der betreffenden Aufgabe überprüft. Nur gültige Statusmeldungen tatsächlich existierender Aufgaben werden übernommen.

Der neue Status wird in `TAG_SaveData["Tasks"]` gespeichert, an alle Clients veröffentlicht und durch `TAG_fnc_saveCampaign` dauerhaft gesichert.

Unterstützte Statuswerte sind:

- `CREATED`
- `ASSIGNED`
- `AUTOASSIGNED`
- `SUCCEEDED`
- `FAILED`
- `CANCELED`

### 10.5 Aufgaben wiederherstellen

Die Funktion `TAG_fnc_restoreTaskStates` wird auf den Clients ausgeführt. Sie wartet zunächst auf den Spieler sowie auf die vom Server veröffentlichten Task-Zustände und Definitionen.

Anschließend werden die gespeicherten Aufgaben bearbeitet.

Existiert ein Task bereits, wird sein gespeicherter Status angewendet. Fehlt die Aufgabe, prüft das System, ob eine passende Definition existiert und deren Feld `Created` auf `true` steht.

Nur in diesem Fall versucht die Wiederherstellung, den fehlenden Task mithilfe von `BIS_fnc_taskCreate` neu anzulegen. Dazu verwendet sie die gespeicherte Definition einschließlich Besitzer, Beschreibungen, Zielposition und initialem Status.

Die Besitzerauflösung ist in der Wiederherstellungsfunktion konkret für `GROUP`, `GROUPS` und `ALL_PLAYABLE_UNITS` implementiert. Gruppen werden anhand ihrer gespeicherten Variablennamen aufgelöst. Bei mehreren Gruppen müssen sämtliche Gruppen gültig gefunden werden.

Nach der Erstellung beziehungsweise Wiedererkennung wartet das System bis zu 30 Sekunden auf die Existenz des Tasks. Ist dieser vorhanden, wird der gespeicherte Zustand mit `BIS_fnc_taskSetState` angewendet. Kann der Task nicht gefunden oder erstellt werden, wird eine Warnung ausgegeben.

Nach Abschluss des Wiederherstellungsdurchlaufs setzt die Funktion `TAG_TaskRestoreComplete` auf `true`. Erst danach darf die clientseitige Statusüberwachung beginnen.

### 10.6 Grenzen und Hinweise für den Missionsbauer

Eine Task-Definition und ein gespeicherter Task-Status erfüllen unterschiedliche Aufgaben. Die Definition beschreibt, wie ein Task angelegt werden kann; der gespeicherte Status beschreibt, welchen Zustand dieser Task beim letzten Speichern hatte.

Daraus ergeben sich folgende Regeln:

- Eden-Task-Erstellungsmodule müssen eine gültige Task-ID und einen Titel besitzen, damit ihre Definition registriert werden kann.
- Die automatische Owner-Erkennung unterstützt Gruppen und alle spielbaren Einheiten.
- Gruppen, die aus Task-Modulen referenziert werden, müssen eindeutig über ihre `player_grp_`-Variablen auflösbar sein.
- Ein fehlender Task wird nur rekonstruiert, wenn eine gespeicherte Definition vorhanden ist und `Created = true` gesetzt wurde.
- Aufgaben ohne rekonstruierbare Definition können weiterhin gespeichert und wiedererkannt werden, lassen sich aber nicht allein anhand eines Status-Eintrags neu erstellen.
- Der gespeicherte Task-Status wird beim Abgleich nicht pauschal durch den aktuell vorgefundenen Zustand ersetzt.

Die Aufgabenpersistenz sorgt damit für eine zentrale Speicherung der bekannten Task-Zustände und stellt die Voraussetzungen bereit, bereits erstellte Aufgaben bei einem Missionsneustart wiederherzustellen.

## 11. Persistenz der Diary-Einträge

Die Diary-Persistenz speichert benutzerdefinierte Diary-Subjects und deren Einträge und stellt sie nach einem Missionsneustart wieder her. Die Einträge können einem einzelnen Spieler, einer Gruppe, einer Seite oder allen Spielern zugeordnet werden.

Die Daten werden clientseitig erfasst, auf dem Server validiert und mit dem bestehenden Speicherbestand zusammengeführt. Die zentrale Speicherung erfolgt in `TAG_SaveData["DiaryEntries"]`.

### 11.1 Geltungsbereiche und Zuordnung

Jeder gespeicherte Diary-Eintrag erhält einen Geltungsbereich (*Scope*). Dieser bestimmt, welchen Spielern der Eintrag bei der Wiederherstellung zur Verfügung gestellt wird.

| Geltungsbereich | Bedeutung | Speicherbereich |
|---|---|---|
| `PLAY` | Spielerspezifischer Eintrag | `PLAY:<Spielervariable>` |
| `GRP` | Eintrag für eine Gruppe | `GRP:<Seite>\|<Gruppenrufzeichen>` |
| `SIDE` | Eintrag für eine Seite | `SIDE:<Seite>` |
| `ALL` | Eintrag für alle Spieler | `ALL:ALL` |

Die Zuordnung wird anhand des Eintragstitels und der dafür vorgesehenen Präfixkonfiguration erkannt. Die dafür verwendeten Konfigurationsvariablen sind `TAG_DiaryPrefixPlayer`, `TAG_DiaryPrefixGroup`, `TAG_DiaryPrefixSide` und `TAG_DiaryPrefixAll`.

Für Gruppeneinträge werden sowohl die Seite als auch die Gruppenkennung berücksichtigt. Dadurch können Gruppen mit gleichem Rufzeichen auf unterschiedlichen Seiten getrennt behandelt werden.

Einträge ohne erkanntes Geltungsbereichspräfix werden zunächst als spielerspezifische Einträge behandelt. Sie bleiben diesem Spieler zugeordnet und werden nicht automatisch zu Gruppen-, Seiten- oder globalen Einträgen. Der Server prüft die Zuordnung, bevor ein Eintrag gespeichert wird.

Die Diary-Erfassung ignoriert die vordefinierten Subjects `Players`, `Units` und `cba_help_docs`.

### 11.2 Erfassung und Speicherung

Die Funktion `TAG_fnc_collectDiaryEntries` liest auf dem jeweiligen Client die vorhandenen Diary-Subjects und deren Einträge aus. Dabei werden Subject-ID, Subject-Titel, Subject-Bild, Eintragstitel, Beschreibung, Icon, Geltungsbereich, Zuordnungsschlüssel und ursprünglicher Eintragsindex erfasst.

Die gesammelten Daten werden an den Server übermittelt. Dort übernimmt `TAG_fnc_reportDiaryEntries` die Validierung und ordnet die Rückmeldung anhand des tatsächlichen Absenders der zugehörigen Spielereinheit zu.

Der Server prüft unter anderem:

- das Datenformat und die Datentypen,
- die erforderlichen Felder und den gültigen Geltungsbereich,
- die Übereinstimmung von Geltungsbereich und Zuordnungsschlüssel,
- die Gültigkeit des Eintragstitel-Präfixes,
- die Berechtigung des Absenders sowie die bestätigte Diary-Wiederherstellung.

Ungültige oder nicht zulässig zugeordnete Einträge werden verworfen.

Die zentrale Speicherung erfolgt über `TAG_fnc_saveDiaryEntries`. Diese Funktion fordert die Diary-Daten der aktiven Clients an, wartet maximal acht Sekunden auf Rückmeldungen und führt die eingegangenen Daten mit dem bestehenden Speicherbestand zusammen.

**Der bestehende Datenbestand wird nicht einfach durch einzelne Client-Snapshots ersetzt.** Neue Einträge werden ergänzt; bereits vorhandene Einträge werden anhand von Subject-ID, Eintragstitel und Beschreibung erkannt. Bei Duplikaten bleibt der bereits gespeicherte Eintragsindex erhalten.

So können gemeinsame Einträge zusammengeführt werden, ohne dass eine einzelne Client-Rückmeldung den gesamten gespeicherten Diary-Bestand überschreibt. Nach erfolgreicher Validierung wird das Ergebnis in `TAG_SaveData["DiaryEntries"]` übernommen und mit `TAG_fnc_saveCampaign` dauerhaft gespeichert.

### 11.3 Wiederherstellung beim Beitritt

Die Funktion `TAG_fnc_requestRestoreDiaryEntries` ermittelt anhand der Spielereinheit des anfragenden Clients die passenden gespeicherten Einträge.

Berücksichtigt werden vier Speicherbereiche:

- der persönliche Speicherbereich des Spielers,
- der Speicherbereich seiner aktuellen Gruppe,
- der Speicherbereich seiner aktuellen Seite,
- der globale Speicherbereich für alle Spieler.

Vor dem Versand wird die Einheit in `TAG_DiaryRestoreReady` als noch nicht wiederhergestellt markiert. Dadurch bleibt die Übernahme ihrer Diary-Daten in spätere Speichervorgänge zunächst gesperrt.

Die ausgewählten Einträge werden nach Subject und ihrem gespeicherten `RecordIndex` sortiert. Dieser Index erhält die ursprüngliche Reihenfolge der Einträge innerhalb eines Diary-Subjects.

Die Daten werden anschließend an den zuständigen Client übermittelt. Auch wenn keine gespeicherten Einträge vorhanden sind, wird ein leerer Datensatz gesendet, damit die Wiederherstellung regulär abgeschlossen und bestätigt werden kann.

### 11.4 Diary-Einträge lokal anwenden

Die Funktion `TAG_fnc_applyDiaryEntries` stellt die übermittelten Daten auf dem Client wieder her.

Fehlt ein gespeichertes Diary-Subject, wird es angelegt. Bereits vorhandene Einträge werden anhand von Titel und Beschreibung erkannt, damit sie nicht doppelt eingefügt werden.

Neue Einträge werden in umgekehrter Reihenfolge verarbeitet. Dadurch bleibt ihre gespeicherte Reihenfolge innerhalb des jeweiligen Diary-Subjects erhalten.

Nachdem sämtliche übermittelten Daten verarbeitet wurden, meldet der Client den Abschluss mit `TAG_fnc_confirmDiaryRestore` an den Server zurück.

### 11.5 Bestätigung und Schutz des gespeicherten Datenbestands

Die Funktion `TAG_fnc_confirmDiaryRestore` prüft, ob die Bestätigung von der zugehörigen Spielereinheit stammt und für diese Einheit tatsächlich eine Wiederherstellung aussteht.

Erst wenn eine gültige Bestätigung eingeht, wird `TAG_DiaryRestoreReady` für diese Einheit auf `true` gesetzt.

Diese Bestätigung ist eine zentrale Voraussetzung für die Speicherung: Client-Daten dürfen nur dann in die Zusammenführung einfließen, wenn der betreffende Client seine Diary-Wiederherstellung abgeschlossen hat.

Damit wird verhindert, dass ein noch nicht wiederhergestellter oder unvollständig initialisierter Client den vorhandenen Speicherbestand unbeabsichtigt verändert.

Die Speicherung ist außerdem gegen fehlerhafte Datensätze und ungültige Speicherbereiche abgesichert. Kann die bestehende Datenstruktur nicht korrekt kopiert oder die Zusammenführung nicht erfolgreich validiert werden, wird das Ergebnis nicht übernommen. Der bisherige gespeicherte Diary-Bestand bleibt erhalten.

### 11.6 Zugehörige Speicherstrukturen und Funktionen

| Struktur oder Funktion | Zweck |
|---|---|
| `TAG_SaveData["DiaryEntries"]` | Dauerhaft gespeicherte Diary-Einträge, getrennt nach Geltungsbereich |
| `TAG_DiarySaveResponses` | Sammelt die Antworten einer laufenden Speicheranforderung |
| `TAG_DiarySaveCounter` | Vergibt eindeutige IDs für Speicheranforderungen |
| `TAG_DiaryRestoreReady` | Hält fest, ob die Diary-Wiederherstellung einer Einheit bestätigt wurde |
| `TAG_fnc_saveDiaryEntries` | Fordert Client-Daten an und führt sie mit dem Speicherbestand zusammen |
| `TAG_fnc_collectDiaryEntries` | Erfasst Diary-Daten lokal auf dem Client |
| `TAG_fnc_reportDiaryEntries` | Validiert eingehende Client-Daten und ordnet sie dem Absender zu |
| `TAG_fnc_requestRestoreDiaryEntries` | Stellt die passenden gespeicherten Daten für einen Client zusammen |
| `TAG_fnc_applyDiaryEntries` | Erstellt fehlende Subjects und stellt Einträge lokal wieder her |
| `TAG_fnc_confirmDiaryRestore` | Bestätigt die erfolgreiche Diary-Wiederherstellung gegenüber dem Server |

Die Diary-Persistenz ermöglicht damit sowohl persönliche als auch gemeinsame Missionsnotizen. Durch die getrennten Speicherbereiche, die Validierung der Client-Daten und die explizite Wiederherstellungsbestätigung wird verhindert, dass einzelne unvollständige Client-Zustände den gemeinsamen Datenbestand unkontrolliert ersetzen.

## 12. Persistenz der Respawn-Tickets

Die Respawn-Ticket-Persistenz speichert den verfügbaren Ticketbestand der einzelnen Fraktionen und stellt ihn nach einem Missionsneustart wieder her. Dadurch bleiben die im Verlauf einer Mission verbrauchten oder hinzugewonnenen Tickets über Neustarts hinweg erhalten.

### 12.1 Gespeicherter Ticketbestand

Die Ticketdaten werden unter `TAG_SaveData["RespawnTickets"]` abgelegt. Die Fraktionen werden anhand ihrer Seitenkennung unterschieden:

- `WEST`
- `EAST`
- `GUER`
- `CIV`

Jeder Eintrag enthält den gespeicherten Ticketbestand der jeweiligen Fraktion.

### 12.2 Wiederherstellung beim Missionsstart

Die Funktion `TAG_fnc_restoreRespawnTickets` übernimmt die Wiederherstellung auf dem Server. Sie erhält die gespeicherten Ticketdaten als HashMap und verarbeitet die vier unterstützten Fraktionen.

Für jeden gültigen, nicht negativen Ticketbestand wird zunächst der aktuell vorhandene Bestand der Fraktion vollständig auf null gesetzt. Anschließend wird der gespeicherte Bestand wieder hinzugefügt.

Der abschließend ermittelte Ticketbestand wird protokolliert. Fehlt für eine Fraktion ein gültiger gespeicherter Wert, wird eine Warnung ausgegeben und der vorhandene Ticketbestand nicht verändert.

Die Funktion stellt die Tickets wieder her, speichert den Spielstand selbst jedoch nicht dauerhaft. Dafür ist die separate Speicherfunktion zuständig.

### 12.3 Speichern während der Mission

Die Funktion `TAG_fnc_saveRespawnTickets` erfasst auf dem Server den aktuellen Ticketbestand der vier Fraktionen `WEST`, `EAST`, `GUER` und `CIV` mithilfe von `BIS_fnc_respawnTickets`.

Für jeden gültigen, nicht negativen Ticketbestand wird die Anzahl unter dem jeweiligen Seitennamen in einer neuen HashMap gespeichert. Fraktionen, für die kein gültiger Ticketbestand ermittelt werden kann, werden übersprungen und mit einer Warnung protokolliert.

Anschließend wird die HashMap `RespawnTickets` in `TAG_SaveData` vollständig aktualisiert und der Kampagnenspielstand mit `TAG_fnc_saveCampaign` dauerhaft gespeichert.

Die Funktion wird im Autosave-Zyklus und nach der Aktivierung persistenter Trigger aufgerufen. Dadurch können Änderungen am Ticketbestand regelmäßig sowie unmittelbar nach bestimmten Missionsereignissen gesichert werden.

### 12.4 Zugehörige Speicherstruktur und Funktionen

| Struktur oder Funktion | Zweck |
|---|---|
| `TAG_SaveData["RespawnTickets"]` | Gespeicherte Ticketbestände der Fraktionen |
| `TAG_fnc_saveRespawnTickets` | Speichert den aktuellen Ticketbestand |
| `TAG_fnc_restoreRespawnTickets` | Stellt den gespeicherten Ticketbestand wieder her |

Die Respawn-Ticket-Persistenz sichert ausschließlich die Ticketbestände. Respawn-Einstellungen wie Spawnpositionen und Respawn-Verhalten werden weiterhin durch die Mission konfiguriert.

## 13. Persistenz der Markerzustände

Die Markerpersistenz speichert und restauriert die Transparenz ausgewählter Editor-Marker. Damit können Marker im Verlauf einer Mission ein- oder ausgeblendet werden, ohne ihren gespeicherten Zustand bei einem Missionsneustart zu verlieren.

### 13.1 Zwingende Namenskonvention

**Ein Marker wird nur dann vom Persistenzsystem gespeichert, wenn sein Name mit `mrk_persist_` beginnt.**

Beispiele:

| Markername | Verhalten |
|---|---|
| `mrk_persist_objective_01` | Alpha-Wert wird gespeichert |
| `mrk_persist_enemy_area` | Alpha-Wert wird gespeichert |
| `objective_01` | Keine Markerpersistenz |
| `enemy_area` | Keine Markerpersistenz |

Das Präfix muss Bestandteil des tatsächlichen Markernamens sein. Marker ohne dieses Präfix werden beim Speichern ignoriert und behalten das normale Verhalten der Mission bei.

### 13.2 Speichern der Markerzustände

Die Funktion `TAG_fnc_saveMarkerStates` wird auf dem Server ausgeführt. Sie durchsucht alle vorhandenen Kartenmarker und erfasst für jeden Marker mit dem Präfix `mrk_persist_` dessen aktuellen Alpha-Wert.

Die Werte werden in der HashMap `MarkerStates` innerhalb von `TAG_SaveData` gespeichert. Der Markername dient dabei als Schlüssel, der Alpha-Wert als Wert.

Nach der Erfassung wird die vollständige HashMap in `TAG_SaveData` übernommen und der Kampagnenspielstand dauerhaft gespeichert.

**Gespeichert wird ausschließlich der Alpha-Wert des Markers.** Position, Farbe, Form, Größe, Text und andere Markereigenschaften werden von diesen Funktionen nicht persistent gesichert.

### 13.3 Wiederherstellung beim Missionsstart

Die Funktion `TAG_fnc_restoreMarkerStates` liest die gespeicherten Werte aus `TAG_SaveData["MarkerStates"]`.

Für jeden gespeicherten Marker wird geprüft, ob ein Marker mit demselben Namen in der aktuellen Mission existiert. Ist das der Fall, wird der gespeicherte Alpha-Wert angewendet, sofern er numerisch und im gültigen Bereich von `0` bis `1` liegt.

Existiert der Marker nicht mehr oder ist der gespeicherte Wert ungültig, wird eine Warnung protokolliert. Andere gültige Markerzustände werden davon nicht beeinträchtigt.

Die Marker müssen daher unter demselben Namen in der Mission vorhanden sein, damit ihre Transparenz wiederhergestellt werden kann.

### 13.4 Zugehörige Speicherstruktur und Funktionen

| Struktur oder Funktion | Zweck |
|---|---|
| `TAG_SaveData["MarkerStates"]` | Gespeicherte Alpha-Werte der persistenten Marker |
| `TAG_fnc_saveMarkerStates` | Erfasst und speichert die aktuellen Alpha-Werte |
| `TAG_fnc_restoreMarkerStates` | Stellt die gespeicherten Alpha-Werte wieder her |

Die Markerpersistenz betrifft ausschließlich Marker mit dem festgelegten Namenspräfix und stellt nur deren Transparenz wieder her. Alle anderen Markereigenschaften bleiben Aufgabe der Missionskonfiguration oder anderer Missionsfunktionen.

## 14. Persistenz der Spielerfahrzeuge

Die Spielerfahrzeugpersistenz verwaltet ausgewählte Editor-Fahrzeuge unabhängig von der normalen Fahrzeugpersistenz. Sie speichert den Fahrzeugzustand und stellt ihn nach einem Missionsneustart wieder her. Zusätzlich kann für jedes Fahrzeug festgelegt werden, ob es nach seiner Zerstörung wiederhergestellt oder dauerhaft als Wrack erhalten werden soll.

Die Spielerfahrzeugpersistenz verwendet eine eigene Registrierung und den Speicherbereich `TAG_SaveData["PlayerVehicles"]`. Sie ist damit von den normalen Fahrzeugdaten unter `Vehicles`, `VehicleWrecks` und `DestroyedVehicles` getrennt.

### 14.1 Zwingende Namenskonvention

**Ein Spielerfahrzeug muss im Eden-Editor einen Variablennamen mit dem Präfix `pveh_` besitzen.**

Beispiele:

| Variablenname | Bedeutung |
|---|---|
| `pveh_transport_01` | Persistentes Spielerfahrzeug |
| `pveh_heli_01` | Persistentes Spielerfahrzeug |
| `transport_01` | Wird nicht als Spielerfahrzeug registriert |

Das Präfix ist zwingend erforderlich. Es sorgt dafür, dass das Fahrzeug vom separaten Spielerfahrzeugsystem erkannt wird und nicht durch die normale Fahrzeugpersistenz verwaltet wird.

Die Funktion `TAG_fnc_registerPlayerVehicles` durchsucht die Variablen im `missionNamespace` nach passenden Namen. Gültige Fahrzeugobjekte werden in `TAG_PersistentPlayerVehicles` registriert. Dabei werden sowohl die Fahrzeugreferenz als auch die Respawn-Einstellung gespeichert.

Die Registrierung erfolgt anhand der Editor-Variablennamen. Fehlende oder ungültige Fahrzeugobjekte werden nicht registriert.

### 14.2 Konfiguration des Fahrzeug-Respawns

Über die Objektvariable `pveh_respawn` wird festgelegt, ob ein Spielerfahrzeug nach seiner Zerstörung durch das Arma-interne Respawn-System erneut verfügbar gemacht werden soll. Dieselbe Einstellung wird vom Persistenzsystem berücksichtigt, um das Verhalten des Fahrzeugs über Missionsneustarts hinweg beizubehalten.

| Wert | Verhalten nach Zerstörung |
|---|---|
| `true` | Respawn ist freigegeben. Das Fahrzeug wird entsprechend der Respawn-Konfiguration und seinem gespeicherten Zustand wiederhergestellt. |
| `false` | Respawn ist nicht freigegeben. Das Fahrzeug bleibt nach einem Missionsneustart als zerstörtes Wrack erhalten. |

Ist die Variable nicht gesetzt, verwendet die Registrierung standardmäßig `false`.

**Wichtig: `pveh_respawn` entscheidet nicht darüber, ob ein Fahrzeug grundsätzlich persistent ist.** Solange ein Spielerfahrzeug nicht zerstört wurde, werden sein Zustand und seine Ausrüstung über Missionsneustarts hinweg gespeichert und wiederhergestellt – unabhängig davon, ob `pveh_respawn` auf `true` oder `false` steht.

Die Einstellung betrifft ausschließlich die Behandlung eines zerstörten Fahrzeugs. Sie ermöglicht dem Missionsbauer, für jedes Spielerfahrzeug individuell festzulegen, ob es nach seiner Zerstörung erneut einsatzbereit zur Verfügung stehen oder dauerhaft als Wrack erhalten bleiben soll.

Die Registrierung liest `pveh_respawn` aus dem Fahrzeugobjekt aus und übernimmt den Wert in `TAG_PersistentPlayerVehicles`. Beim Speichern wird die Einstellung zusätzlich im Fahrzeugzustand unter `Respawn` abgelegt.

### 14.3 Speichern des Fahrzeugzustands

Die Funktion `TAG_fnc_savePlayerVehicles` speichert den Zustand aller registrierten Spielerfahrzeuge in `TAG_SaveData["PlayerVehicles"]`.

Für lebende Fahrzeuge wird ein Datensatz mit folgenden Informationen angelegt:

| Datenfeld | Inhalt |
|---|---|
| `Position` | Position in ATL-Koordinaten |
| `VectorDirAndUp` | Fahrzeugausrichtung und Aufwärtsvektor |
| `Damage` | Gesamtschaden |
| `HitPoints` | Einzelne Trefferpunkt-Schäden |
| `Fuel` | Treibstoffstand |
| `TurretMagazines` | Turmmagazine einschließlich Turmpfad und Restmunition |
| `PylonMagazines` | Pylonen, Magazin-Klassen und Restmunition |
| `WeaponCargo` | Waffen im Laderaum |
| `MagazineCargo` | Magazine im Laderaum |
| `ItemCargo` | Gegenstände im Laderaum |
| `BackpackCargo` | Rucksäcke im Laderaum |
| `Respawn` | Respawn-Einstellung des Fahrzeugs |
| `Status` | `ACTIVE` |

Bei einem zerstörten Fahrzeug wird der Status auf `DESTROYED` gesetzt. Zusätzlich werden die aktuelle Position und Ausrichtung des Wracks sowie die Respawn-Einstellung gespeichert.

Bereits vorhandene Zustandsdaten bleiben dabei erhalten. Dadurch gehen die zuletzt gespeicherten Informationen über Schaden, Treibstoff, Munition und Inventar nicht allein dadurch verloren, dass das Fahrzeug zerstört wurde.

Anschließend wird die aktualisierte HashMap in `TAG_SaveData` übernommen und der Kampagnenspielstand mit `TAG_fnc_saveCampaign` dauerhaft gespeichert.

### 14.4 Wiederherstellung beim Missionsstart

Die Funktion `TAG_fnc_restorePlayerVehicles` arbeitet mit den bereits registrierten Editor-Fahrzeugen. Sie erzeugt keine neuen Fahrzeugobjekte.

Existiert für ein registriertes Fahrzeug kein gespeicherter Zustand, bleibt das Fahrzeug unverändert, wie es in der Missionsdefinition vorgegeben ist.

Bei vorhandenen Zustandsdaten unterscheidet die Funktion zwischen zerstörten Fahrzeugen ohne Respawn-Freigabe und allen übrigen gültigen Zuständen.

**Zerstörte Fahrzeuge ohne Respawn-Freigabe**

Ist der gespeicherte Status `DESTROYED` und `Respawn` auf `false` gesetzt, wird das Fahrzeug als Wrack wiederhergestellt. Dazu werden die gespeicherte Position und Ausrichtung angewendet, ACE-Cook-off deaktiviert und der Schaden direkt auf `1` gesetzt.

Das Fahrzeug wird nicht repariert und nicht zunächst als intaktes Fahrzeug dargestellt.

**Fahrzeuge mit Respawn-Freigabe und übrige gültige Zustände**

Alle anderen gültigen Zustände werden über den regulären Wiederherstellungspfad verarbeitet. Dazu gehören auch zerstörte Fahrzeuge mit aktivierter Respawn-Freigabe.

Die Funktion stellt Position und Ausrichtung wieder her und wendet anschließend den gespeicherten Schaden, die Trefferpunkt-Schäden, den Treibstoffstand, die Munition und das Laderauminventar an. Die Turmmunition wird anhand der gespeicherten Turmpfade wiederhergestellt; die Pylonenmunition wird über die gespeicherten Pylonendaten gesetzt.

Damit kann ein für Respawn freigegebenes Fahrzeug trotz seines beim letzten Speichern erfassten Zerstörungsstatus wiederhergestellt werden. Maßgeblich bleibt dabei der zugehörige gespeicherte Fahrzeugzustand.

Sind die notwendigen Kerndaten unvollständig oder ungültig, wird die Wiederherstellung abgebrochen und eine Warnung protokolliert. Das Fahrzeug bleibt in diesem Fall unverändert.

### 14.5 Zugehörige Speicherstrukturen und Funktionen

| Struktur oder Funktion | Zweck |
|---|---|
| `TAG_PersistentPlayerVehicles` | Registrierung der persistenten Spielerfahrzeuge einschließlich Respawn-Einstellung |
| `TAG_SaveData["PlayerVehicles"]` | Dauerhaft gespeicherte Fahrzeugzustände |
| `TAG_fnc_registerPlayerVehicles` | Registriert Editor-Fahrzeuge mit dem Präfix `pveh_` |
| `TAG_fnc_savePlayerVehicles` | Speichert Zustand und Zerstörungsstatus |
| `TAG_fnc_restorePlayerVehicles` | Stellt gespeicherte Fahrzeugzustände wieder her |

Die Spielerfahrzeugpersistenz ist für ausgewählte, im Editor platzierte Fahrzeuge vorgesehen. Ihre Objektidentität bleibt über den Editor-Variablennamen erhalten, und ihr Zustand wird in einem separaten Speicherbereich verwaltet. Normale Fahrzeuge werden weiterhin durch das allgemeine Fahrzeugpersistenzsystem behandelt.

## 15. Debugging und zentrale Konfiguration

Das Persistenzframework verfügt über eine zentrale Debug-Konfiguration. Damit können Diagnosemeldungen global oder gezielt für einzelne Funktionsbereiche aktiviert werden. Zusätzlich werden zentrale Präfixe für die Diary-Persistenz definiert und an die Clients verteilt.

### 15.1 Globale Debug-Ausgabe

Die globale Einstellung wird über die Variable `TAG_DebugPersistence` gesteuert.

Standardmäßig ist sie auf `false` gesetzt. Wird sie auf `true` gesetzt, werden alle Debug-Meldungen ausgegeben, die über `TAG_fnc_debugLog` laufen.

Die zentrale Konfiguration wird ausschließlich auf dem Server gesetzt und anschließend mit `publicVariable` veröffentlicht. Clients überschreiben diese serverseitigen Einstellungen nicht.

### 15.2 Funktionsbezogene Debug-Schalter

Zusätzlich zur globalen Einstellung können die Debug-Ausgaben einzelner Funktionsbereiche separat aktiviert werden.

Die Konfiguration erfolgt über die Liste `_debugFunctions` in `TAG_fnc_configurePersistenceDebug`. Jeder Eintrag enthält die Bezeichnung des Log-Bereichs und einen booleschen Schalter.

Beispielsweise lassen sich folgende Bereiche unabhängig voneinander überwachen:

- Kampagnenspeicherung und Autosave
- Spieler- und Spielerfahrzeugpersistenz
- Gruppen- und Fahrzeugpersistenz
- Aufgaben und persistente Trigger
- Respawn-Tickets, Marker und Diary-Einträge

Die Schalter sind standardmäßig deaktiviert. Um einen Bereich gezielt zu untersuchen, wird dessen Eintrag in `_debugFunctions` auf `true` gesetzt. Die entsprechende Einstellung wird unter einer Variablen nach dem Schema `TAG_Debug_<Funktionsname>` gespeichert und vom Server veröffentlicht.

Die globale und die funktionsbezogene Einstellung wirken unabhängig voneinander: Eine Meldung wird ausgegeben, sobald mindestens eine der beiden Einstellungen aktiviert ist.

### 15.3 Einheitliche Log-Ausgabe

Die Funktion `TAG_fnc_debugLog` stellt die zentrale Schnittstelle für Debug-Meldungen bereit.

Sie erwartet zwei Parameter:

| Parameter | Bedeutung |
|---|---|
| `_functionName` | Bezeichnung des Log-Bereichs |
| `_message` | Auszugebende Nachricht |

Ist weder das globale Debugging noch der passende Funktionsschalter aktiviert, wird die Meldung verworfen.

Aktivierte Meldungen erscheinen über `diag_log` im RPT-Protokoll. Sie verwenden das einheitliche Format:

`[PERSISTENCE][DEBUG][Funktionsname] Nachricht`

Dadurch lassen sich Meldungen verschiedener Framework-Bereiche anhand ihrer Kennzeichnung filtern und nachvollziehen.

Die Debug-Ausgabe ersetzt nicht die regulären Fehler- und Warnmeldungen. Direkte `diag_log`-Aufrufe für Fehler und Warnungen werden durch die Debug-Schalter nicht unterdrückt.

### 15.4 Zentrale Diary-Konfiguration

Die Funktion `TAG_fnc_configurePersistence` setzt die zentralen Autosave- und Fahrzeugzustandsintervalle sowie die Präfixe für die Zuordnung von Diary-Einträgen.

| Konfigurationsvariable | Standardwert | Geltungsbereich |
|---|---|---|
| `TAG_AutoSaveInterval` | 300 Sekunden | Allgemeiner Autosave |
| `TAG_VehicleStateInterval` | 60 Sekunden | Erfassung und Speicherung normaler Fahrzeugzustände |
| `TAG_DiaryPrefixPlayer` | `PLAY:` | Einzelner Spieler |
| `TAG_DiaryPrefixGroup` | `GRP:` | Gruppe |
| `TAG_DiaryPrefixSide` | `SIDE:` | Seite |
| `TAG_DiaryPrefixAll` | `ALL:` | Alle Spieler |

Die Intervalle und Präfixe werden zentral auf dem Server definiert und anschließend mit `publicVariable` an die Clients verteilt.

Sie werden bei der Erfassung und Validierung der Diary-Einträge verwendet, um deren vorgesehenen Geltungsbereich anhand des Eintragstitels zu erkennen.

Die Standardwerte sollten mit den Präfixen übereinstimmen, die bei der Erstellung der Diary-Einträge in der Mission verwendet werden. Werden die Präfixe geändert, müssen auch die entsprechenden Einträge in der Mission angepasst werden.

### 15.5 Zugehörige Funktionen und Variablen

| Funktion oder Variable | Zweck |
|---|---|
| `TAG_fnc_configurePersistenceDebug` | Initialisiert und veröffentlicht die Debug-Einstellungen |
| `TAG_fnc_debugLog` | Einheitliche, schaltbare Debug-Ausgabe |
| `TAG_fnc_configurePersistence` | Definiert und veröffentlicht Speicherintervalle und Diary-Präfixe |
| `TAG_AutoSaveInterval` | Intervall des allgemeinen Autosaves in Sekunden |
| `TAG_VehicleStateInterval` | Intervall der Fahrzeugzustandserfassung in Sekunden |
| `TAG_DebugPersistence` | Globale Debug-Einstellung |
| `TAG_Debug_<Funktionsname>` | Funktionsbezogene Debug-Einstellung |
| `TAG_DiaryPrefixPlayer` | Präfix für spielerspezifische Diary-Einträge |
| `TAG_DiaryPrefixGroup` | Präfix für gruppenbezogene Diary-Einträge |
| `TAG_DiaryPrefixSide` | Präfix für seitenbezogene Diary-Einträge |
| `TAG_DiaryPrefixAll` | Präfix für globale Diary-Einträge |

Die zentralen Konfigurationsfunktionen erleichtern damit sowohl die Fehlersuche als auch die einheitliche Steuerung der Diary-Zuordnung. Für den normalen Missionsbetrieb können die Debug-Schalter deaktiviert bleiben; bei der Diagnose einzelner Persistenzbereiche lassen sich die benötigten Meldungen gezielt einschalten.

## 16. Schlusswort – Bugs sind auch nur persistente Features

Glückwunsch! Du hast es bis ans Ende der Dokumentation geschafft. Deine Mission ist hoffentlich persistent, deine Spielstände sind sicher und deine KI hat noch nicht beschlossen, eigene Aufgaben zu erstellen.

Trotz aller Tests gilt: Kein Framework ist frei von Bugs. Manche sind offensichtlich, manche warten drei Missionsneustarts, bevor sie sich zeigen, und manche sind so gut versteckt, dass man sie irgendwann als Feature dokumentiert.

**Wenn du einen Bug findest, behalte ihn nicht für dich – aber bitte auch nicht im Spielstand.**

Sichere dein RPT, dokumentiere den Fehler und finde heraus, warum er auftritt. Denn ein reproduzierbarer Bug ist schon halb behoben. Ein Bug, der sich nicht reproduzieren lässt, ist dagegen vermutlich längst persistent geworden.

Persistiere mit Bedacht – und wenn der Bug bleibt, hat wenigstens die Persistenz funktioniert!

*Happy Persisting!* 🚀

## 17. Bekannte Fehler / weitere Optimierungen notwendig / zukünftige geplante Features

# Fehler - behoben in Version 1.1.1
Achtung: allVariables und Groß-/Kleinschreibung - Bis auf weiteres bis das Framework noch einmal vollständig geprüft wurde Variablen nur aus Kleinbuchstaben formulieren!

allVariables missionNamespace liefert Variablennamen in Kleinbuchstaben zurück. vehicleVarName liefert dagegen den im Eden-Editor hinterlegten Variablennamen mit seiner ursprünglichen Schreibweise.

Da SQF-HashMaps bei String-Schlüsseln zwischen Groß- und Kleinschreibung unterscheiden, kann dies zu Fehlern beim Zugriff auf registrierte Einträge führen.

Beispiel (wurde bereits behoben an dieser Stelle):

Eden-Variablenname: player_alpha_Leader

Rückgabe von allVariables: player_alpha_leader

Rückgabe von vehicleVarName: player_alpha_Leader

Wird bei der Registrierung der Name aus allVariables als HashMap-Schlüssel verwendet, kann ein späterer Zugriff über den Namen aus vehicleVarName fehlschlagen.

Empfehlung: Bei der Registrierung persistenter Einheiten den Variablennamen direkt über vehicleVarName ermitteln und für Registrierung und Zugriff dieselbe Namensquelle verwenden. Bei anderen Verwendungen von allVariables diesen Unterschied berücksichtigen.

--------------------------
# Optimierung
Respawnmarker nach dem Arma internen notwendigen Namensschema respawn_XXX werden aktuell vom Framework nicht erfasst und damit nicht gespeichert. Bis zur Behebung des Fehlverhaltens Respawnmarker am besten über einen Trigger setzen, der nicht persistent ist. KEINE Abhängigkeite von eventuellen persistenten Triggern schaffen, da durch wird der Marker dann zb nicht erzeugt!

Beispiel: createMarker ["respawn_west",getMarkerPos "mrk_persist_respawn_west_01"];

Damit wird der Respawn Punktmarker auf die Position der Kartenmarkierung erzeugt, und das System bleibt funktional. Und die Kartenmarkierung wird nach Auslösen des persistenten Triggers ebenfalls gespeichert.

--------------------------
# Optimierung
Die Speicherung und Wiederherstellung von dynamisch erzeugten Respawn Positionen und dynamisch aktivierten Eden Modulen. Aktuell werden diese nicht gespeichert! Alle Module müssen entweder dauerhauft aktiv sein, oder über nicht persistente Trigger aktiviert werden. Siehe Problematik oben (Respawn Marker)

--------------------------
# Feature
Die Erweiterung der Default Hashmap mit eigenen Werten und Variablen ist ein noch geplantes Feature. Aktuell ist es nur auf eigene Gefahr möglich die TAG_Savedata mit eigenen Daten zu erweitern.

--------------------------
# Optimierung
Erweiterung des Fahrzeug Respawns um Framework interne Funktionalität zum Triggern des Respawns. Aktuell muss hierfür noch paralell das Arma interne System verwendet werden, und unterliegt damit ähnlichen Beschränkungen wie auch die normalen Respawn Marker. Verwendung doppelter Trigger für das dynamische Freischalten von Respawn Punkten während der Mission und der dauerhaften Verfügbarkeit.

## 18. Changelog
10/18/2026 Anpassung fn_registerPlayer.sqf - Anpassung des Variablenscopes auf allUnits. Entfernung der Prüfung auf CAManBase, diese ist nicht mehr notwendig.
