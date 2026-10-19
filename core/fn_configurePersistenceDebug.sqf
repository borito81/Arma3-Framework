/*
    Author: Djinn

    Description:
    Zentrale Debug-Konfiguration der Persistenz.
    Der Server setzt und veröffentlicht die Einstellungen.
    Clients überschreiben keine vom Server gesetzten Werte.
*/

// Globale Einstellung ausschließlich auf dem Server initialisieren.
if (isServer) then {
    TAG_DebugPersistence = false;
};

private _debugFunctions = [
    // Core Funktionen
    ["initializeServerPersistence", false],
    ["initializePlayerPersistence", false],
    ["onPlayerKilled", false],
    ["onPlayerRespawn", false],

    // Spielerfahrzeuge
    ["savePlayerVehicles", false],
    ["restorePlayerVehicles", false],
    ["registerPlayerVehicles", false],

    // Kampagnenspeicherung
    ["saveCampaign", false],
    ["loadCampaign", false],
    ["autoSave", false],

    // Spieler
    ["registerPlayers", true],
    ["requestRestorePlayer", true],
    ["restorePlayer", true],
    ["savePlayerDeathLoadout", true],
    ["savePlayers", true],

    // Weltfahrzeuge
    ["registerVehicles", false],
    ["saveVehicleStates", false],
    ["applyVehicleStates", false],
    ["trackVehicleStates", false],
    ["applyDestroyedVehicles", false],
    ["trackDestroyedVehicles", false],
    ["restoreDynamicVehicles", false],

    // Gruppen
    ["registerGroups", false],
    ["saveDynamicGroups", false],
    ["applyDestroyedGroups", false],
    ["restoreDynamicGroups", false],
    ["trackDestroyedGroups", false],

    // Marker
    ["saveMarkerStates", false],
    ["restoreMarkerStates", false],

    // Aufgaben
    ["registerTaskDefinition", false],
    ["registerTaskDefinitions", false],
    ["syncTaskRegistry", false],
    ["reportTaskState", false],
    ["restoreTaskStates", false],
    ["trackTaskStates", false],

    // Persistente Trigger
    ["completePersistentTrigger", false],
    ["registerPersistentTriggers", false],

    // Respawn-Tickets
    ["saveRespawnTickets", false],
    ["restoreRespawnTickets", false],

    // Diary-Speicherung und Wiederherstellung
    ["saveDiaryEntries", false],
    ["collectDiaryEntries", false],
    ["reportDiaryEntries", false],
    ["sendDiaryRestore", false],
    ["applyDiaryEntries", false]
];

// Nur der Server setzt die Funktionsschalter.
if (isServer) then {
    {
        _x params ["_functionName", "_enabled"];

        missionNamespace setVariable [
            format ["TAG_Debug_%1", _functionName],
            _enabled
        ];
    } forEach _debugFunctions;

    // Konfiguration veröffentlichen.
    publicVariable "TAG_DebugPersistence";

    {
        _x params ["_functionName"];

        publicVariable format [
            "TAG_Debug_%1",
            _functionName
        ];
    } forEach _debugFunctions;
};