
/*
    Author: Djinn

    Description:
    Regelmäßige Sicherung der Fahrzeugzustände.
    Das Speicherintervall wird zentral konfiguriert.
*/

if (!isServer) exitWith {};

private _interval = missionNamespace getVariable [
    "TAG_VehicleStateInterval",
    60
];

if (_interval < 1) exitWith {
    diag_log format [
        "[PERSISTENCE] FEHLER: Ungültiges Fahrzeugzustands-Intervall: %1",
        _interval
    ];
};

["trackVehicleStates", format [
    "Fahrzeugüberwachung gestartet | Intervall=%1 Sekunden",
    _interval
]] call TAG_fnc_debugLog;

// Beim Start sofort den aktuellen Fahrzeugzustand speichern.
[] call TAG_fnc_saveVehicleStates;

// Anschließend regelmäßig speichern.
while {isServer} do {
    sleep _interval;

    if (!isServer) exitWith {};

    [] call TAG_fnc_saveVehicleStates;
};
