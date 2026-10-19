
/*
    Author: Djinn

    Description:
    Registriert persistente Editor- und dynamische Fahrzeuge.

    Editor-Fahrzeuge:
    EDEN_<Eden-ID>

    Dynamische Fahrzeuge:
    DYNVEH_<laufende-ID>

    Spielerfahrzeuge mit dem Präfix pveh_ werden weiterhin
    ausschließlich durch das separate Spielerfahrzeugsystem verwaltet.

    Dynamische IDs werden aus gespeicherten Fahrzeugzuständen,
    Wrackdaten und zerstörten Fahrzeugen abgeleitet, damit bereits
    vergebene IDs nach einem Missionsneustart nicht erneut vergeben
    werden.
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};


// Vorhandenen Event Handler bei erneuter Registrierung entfernen.

if (!isNil "TAG_RegisterVehicles_EntityCreated_EHID") then {
    removeMissionEventHandler [
        "EntityCreated",
        TAG_RegisterVehicles_EntityCreated_EHID
    ];

    TAG_RegisterVehicles_EntityCreated_EHID = nil;
};


// Registrierung initialisieren.

TAG_PersistentVehicles = createHashMap;


// Bereits vergebene dynamische IDs aus dem Spielstand berücksichtigen.

private _savedStates = TAG_SaveData getOrDefault [
    "Vehicles",
    createHashMap
];

private _savedWrecks = TAG_SaveData getOrDefault [
    "VehicleWrecks",
    createHashMap
];

private _destroyedVehicles = TAG_SaveData getOrDefault [
    "DestroyedVehicles",
    []
];

private _knownIDs = keys _savedStates;

_knownIDs append (keys _savedWrecks);
_knownIDs append _destroyedVehicles;


private _nextDynamicID = missionNamespace getVariable [
    "TAG_DynamicVehicleCounter",
    1
];


{
    private _id = _x;

    if (
        _id isEqualType ""
        && {
            (count _id) > 7
        }
        && {
            (_id select [0, 7]) isEqualTo "DYNVEH_"
        }
    ) then {

        private _number = parseNumber (
            _id select [7]
        );

        if (_number >= _nextDynamicID) then {
            _nextDynamicID = floor _number + 1;
        };
    };

} forEach _knownIDs;


TAG_DynamicVehicleCounter = _nextDynamicID;


// Zentrale Hilfsfunktion für die Registrierung einzelner Fahrzeuge.

TAG_RegisterVehicles_RegisterSingle = {
    params ["_vehicle"];

    if (isNull _vehicle) exitWith {};

    if !(_vehicle isKindOf "AllVehicles") exitWith {};
    if (_vehicle isKindOf "Man") exitWith {};
    if (_vehicle isKindOf "WeaponHolderSimulated") exitWith {};


    private _variableName = vehicleVarName _vehicle;


    // Spielerfahrzeuge bleiben im separaten System.

    if (
        (count _variableName) >= 5
        && {
            (_variableName select [0, 5]) isEqualTo "pveh_"
        }
    ) exitWith {

        [
            "registerVehicles",
            format [
                "Fahrzeug übersprungen | Variablenname=%1 | Grund=Spielerfahrzeugsystem",
                _variableName
            ]
        ] call TAG_fnc_debugLog;
    };


    private _edenID = get3DENEntityID _vehicle;
    private _vehicleID = "";
    private _source = "";


    // Editor-Fahrzeuge erhalten ihre stabile Eden-ID.

    if (_edenID >= 0) then {

        _vehicleID = format [
            "EDEN_%1",
            _edenID
        ];

        _source = "Editor";

    } else {

        // Dynamische Fahrzeuge erhalten eine eigene persistente ID.

        private _dynamicID = _vehicle getVariable [
            "TAG_DynamicVehicleID",
            ""
        ];

        private _hasDynamicID = (
            (count _dynamicID) > 7
            && {
                (_dynamicID select [0, 7]) isEqualTo "DYNVEH_"
            }
        );


        if (!_hasDynamicID) then {

            _dynamicID = format [
                "DYNVEH_%1",
                TAG_DynamicVehicleCounter
            ];

            TAG_DynamicVehicleCounter =
                TAG_DynamicVehicleCounter + 1;

        } else {

            // Bereits vergebene IDs berücksichtigen.

            private _number = parseNumber (
                _dynamicID select [7]
            );

            TAG_DynamicVehicleCounter = TAG_DynamicVehicleCounter max (
                floor _number + 1
            );
        };


        _vehicleID = _dynamicID;
        _source = "Dynamisch";


        _vehicle setVariable [
            "TAG_DynamicVehicleID",
            _vehicleID
        ];
    };


    // Bereits belegte Schlüssel dürfen kein anderes Fahrzeug überschreiben.

    private _registeredVehicle = TAG_PersistentVehicles getOrDefault [
        _vehicleID,
        objNull
    ];

    if (
        !isNull _registeredVehicle
        && { !(_registeredVehicle isEqualTo _vehicle) }
    ) then {

        if (_source isEqualTo "Dynamisch") then {

            private _previousID = _vehicleID;

            _vehicleID = format [
                "DYNVEH_%1",
                TAG_DynamicVehicleCounter
            ];

            while {
                !isNull (
                    TAG_PersistentVehicles getOrDefault [
                        _vehicleID,
                        objNull
                    ]
                )
            } do {

                TAG_DynamicVehicleCounter =
                    TAG_DynamicVehicleCounter + 1;

                _vehicleID = format [
                    "DYNVEH_%1",
                    TAG_DynamicVehicleCounter
                ];
            };

            TAG_DynamicVehicleCounter =
                TAG_DynamicVehicleCounter + 1;

            _vehicle setVariable [
                "TAG_DynamicVehicleID",
                _vehicleID
            ];

            [
                "registerVehicles",
                format [
                    "Dynamische ID-Kollision korrigiert | AlteID=%1 | NeueID=%2",
                    _previousID,
                    _vehicleID
                ]
            ] call TAG_fnc_debugLog;

        } else {

            diag_log format [
                "[PERSISTENCE] FEHLER: Doppelte Eden-Fahrzeug-ID | ID=%1 | Klasse=%2",
                _vehicleID,
                typeOf _vehicle
            ];

            _vehicleID = "";
        };
    };


    if (_vehicleID isEqualTo "") exitWith {};


    // Allgemeine ID für nachfolgende Persistenzfunktionen am Objekt ablegen.

    _vehicle setVariable [
        "TAG_PersistentVehicleID",
        _vehicleID
    ];


    TAG_PersistentVehicles set [
        _vehicleID,
        _vehicle
    ];


    [
        "registerVehicles",
        format [
            "Fahrzeug registriert | ID=%1 | Quelle=%2 | Klasse=%3 | EdenID=%4 | Variablenname=%5",
            _vehicleID,
            _source,
            typeOf _vehicle,
            _edenID,
            _variableName
        ]
    ] call TAG_fnc_debugLog;
};


// Neue Fahrzeuge automatisch erkennen.

TAG_RegisterVehicles_EntityCreated_EHID = addMissionEventHandler [
    "EntityCreated",
    {
        params ["_entity"];

        if (isNull _entity) exitWith {};

        // Während einer gezielten Wiederherstellung übernimmt
        // die Wiederherstellungsfunktion selbst die Registrierung.

        if (
            missionNamespace getVariable [
                "TAG_RegisterVehicles_SuppressEntityCreated",
                false
            ]
        ) exitWith {};

        [_entity] call TAG_RegisterVehicles_RegisterSingle;
    }
];


// Bereits vorhandene Editor- und dynamische Fahrzeuge registrieren.

{
    [_x] call TAG_RegisterVehicles_RegisterSingle;
} forEach vehicles;


// Abschließende Statistik.

private _registeredIDs = keys TAG_PersistentVehicles;

private _editorCount = {
    (_x select [0, 5]) isEqualTo "EDEN_"
} count _registeredIDs;

private _dynamicCount = {
    (_x select [0, 7]) isEqualTo "DYNVEH_"
} count _registeredIDs;


[
    "registerVehicles",
    format [
        "Fahrzeugregistrierung abgeschlossen | Gesamt=%1 | Editor=%2 | Dynamisch=%3",
        count TAG_PersistentVehicles,
        _editorCount,
        _dynamicCount
    ]
] call TAG_fnc_debugLog;
