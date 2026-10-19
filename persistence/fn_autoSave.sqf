/*
    Author: Djinn
    Description: Regelmäßige automatische Speicherung der
                 Spieler- und Kampagnenzustände.
*/

if (!isServer) exitWith {};

private _interval = missionNamespace getVariable [
    "TAG_AutoSaveInterval",
    300
];

if (_interval < 1) exitWith {
    diag_log format [
        "[PERSISTENCE] FEHLER: Ungültiges Autosave-Intervall: %1",
        _interval
    ];
};

["autoSave", format [
    "Autosave gestartet | Intervall=%1 Sekunden",
    _interval
]] call TAG_fnc_debugLog;

while {isServer} do {

    sleep _interval;

    if (!isServer) exitWith {};

    ["autoSave", "Autosave-Zyklus gestartet."] call TAG_fnc_debugLog;

    // Aktuelle Zustände besetzter Spielerrollen speichern.
    [] call TAG_fnc_savePlayers;

    // Aktuellen Zustand der Spielerfahrzeuge speichern.
    [] call TAG_fnc_savePlayerVehicles;
    
    // Zustände dynamischer Gruppen speichern
    [] call TAG_fnc_saveDynamicGroups;

    // Respawn Tickets speichern
    [] call TAG_fnc_saveRespawnTickets;

    // Zustände der Marker speichern
    [] call TAG_fnc_saveMarkerStates;

    // Diary Einträge speichern
    [] spawn TAG_fnc_saveDiaryEntries;

    // Abschließende Sicherung aller Kampagnendaten
    [] call TAG_fnc_saveCampaign;

    ["autoSave", "Autosave-Zyklus abgeschlossen."] call TAG_fnc_debugLog;
};
