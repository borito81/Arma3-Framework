/*
    Author: Djinn

    Description:
    Speichert den Abschluss eines persistenten Editor-Triggers.

    Parameter:
    0: STRING - Variablenname des Triggers

    Return:
    BOOL - true, wenn der Abschluss neu gespeichert wurde
*/

params [
    ["_triggerName", "", [""]]
];

if (!isServer) exitWith {
    diag_log "[PERSISTENCE][TRIGGER] FEHLER: Abschluss wurde nicht auf dem Server ausgeführt.";
    false
};

if (_triggerName isEqualTo "") exitWith {
    diag_log "[PERSISTENCE][TRIGGER] FEHLER: Leerer Triggername.";
    false
};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE][TRIGGER] FEHLER: TAG_SaveData ist nicht initialisiert.";
    false
};

private _triggerStates = TAG_SaveData getOrDefault [
    "TriggerStates",
    createHashMap
];

if (_triggerStates getOrDefault [_triggerName, false]) exitWith {
    ["completePersistentTrigger", format [
        "Trigger bereits abgeschlossen | Name=%1",
        _triggerName
    ]] call TAG_fnc_debugLog;
    false
};

// Abschluss zuerst setzen und speichern.
_triggerStates set [_triggerName, true];
TAG_SaveData set ["TriggerStates", _triggerStates];

[] call TAG_fnc_saveCampaign;

["completePersistentTrigger", format [
    "Triggerabschluss gespeichert | Name=%1",
    _triggerName
]] call TAG_fnc_debugLog;

true