/*
    Author: Djinn
    Description:
    Erkennt zerstörte persistente Fahrzeuge und speichert
    die Daten für eine spätere Wrack-Wiederherstellung.
*/

if (!isServer) exitWith {};

if (isNil "TAG_PersistentVehicles") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_PersistentVehicles fehlt.";
};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

if (!isNil "TAG_TrackDestroyedVehicles_EHID") exitWith {
    diag_log "[PERSISTENCE] WARNUNG: Fahrzeugüberwachung bereits registriert.";
};

TAG_TrackDestroyedVehicles_EHID = addMissionEventHandler [
    "EntityKilled",
    {
        params ["_killed", "_killer", "_instigator"];

        if (isNil "TAG_SaveData") exitWith {
            diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt im EntityKilled-Handler.";
        };

        private _vehicleID = "";

        {
            if (_y isEqualTo _killed) exitWith {
                _vehicleID = _x;
            };
        } forEach TAG_PersistentVehicles;

        if (_vehicleID isEqualTo "") exitWith {};

        private _destroyed = TAG_SaveData getOrDefault [
            "DestroyedVehicles",
            []
        ];

        if (_vehicleID in _destroyed) exitWith {};

        // Daten des zerstörten Fahrzeugs erfassen
        private _vehicleClass = typeOf _killed;

        private _wreckClass = getText (
            configFile
            >> "CfgVehicles"
            >> _vehicleClass
            >> "wreck"
        );

        private _wreckData = createHashMapFromArray [
            ["VehicleClass", _vehicleClass],
            ["WreckClass", _wreckClass],
            ["Position", getPosATL _killed],
            ["VectorDirAndUp", [
                vectorDir _killed,
                vectorUp _killed
            ]]
        ];

        // Wrackdaten dauerhaft in der Kampagnenstruktur ablegen
        private _wrecks = TAG_SaveData getOrDefault [
            "VehicleWrecks",
            createHashMap
        ];

        _wrecks set [_vehicleID, _wreckData];

        TAG_SaveData set [
            "VehicleWrecks",
            _wrecks
        ];

        // Fahrzeug als zerstört markieren
        _destroyed pushBack _vehicleID;

        TAG_SaveData set [
            "DestroyedVehicles",
            _destroyed
        ];

        // Intakten Fahrzeugzustand entfernen
        private _states = TAG_SaveData getOrDefault [
            "Vehicles",
            createHashMap
        ];

        _states deleteAt _vehicleID;

        TAG_SaveData set [
            "Vehicles",
            _states
        ];

        // Diagnose
        ["trackDestroyedVehicles", format [
            "Wrackdaten gespeichert | ID=%1 | Fahrzeugklasse=%2 | Wrackklasse=%3 | Position=%4",
            _vehicleID,
            _vehicleClass,
            if (_wreckClass isEqualTo "") then {
                "KEINE WRACKKLASSE DEFINIERT"
            } else {
                _wreckClass
            },
            getPosATL _killed
        ]] call TAG_fnc_debugLog;

        if (_wreckClass isEqualTo "") then {
            diag_log format [
                "[PERSISTENCE][WRECK] WARNUNG: Keine Wrackklasse in der Konfiguration gefunden | ID=%1 | Klasse=%2",
                _vehicleID,
                _vehicleClass
            ];
        };

        [] call TAG_fnc_saveCampaign;

        diag_log format [
            "[PERSISTENCE] FAHRZEUG ZERSTÖRT UND WRACKDATEN GESPEICHERT: %1",
            _vehicleID
        ];
    }
];

[
    "trackDestroyedVehicles",
    "Ereignisbasierte Fahrzeugüberwachung gestartet."
] call TAG_fnc_debugLog;