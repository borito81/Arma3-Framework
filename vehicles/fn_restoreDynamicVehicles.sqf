
/*
    Author: Djinn

    Description:
    Erstellt fehlende dynamische Fahrzeuge anhand des Spielstands
    und registriert sie unter ihrer gespeicherten ID.

    Überlebende Fahrzeuge:
    - Klasse und Position aus Vehicles
    - Der restliche Zustand wird durch fn_applyVehicleStates
      wiederhergestellt.

    Zerstörte Fahrzeuge:
    - Fahrzeugklasse und Position aus VehicleWrecks
    - Das Wrack wird anschließend durch fn_applyDestroyedVehicles
      wiederhergestellt.

    IDs:
    DYNVEH_<laufende-ID>

    Editor-Fahrzeuge und Spielerfahrzeuge bleiben unverändert.
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

if (isNil "TAG_PersistentVehicles") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_PersistentVehicles fehlt.";
};


private _states = TAG_SaveData getOrDefault [
    "Vehicles",
    createHashMap
];

private _destroyed = TAG_SaveData getOrDefault [
    "DestroyedVehicles",
    []
];

private _wrecks = TAG_SaveData getOrDefault [
    "VehicleWrecks",
    createHashMap
];


private _createdVehicles = 0;
private _registeredVehicles = 0;


// Prüfen, ob eine ID zu einem dynamischen Fahrzeug gehört.

private _isDynamicVehicleID = {
    params ["_vehicleID"];

    _vehicleID isEqualType ""
    && {
        (count _vehicleID) > 7
    }
    && {
        (_vehicleID select [0, 7]) isEqualTo "DYNVEH_"
    }
};


// Hilfsfunktion zum Erzeugen und Registrieren eines Fahrzeugs.

private _createAndRegisterVehicle = {
    params [
        "_vehicleID",
        "_class",
        "_position",
        "_vectors"
    ];


    // Existiert das Fahrzeug bereits unter dieser ID,
    // wird kein zweites Objekt erzeugt.

    private _vehicle = TAG_PersistentVehicles getOrDefault [
        _vehicleID,
        objNull
    ];

    if (!isNull _vehicle) exitWith {

        _vehicle setVariable [
            "TAG_DynamicVehicleID",
            _vehicleID
        ];

        _vehicle setVariable [
            "TAG_PersistentVehicleID",
            _vehicleID
        ];

        _vehicle
    };


    // Ungültige oder nicht verfügbare Fahrzeugklassen ausschließen.

    if (
        _class isEqualTo ""
        || {
            !isClass (
                configFile
                >> "CfgVehicles"
                >> _class
            )
        }
    ) exitWith {

        diag_log format [
            "[PERSISTENCE] FEHLER: Dynamisches Fahrzeug nicht erzeugt | ID=%1 | Klasse=%2",
            _vehicleID,
            _class
        ];

        objNull
    };


    // Ungültige Positionsdaten abfangen.

    if (
        !(_position isEqualType [])
        || { count _position < 2 }
    ) then {
        _position = [0, 0, 0];
    };


    // EntityCreated darf für dieses Objekt keine neue ID vergeben.

    private _wasSuppressed = missionNamespace getVariable [
        "TAG_RegisterVehicles_SuppressEntityCreated",
        false
    ];

    missionNamespace setVariable [
        "TAG_RegisterVehicles_SuppressEntityCreated",
        true
    ];

    _vehicle = createVehicle [
        _class,
        _position,
        [],
        0,
        "CAN_COLLIDE"
    ];

    // Vorherigen Zustand wiederherstellen.

    missionNamespace setVariable [
        "TAG_RegisterVehicles_SuppressEntityCreated",
        _wasSuppressed
    ];


    if (isNull _vehicle) exitWith {

        diag_log format [
            "[PERSISTENCE] FEHLER: createVehicle fehlgeschlagen | ID=%1 | Klasse=%2",
            _vehicleID,
            _class
        ];

        objNull
    };


    // Gespeicherte Position und Ausrichtung anwenden.

    _vehicle setPosATL _position;

    if (
        _vectors isEqualType []
        && { count _vectors isEqualTo 2 }
    ) then {
        _vehicle setVectorDirAndUp _vectors;
    };


    // Gespeicherte ID am Objekt hinterlegen.

    _vehicle setVariable [
        "TAG_DynamicVehicleID",
        _vehicleID
    ];

    _vehicle setVariable [
        "TAG_PersistentVehicleID",
        _vehicleID
    ];


    // In der zentralen Registrierung aufnehmen.

    TAG_PersistentVehicles set [
        _vehicleID,
        _vehicle
    ];


    _createdVehicles = _createdVehicles + 1;


    [
        "restoreDynamicVehicles",
        format [
            "Dynamisches Fahrzeug erzeugt und registriert | ID=%1 | Klasse=%2 | Position=%3",
            _vehicleID,
            _class,
            _position
        ]
    ] call TAG_fnc_debugLog;


    _vehicle
};


// Überlebende dynamische Fahrzeuge erzeugen.

{
    private _vehicleID = _x;
    private _state = _y;

    if (
        [_vehicleID] call _isDynamicVehicleID
        && { !(_vehicleID in _destroyed) }
    ) then {

        private _class = _state getOrDefault [
            "Class",
            ""
        ];

        private _position = _state getOrDefault [
            "Position",
            [0, 0, 0]
        ];

        private _vectors = _state getOrDefault [
            "VectorDirAndUp",
            [[0, 1, 0], [0, 0, 1]]
        ];

        private _vehicle = [
            _vehicleID,
            _class,
            _position,
            _vectors
        ] call _createAndRegisterVehicle;


        if (!isNull _vehicle) then {
            _registeredVehicles = _registeredVehicles + 1;
        };
    };

} forEach _states;


// Zerstörte dynamische Fahrzeuge zur späteren Wrack-Wiederherstellung
// erzeugen. Das eigentliche Zerstören übernimmt fn_applyDestroyedVehicles.

{
    private _vehicleID = _x;

    if ([_vehicleID] call _isDynamicVehicleID) then {

        private _wreckData = _wrecks getOrDefault [
            _vehicleID,
            createHashMap
        ];

        if (_wreckData isEqualTo createHashMap) then {

            diag_log format [
                "[PERSISTENCE] WARNUNG: Keine Wrackdaten für dynamisches Fahrzeug vorhanden | ID=%1",
                _vehicleID
            ];

        } else {

            private _class = _wreckData getOrDefault [
                "VehicleClass",
                ""
            ];

            private _position = _wreckData getOrDefault [
                "Position",
                [0, 0, 0]
            ];

            private _vectors = _wreckData getOrDefault [
                "VectorDirAndUp",
                [[0, 1, 0], [0, 0, 1]]
            ];

            private _vehicle = [
                _vehicleID,
                _class,
                _position,
                _vectors
            ] call _createAndRegisterVehicle;


            if (!isNull _vehicle) then {

                _registeredVehicles = _registeredVehicles + 1;

                [
                    "restoreDynamicVehicles",
                    format [
                        "Dynamisches Fahrzeug für Wrack-Wiederherstellung bereitgestellt | ID=%1 | Klasse=%2",
                        _vehicleID,
                        _class
                    ]
                ] call TAG_fnc_debugLog;
            };
        };
    };

} forEach _destroyed;


[
    "restoreDynamicVehicles",
    format [
        "Fahrzeugvorbereitung abgeschlossen | Erzeugt=%1 | Verfügbar=%2",
        _createdVehicles,
        _registeredVehicles
    ]
] call TAG_fnc_debugLog;
