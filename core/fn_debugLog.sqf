/*
    Author: Djinn

    Description:
    Zentrale Debug-Ausgabe der Persistenz.
    Globales oder funktionsbezogenes Debugging.
*/

params [
    ["_functionName", "", [""]],
    ["_message", "", [""]]
];

if (_functionName isEqualTo "") exitWith {};

private _globalDebug = missionNamespace getVariable [
    "TAG_DebugPersistence",
    false
];

private _functionDebug = missionNamespace getVariable [
    format ["TAG_Debug_%1", _functionName],
    false
];

// Ausgeben, wenn global ODER für diese Funktion aktiviert.
if !(_globalDebug || _functionDebug) exitWith {};

diag_log format [
    "[PERSISTENCE][DEBUG][%1] %2",
    _functionName,
    _message
];