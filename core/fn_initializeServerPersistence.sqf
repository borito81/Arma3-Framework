
/*
    Author: Djinn

    Description:
    Zentralisiert die serverseitige Initialisierung des
    Persistenzframeworks.

    Ablauf:
    1. Grundeinstellungen und Konfiguration laden
    2. Kampagnendaten und gespeicherte Zustände laden
    3. Task-System initialisieren und Daten veröffentlichen
    4. Persistente Objekte und Trigger registrieren
    5. Gespeicherte Weltzustände wiederherstellen
    6. Laufende Überwachung und Autosave starten
    7. Initialisierung abschließen und Clients freigeben

    Ausführung: Server
*/

// Signalisiert, dass die serverseitige Initialisierung noch läuft. Das ist eine Initial Variable nicht verändern!
TAG_PersistenceReady = false;

// =================================================================================================
// 1. Grundeinstellungen
// =================================================================================================

// Intervall für automatische Speicherungen in Sekunden.
TAG_AutoSaveInterval = 30;

// Intervall für die Erfassung des Zustands persistenter Fahrzeuge in Sekunden.
TAG_VehicleStateInterval = 60;


// -------------------------------------------------------------------------------------------------
// Spieler-Loadouts
// -------------------------------------------------------------------------------------------------
// TAG_SaveLoadoutOnDeath = true:
// Das Loadout wird zum Todeszeitpunkt gespeichert.
//
// TAG_RestoreLoadoutOnRespawn = true:
// Das gespeicherte Loadout wird beim Respawn wiederhergestellt.
// Dadurch erhält der Spieler keine zusätzliche Munition oder Ausrüstung
// allein durch den Respawn.
// -------------------------------------------------------------------------------------------------

TAG_SaveLoadoutOnDeath = true;
TAG_RestoreLoadoutOnRespawn = true;


// Grundeinstellungen an Clients veröffentlichen.
publicVariable "TAG_SaveLoadoutOnDeath";
publicVariable "TAG_RestoreLoadoutOnRespawn";
publicVariable "TAG_PersistenceReady";


// =================================================================================================
// 2. Zentrale Konfiguration
// =================================================================================================

// Debug-Ausgaben anhand der zentralen Debug-Konfiguration einrichten.
[] call TAG_fnc_configurePersistenceDebug;

// Allgemeine Einstellungen des Persistenzframeworks laden.
[] call TAG_fnc_configurePersistence;


// =================================================================================================
// 3. Kampagnendaten laden
// =================================================================================================

// Gespeicherte Kampagnendaten in den zentralen Speicher laden.
[] call TAG_fnc_loadCampaign;


// =================================================================================================
// 4. Respawn-Tickets wiederherstellen
// =================================================================================================

// Gespeicherte Respawn-Tickets aus den Kampagnendaten auslesen.
private _savedTickets = TAG_SaveData getOrDefault [
    "RespawnTickets",
    createHashMap
];

// Ticket-Zustände im Respawn-System wiederherstellen.
[_savedTickets] call TAG_fnc_restoreRespawnTickets;


// =================================================================================================
// 5. Task-System initialisieren
// =================================================================================================

// Task-Definitionen registrieren und mit dem gespeicherten
// Task-Register abgleichen.
[] call TAG_fnc_registerTaskDefinitions;
[] call TAG_fnc_syncTaskRegistry;

// Anzahl der veröffentlichten Task-Definitionen protokollieren.
["initializeServerPersistence", format [
    "Task-Definitionen veröffentlicht | Anzahl=%1",
    count TAG_TaskDefinitions
]] call TAG_fnc_debugLog;

// Anzahl der veröffentlichten Task-Zustände protokollieren.
["initializeServerPersistence", format [
    "Initiale Task-Daten veröffentlicht | Anzahl=%1",
    count TAG_TaskStates
]] call TAG_fnc_debugLog;

// =================================================================================================
// 6. Persistente Objekte und Trigger registrieren
// =================================================================================================

// Persistente Editor-Trigger frühzeitig registrieren.
[] call TAG_fnc_registerPersistentTriggers;

// Spieler für die spielerbezogene Persistenz registrieren.
[] call TAG_fnc_registerPlayers;

// Spielerfahrzeuge getrennt von normalen persistenten Fahrzeugen registrieren.
[] call TAG_fnc_registerPlayerVehicles;

// Persistente Gruppen registrieren.
[] call TAG_fnc_registerGroups;

// Normale persistente Fahrzeuge registrieren.
[] call TAG_fnc_registerVehicles;


// =================================================================================================
// 7. Gespeicherte Weltzustände wiederherstellen
// =================================================================================================

// Gruppen wiederherstellen
[] call TAG_fnc_applyDestroyedGroups;
[] call TAG_fnc_restoreDynamicGroups;

// Dynamische Fahrzeuge erstellen und Zustände anwenden
[] call TAG_fnc_restoreDynamicVehicles;
[] call TAG_fnc_applyVehicleStates;

// Zerstörte Fahrzeuge als Wracks wiederherstellen
[] call TAG_fnc_applyDestroyedVehicles;

// Besatzung erst nach der Fahrzeugwiederherstellung zuweisen
[] call TAG_fnc_restoreDynamicVehicleCrew;

// Gespeicherte Zustände bestehender Fahrzeuge wiederherstellen.
[] call TAG_fnc_applyVehicleStates;

// Gespeicherte Spielerfahrzeuge wiederherstellen.
[] call TAG_fnc_restorePlayerVehicles;

// Gespeicherte Markerzustände wiederherstellen.
[] call TAG_fnc_restoreMarkerStates;


// =================================================================================================
// 8. Laufende Überwachung und Autosave starten
// =================================================================================================

// Zerstörte Gruppen und Fahrzeuge anhand ihrer Ereignisse überwachen.
[] call TAG_fnc_trackDestroyedGroups;
[] call TAG_fnc_trackDestroyedVehicles;

// Fahrzeugzustände fortlaufend erfassen.
[] spawn TAG_fnc_trackVehicleStates;

// Automatische Speicherung der Kampagnendaten starten.
[] spawn TAG_fnc_autoSave;


// =================================================================================================
// 9. Initialisierung abschließen
// =================================================================================================

// Erst jetzt signalisieren, dass die serverseitige Initialisierung
// abgeschlossen ist und Clients ihre Zustände anfordern dürfen.
TAG_PersistenceReady = true;
publicVariable "TAG_PersistenceReady";

diag_log "[PERSISTENCE] Initialisierung abgeschlossen. Spieler können ihre Zustände anfordern.";
