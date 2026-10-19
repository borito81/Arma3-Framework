
/*
    Author: Djinn

    Description:
    Registriert persistente KI-Gruppen anhand ihrer Side
    und ihres Callsigns.

    Vorhandene Gruppen werden über allGroups registriert.
    Neue Gruppen werden über GroupCreated erkannt.

    Gruppen, die Spielereinheiten enthalten, werden
    nicht als persistente KI-Gruppen verwaltet.

    Dynamische Fahrzeugbesatzungen werden nach der
    Einheiten-Erzeugung zusätzlich erkannt.

    Gruppen-ID:
    <SIDE>_<CALLSIGN>
*/

if (!isServer) exitWith {};

TAG_PersistentGroups = createHashMap;
TAG_DynamicGroups = createHashMap;

[
    "registerGroups",
    "Registrierung gestartet; HashMap erstellt."
] call TAG_fnc_debugLog;


// Vorhandene Event Handler bei erneuter Registrierung entfernen.

if (!isNil "TAG_RegisterGroups_GroupCreated_EHID") then {
    removeMissionEventHandler [
        "GroupCreated",
        TAG_RegisterGroups_GroupCreated_EHID
    ];

    TAG_RegisterGroups_GroupCreated_EHID = nil;
};

if (!isNil "TAG_RegisterGroups_EntityCreated_EHID") then {
    removeMissionEventHandler [
        "EntityCreated",
        TAG_RegisterGroups_EntityCreated_EHID
    ];

    TAG_RegisterGroups_EntityCreated_EHID = nil;
};


// Lokale Hilfsfunktion für die Gruppenregistrierung.

private _registerGroupIfEligible = {
    params ["_group"];

    if (isNull _group) exitWith {};

    private _groupID = format [
        "%1_%2",
        side _group,
        groupId _group
    ];

    private _hasPlayer = (units _group) findIf {
        isPlayer _x
    } >= 0;

    if (_hasPlayer) exitWith {

        TAG_PersistentGroups deleteAt _groupID;
        TAG_DynamicGroups deleteAt _groupID;

        [
            "registerGroups",
            format [
                "Gruppe ausgeschlossen | ID=%1 | Grund=Spielereinheit enthalten",
                _groupID
            ]
        ] call TAG_fnc_debugLog;
    };

    TAG_PersistentGroups set [
        _groupID,
        _group
    ];

    [
        "registerGroups",
        format [
            "Gruppe registriert | ID=%1 | Einheiten=%2",
            _groupID,
            count units _group
        ]
    ] call TAG_fnc_debugLog;
};


// Neue Gruppen erkennen.

TAG_RegisterGroups_GroupCreated_EHID = addMissionEventHandler [
    "GroupCreated",
    {
        params ["_group"];

        if (isNull _group) exitWith {};

        // Während der gezielten Wiederherstellung keine
        // vorläufige Registrierung anhand der automatisch
        // vergebenen Gruppen-ID durchführen.

        if (
            missionNamespace getVariable [
                "TAG_RegisterGroups_SuppressGroupCreated",
                false
            ]
        ) exitWith {};

        private _groupID = format [
            "%1_%2",
            side _group,
            groupId _group
        ];

        TAG_PersistentGroups set [
            _groupID,
            _group
        ];

        TAG_DynamicGroups set [
            _groupID,
            _group
        ];

        [
            "registerGroups",
            format [
                "Dynamische Gruppe registriert | ID=%1 | Einheiten=%2",
                _groupID,
                count units _group
            ]
        ] call TAG_fnc_debugLog;
    }
];


// Einheiten-Erzeugung überwachen.
//
// Spielergruppen werden weiterhin ausgeschlossen.
// Besatzungen dynamischer Fahrzeuge werden nach kurzer Verzögerung
// geprüft, wenn Einheit und Fahrzeug bereits zugeordnet sein sollten.

