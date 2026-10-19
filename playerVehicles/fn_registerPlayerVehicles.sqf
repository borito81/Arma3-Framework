/*
    Author: Djinn

    Description:
    Registriert persistente Spielerfahrzeuge anhand ihres
    Editor-Variablennamens mit dem Präfix "pveh_".

    Die Respawn-Konfiguration wird über die Variable
    "pveh_respawn" am Fahrzeugobjekt ausgelesen.

    Ausführung: Server
*/

if (!isServer) exitWith {};

// Registrierung initialisieren.
TAG_PersistentPlayerVehicles = createHashMap;

{
    private _varName = _x;

    // Nur Variablennamen mit dem Präfix "pveh_" berücksichtigen.
    if ((_varName select [0, 5]) isEqualTo "pveh_") then {

        private _vehicle = missionNamespace getVariable [
            _varName,
            objNull
        ];

        // Nur gültige Fahrzeuge registrieren.
        if (
            !isNull _vehicle
            && {_vehicle isKindOf "AllVehicles"}
            && {!(_vehicle isKindOf "Man")}
        ) then {

            // Respawn-Konfiguration aus dem Fahrzeug auslesen.
            private _respawn = _vehicle getVariable [
                "pveh_respawn",
                false
            ];

            TAG_PersistentPlayerVehicles set [
                _varName,
                createHashMapFromArray [
                    ["Vehicle", _vehicle],
                    ["Respawn", _respawn isEqualTo true]
                ]
            ];

            ["registerPlayerVehicles", format [
                "Fahrzeug registriert | ID=%1 | Klasse=%2 | Respawn=%3",
                _varName,
                typeOf _vehicle,
                _respawn isEqualTo true
            ]] call TAG_fnc_debugLog;
        };
    };
} forEach allVariables missionNamespace;

["registerPlayerVehicles", format [
    "Registrierung abgeschlossen | Anzahl=%1",
    count TAG_PersistentPlayerVehicles
]] call TAG_fnc_debugLog;