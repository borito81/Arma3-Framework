/*
    Author: Djinn

    Description:
    Speichert die vollständigen Kampagnendaten
    im Mission Profile Namespace.
*/

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData existiert nicht. Speichern abgebrochen.";
};

missionProfileNamespace setVariable [
    "TAG_SaveData",
    TAG_SaveData
];

saveMissionProfileNamespace;

["saveCampaign", "Kampagnendaten gespeichert."] call TAG_fnc_debugLog;