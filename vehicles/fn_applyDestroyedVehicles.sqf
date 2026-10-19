/*
    Author: Djinn
    Description:
    Stellt zerstörte persistente Fahrzeuge als Wracks wieder her.
    Position und Ausrichtung werden aus den gespeicherten Wrackdaten
    wiederhergestellt. ACE-Cook-off wird deaktiviert.
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

if (isNil "TAG_PersistentVehicles") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_PersistentVehicles fehlt.";
};

private _destroyed = TAG_SaveData getOrDefault [
    "DestroyedVehicles",
    []
];

private _wrecks = TAG_SaveData getOrDefault [
    "VehicleWrecks",
    createHashMap
];

{
    private _vehicleID = _x;

    private _vehicle = TAG_PersistentVehicles getOrDefault [
        _vehicleID,
        objNull
    ];

    if (!isNull _vehicle) then {

        private _wreckData = _wrecks getOrDefault [
            _vehicleID,
            createHashMap
        ];

        // ACE-Cook-off vor der Zerstörung deaktivieren
        _vehicle setVariable ["ace_cookoff_enable", false, true];

        // Gespeicherte Position und Ausrichtung anwenden
        if !(_wreckData isEqualTo createHashMap) then {

            private _position = _wreckData getOrDefault [
                "Position",
                getPosATL _vehicle
            ];

            private _vectors = _wreckData getOrDefault [
                "VectorDirAndUp",
                [vectorDir _vehicle, vectorUp _vehicle]
            ];

            _vehicle setPosATL _position;
            _vehicle setVectorDirAndUp _vectors;

            ["applyDestroyedVehicles", format [
                "Wrackposition wiederhergestellt | ID=%1 | Position=%2 | Ausrichtung=%3",
                _vehicleID,
                _position,
                _vectors
            ]] call TAG_fnc_debugLog;

        } else {
            diag_log format [
                "[PERSISTENCE][WRECK] WARNUNG: Keine Wrackdaten vorhanden; bestehende Position bleibt erhalten | ID=%1",
                _vehicleID
            ];
        };

        // Fahrzeug direkt als Wrack wiederherstellen
        _vehicle setDamage [1, false];

        ["applyDestroyedVehicles", format [
            "Wrack wiederhergestellt | ID=%1 | Klasse=%2 | Schaden=%3",
            _vehicleID,
            typeOf _vehicle,
            damage _vehicle
        ]] call TAG_fnc_debugLog;

    } else {
        diag_log format [
            "[PERSISTENCE] WARNUNG: Zerstörtes Fahrzeug nicht gefunden: %1",
            _vehicleID
        ];
    };

} forEach _destroyed;