TAG_RegisterGroups_EntityCreated_EHID = addMissionEventHandler [
    "EntityCreated",
    {
        params ["_entity"];

        if (isNull _entity) exitWith {};
        if !(_entity isKindOf "CAManBase") exitWith {};


        // Spielergruppen ausschließen.

        if (isPlayer _entity) exitWith {

            private _group = group _entity;

            if (isNull _group) exitWith {};

            private _groupID = format [
                "%1_%2",
                side _group,
                groupId _group
            ];

            TAG_PersistentGroups deleteAt _groupID;
            TAG_DynamicGroups deleteAt _groupID;

            [
                "registerGroups",
                format [
                    "Spielergruppe ausgeschlossen | ID=%1",
                    _groupID
                ]
            ] call TAG_fnc_debugLog;
        };


        // Prüfung nach der Einheiten-Erzeugung ausführen.

        [_entity] spawn {
            params ["_unit"];

            sleep 0.25;

            if (isNull _unit) exitWith {};
            if (isPlayer _unit) exitWith {};

            private _group = group _unit;

            if (isNull _group) exitWith {};


            // Nur Besatzungen dynamischer Fahrzeuge behandeln.

            private _vehicle = vehicle _unit;

            if (_vehicle isEqualTo _unit) exitWith {};


            private _vehicleID = _vehicle getVariable [
                "TAG_DynamicVehicleID",
                ""
            ];

            if (
                !(_vehicleID isEqualType "")
                || {
                    (count _vehicleID) < 7
                }
                || {
                    (_vehicleID select [0, 7]) isNotEqualTo "DYNVEH_"
                }
            ) exitWith {};


            // Gruppen mit Spielereinheiten nicht verwalten.

            private _hasPlayer = (units _group) findIf {
                isPlayer _x
            } >= 0;

            if (_hasPlayer) exitWith {

                private _playerGroupID = format [
                    "%1_%2",
                    side _group,
                    groupId _group
                ];

                TAG_PersistentGroups deleteAt _playerGroupID;
                TAG_DynamicGroups deleteAt _playerGroupID;

                [
                    "registerGroups",
                    format [
                        "Fahrzeugbesatzung ausgeschlossen | Fahrzeug=%1 | Gruppe=%2 | Grund=Spielereinheit enthalten",
                        _vehicleID,
                        _playerGroupID
                    ]
                ] call TAG_fnc_debugLog;
            };


            // Aktuelle Gruppen-ID bestimmen.

            private _groupID = format [
                "%1_%2",
                side _group,
                groupId _group
            ];


            // Prüfen, ob die gewünschte ID bereits einer
            // anderen Gruppe zugeordnet ist.

            private _dynamicAtID = TAG_DynamicGroups getOrDefault [
                _groupID,
                grpNull
            ];

            private _persistentAtID = TAG_PersistentGroups getOrDefault [
                _groupID,
                grpNull
            ];

            if (
                (
                    !isNull _dynamicAtID
                    && {
                        !(_dynamicAtID isEqualTo _group)
                    }
                )
                || {
                    !isNull _persistentAtID
                    && {
                        !(_persistentAtID isEqualTo _group)
                    }
                }
            ) exitWith {

                diag_log format [
                    "[PERSISTENCE] FEHLER: Gruppen-ID bereits belegt | ID=%1 | Fahrzeug=%2",
                    _groupID,
                    _vehicleID
                ];
            };


            // Veraltete Schlüssel derselben Gruppe entfernen.
            // Das ist insbesondere wichtig, wenn GroupCreated die
            // Gruppe unter einer vorläufigen ID registriert hat.

            {
                if (
                    (
                        TAG_DynamicGroups getOrDefault [
                            _x,
                            grpNull
                        ]
                    ) isEqualTo _group
                ) then {
                    TAG_DynamicGroups deleteAt _x;
                };
            } forEach (keys TAG_DynamicGroups);


            {
                if (
                    (
                        TAG_PersistentGroups getOrDefault [
                            _x,
                            grpNull
                        ]
                    ) isEqualTo _group
                ) then {
                    TAG_PersistentGroups deleteAt _x;
                };
            } forEach (keys TAG_PersistentGroups);


            // Dynamische Fahrzeugbesatzung registrieren.

            TAG_PersistentGroups set [
                _groupID,
                _group
            ];

            TAG_DynamicGroups set [
                _groupID,
                _group
            ];


            [
                "registerGroups",
                format [
                    "Dynamische Fahrzeugbesatzung registriert | Fahrzeug=%1 | Gruppe=%2 | Einheiten=%3",
                    _vehicleID,
                    _groupID,
                    count units _group
                ]
            ] call TAG_fnc_debugLog;
        };
    }
];


// Bereits vorhandene Gruppen registrieren.

{
    [_x] call _registerGroupIfEligible;
} forEach allGroups;


[
    "registerGroups",
    format [
        "Gruppenregistrierung abgeschlossen | Anzahl=%1",
        count TAG_PersistentGroups
    ]
] call TAG_fnc_debugLog;
