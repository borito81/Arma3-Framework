# Persistenz normaler Weltfahrzeuge

Diese Notiz hält den im aktuellen SQF-Code nachvollziehbaren Ablauf und die bisherigen statischen Prüfungen fest. Sie ersetzt weder das [Projekthandbuch](../../READ_THE_FUCKING_MANUAL.md) noch die Prüfung des Codes. Der Implementierungsstand richtet sich nach den Funktionsdateien.

## Systeme und Registrierung

Normale Weltfahrzeuge werden in `TAG_PersistentVehicles` registriert und unter `TAG_SaveData["Vehicles"]` gespeichert. `TAG_fnc_registerVehicles` vergibt für Editorfahrzeuge IDs im Format `EDEN_<Eden-ID>` und für dynamische Fahrzeuge IDs im Format `DYNVEH_<Nummer>`. Die Registrierung erfasst vorhandene Fahrzeuge und neue Objekte über `EntityCreated`; sie überspringt Fahrzeuge mit einem Variablennamen `pveh_...`. Siehe [fn_registerVehicles.sqf](../../vehicles/fn_registerVehicles.sqf).

Spielerfahrzeuge sind ein getrenntes System: `TAG_fnc_registerPlayerVehicles` und `TAG_fnc_restorePlayerVehicles` verwenden `TAG_SaveData["PlayerVehicles"]`. Die Serverinitialisierung registriert Spielerfahrzeuge und normale Fahrzeuge separat. Siehe [fn_initializeServerPersistence.sqf](../../core/fn_initializeServerPersistence.sqf), [fn_registerPlayerVehicles.sqf](../../playerVehicles/fn_registerPlayerVehicles.sqf) und [fn_restorePlayerVehicles.sqf](../../playerVehicles/fn_restorePlayerVehicles.sqf).

## Wiederherstellungsreihenfolge

Nach der Registrierung normaler Fahrzeuge in `fn_initializeServerPersistence.sqf` ist die aktuelle Reihenfolge:

1. `TAG_fnc_restoreDynamicVehicles` stellt fehlende dynamische Fahrzeuge bereit und registriert sie unter ihrer gespeicherten ID.
2. `TAG_fnc_applyDestroyedVehicles` stellt gespeicherte zerstörte Fahrzeuge als zerstörte Objekte dar.
3. `TAG_fnc_restoreDynamicVehicleCrew` ordnet vorhandene dynamische Einheiten ihren gespeicherten Sitzplätzen zu.
4. `TAG_fnc_applyVehicleStates` wendet gespeicherte Zustände auf registrierte, nicht zerstörte Fahrzeuge an.
5. `TAG_fnc_restorePlayerVehicles` läuft separat für Spielerfahrzeuge.

Editorfahrzeuge sind bereits durch die normale Registrierung in `TAG_PersistentVehicles`; dynamische Fahrzeuge werden vor der Zustandsanwendung wiederhergestellt. `TAG_fnc_applyVehicleStates` liest `Vehicles` und überspringt IDs aus `DestroyedVehicles`. Betroffen sind daher gespeicherte Zustände intakter Editor- und dynamischer Fahrzeuge, nicht Spielerfahrzeuge. Belege: [fn_initializeServerPersistence.sqf](../../core/fn_initializeServerPersistence.sqf), [fn_restoreDynamicVehicles.sqf](../../vehicles/fn_restoreDynamicVehicles.sqf), [fn_applyDestroyedVehicles.sqf](../../vehicles/fn_applyDestroyedVehicles.sqf), [fn_restoreDynamicVehicleCrew.sqf](../../vehicles/fn_restoreDynamicVehicleCrew.sqf), [fn_applyVehicleStates.sqf](../../vehicles/fn_applyVehicleStates.sqf).

## Speichern und Profil-Schreibvorgänge

`TAG_fnc_trackVehicleStates` speichert beim Start sofort und danach alle 60 Sekunden (`TAG_VehicleStateInterval`, durch `TAG_fnc_configurePersistence` gesetzt und veröffentlicht). Der Autosave läuft alle 300 Sekunden (`TAG_AutoSaveInterval`) und ruft `TAG_fnc_saveVehicleStates` nicht zusätzlich auf. Belege: [fn_configurePersistence.sqf](../../core/fn_configurePersistence.sqf), [fn_initializeServerPersistence.sqf](../../core/fn_initializeServerPersistence.sqf), [fn_trackVehicleStates.sqf](../../vehicles/fn_trackVehicleStates.sqf), [fn_autoSave.sqf](../../persistence/fn_autoSave.sqf).

`TAG_fnc_saveVehicleStates` aktualisiert `TAG_SaveData["Vehicles"]` für registrierte, noch existente, lebende und nicht als zerstört markierte Fahrzeuge. Gespeichert werden unter anderem Position, Ausrichtung, Schaden, Trefferpunkte, Kraftstoff, Turm- und Pylonenmunition sowie Fahrzeugcargo. Für `DYNVEH_`-Fahrzeuge wird außerdem `Crew` gespeichert. Nach dem Aktualisieren ruft die Funktion selbst `TAG_fnc_saveCampaign` auf. Beleg: [fn_saveVehicleStates.sqf](../../vehicles/fn_saveVehicleStates.sqf).

