/*
    Author: Djinn

    Description:
    Lädt die Kampagnendaten.
    Existiert kein Spielstand, wird eine neue
    Standard-SaveData-Struktur erstellt.
*/

private _defaultSaveData = call TAG_fnc_createDefaultSaveData;

TAG_SaveData = missionProfileNamespace getVariable [
    "TAG_SaveData",
    _defaultSaveData
];

["loadCampaign", format [
    "Geladene Ticketdaten | Daten=%1",
    str (TAG_SaveData getOrDefault ["RespawnTickets", createHashMap])
]] call TAG_fnc_debugLog;

["loadCampaign", format [
    "Kampagnendaten geladen | Version=%1",
    TAG_SaveData getOrDefault ["SaveVersion", 1]
]] call TAG_fnc_debugLog;

private _dynamicGroups = TAG_SaveData getOrDefault [
    "DynamicGroups",
    createHashMap
];

[
    "loadCampaign",
    format [
        "Dynamische Gruppen geladen | Anzahl=%1 | IDs=%2",
        count _dynamicGroups,
        str (keys _dynamicGroups)
    ]
] call TAG_fnc_debugLog;