`TAG_fnc_saveCampaign` schreibt die gesamte `TAG_SaveData`-HashMap in `missionProfileNamespace` und ruft `saveMissionProfileNamespace` auf ([fn_saveCampaign.sqf](../../persistence/fn_saveCampaign.sqf)). Im Autosave folgt nach den Teilspeicherungen zusätzlich ein abschließender Aufruf. Mehrere Teilspeicherfunktionen rufen `saveCampaign` ebenfalls selbst auf; außerdem gibt es direkte Aufrufe außerhalb des Autosaves, darunter bei Fahrzeugzerstörung. Relevante Aufrufer sind `fn_saveVehicleStates`, `fn_trackDestroyedVehicles`, `fn_savePlayers`, `fn_savePlayerVehicles`, `fn_saveDynamicGroups`, `fn_saveRespawnTickets`, `fn_saveMarkerStates` und `fn_saveDiaryEntries`. Die Aufrufstellen sind im Repository über `TAG_fnc_saveCampaign` nachvollziehbar. Damit ist belegt, dass es mehrere Profil-Schreibpfade gibt; daraus allein folgt kein nachgewiesener Fehler.

## Zerstörung und Wracks

`TAG_fnc_trackDestroyedVehicles` registriert einen Mission-Event-Handler für `EntityKilled`. Ist das getötete Objekt in `TAG_PersistentVehicles`, speichert der Handler `VehicleClass`, `WreckClass`, Position und Ausrichtung unter `TAG_SaveData["VehicleWrecks"]`, trägt die ID in `DestroyedVehicles` ein, entfernt den intakten Zustand aus `Vehicles` und speichert die Kampagnendaten. Siehe [fn_trackDestroyedVehicles.sqf](../../vehicles/fn_trackDestroyedVehicles.sqf).

Bei der Wiederherstellung stellt `TAG_fnc_restoreDynamicVehicles` für zerstörte dynamische IDs anhand der Wrackdaten ein Objekt bereit. `TAG_fnc_applyDestroyedVehicles` setzt Cook-off am Objekt außer Kraft, wendet die gespeicherte Position und Ausrichtung an und setzt dessen Schaden auf `1`. Im geprüften Wiederherstellungscode wird `WreckClass` nicht gelesen; der Ablauf setzt das bereitgestellte Fahrzeugobjekt als zerstört, statt anhand dieses Felds eine separate Wrackklasse zu erzeugen. Siehe [fn_restoreDynamicVehicles.sqf](../../vehicles/fn_restoreDynamicVehicles.sqf) und [fn_applyDestroyedVehicles.sqf](../../vehicles/fn_applyDestroyedVehicles.sqf).

## Bewertung des entfernten doppelten Aufrufs

Der frühere Aufruf von `TAG_fnc_applyVehicleStates` direkt nach `TAG_fnc_restoreDynamicVehicles` wurde entfernt. In der aktuellen Reihenfolge bleibt der Aufruf nach `TAG_fnc_applyDestroyedVehicles` und `TAG_fnc_restoreDynamicVehicleCrew` bestehen. Die Kommentar-Vorbedingung in `fn_restoreDynamicVehicleCrew.sqf` verlangt nicht mehr, dass Fahrzeugzustände bereits angewendet wurden.

Die Entfernung wurde statisch begründet: `applyVehicleStates` überspringt zerstörte IDs; der Crew-Restore liest die gespeicherten Crew-Daten und ändert Besatzungszuweisungen, benötigt laut Funktionskörper aber keine zuvor angewendeten Fahrzeugzustandsfelder. Ein bereits registriertes dynamisches Fahrzeug kann durch `restoreDynamicVehicles` unverändert zurückgegeben werden; seine gespeicherte Position wird dann erst beim verbleibenden Zustandsaufruf gesetzt. Der Crew-Restore fragt diese Position nicht ab, und die Sitzzuweisungen verwenden die Fahrzeug- und Einheitenobjekte sowie gespeicherte Rollen und Sitzpfade.

**Verifikationsstand:** Das ist eine statische Codeprüfung. Die geänderte Reihenfolge und insbesondere das Versetzen eines bereits besetzten, zuvor schon registrierten dynamischen Fahrzeugs wurden nicht im Spiel verifiziert. Es liegen hierzu keine In-Game-Testergebnisse vor.

## Offener Fall: gelöschte dynamische Fahrzeuge

Im geprüften normalen Fahrzeugregistrierungs- und Zerstörungspfad gibt es einen `EntityCreated`-Handler und einen `EntityKilled`-Handler, aber keinen `EntityDeleted`-Handler zur Bereinigung von `TAG_PersistentVehicles` oder `TAG_SaveData["Vehicles"]`. `fn_saveVehicleStates` aktualisiert gespeicherte Einträge für lebende registrierte Fahrzeuge, löscht aber nicht allgemein Einträge für nicht mehr vorhandene Fahrzeuge. Ein zuvor gespeicherter dynamischer Zustand kann daher im Speicherstand verbleiben, wenn das Objekt ohne den üblichen Zerstörungsablauf entfernt wird. Da `fn_restoreDynamicVehicles` gespeicherte, nicht als zerstört markierte `DYNVEH_`-Zustände als fehlende Fahrzeuge wiederherstellt, ist eine spätere Neuerzeugung dieses Objekts ein nachvollziehbares Risiko, kein hier im Spiel bestätigter Fehler.

Offen ist, welche Löschfälle dauerhaftes Entfernen bedeuten sollen und welche erhalten bleiben sollen, sowie wie `EntityDeleted` und `EntityKilled` bei regulärer Zerstörung, Cleanup oder anderen Löschungen zusammenspielen. Eine Bereinigungssemantik oder einen Event-Handler legt diese Dokumentation nicht fest.
