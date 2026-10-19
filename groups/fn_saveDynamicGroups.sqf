
/*
    Author: Djinn

    Description:
    Speichert den aktuellen Zustand dynamischer Gruppen.

    Erfasst:
    - Gruppenzugehörigkeit und Gruppenparameter
    - Einheiten inklusive Klasse, Position, Ausrichtung,
      Ausrüstung, Schaden und Trefferzonenschaden
    - Aktuellen Wegpunkt und verbleibende Wegpunkte

    Gruppen ohne Einheiten werden übersprungen.
    Bereits gespeicherte Zustände werden dadurch nicht gelöscht.
*/

if (!isServer) exitWith {};

if (isNil "TAG_SaveData") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_SaveData fehlt.";
};

if (isNil "TAG_DynamicGroups") exitWith {
    diag_log "[PERSISTENCE] FEHLER: TAG_DynamicGroups fehlt.";
};

[
    "saveDynamicGroups",
    format [
        "Speicherfunktion aufgerufen | Registrierte Gruppen=%1",
        count TAG_DynamicGroups
    ]
] call TAG_fnc_debugLog;


private _savedGroups = TAG_SaveData getOrDefault [
    "DynamicGroups",
    createHashMap
];


{
    private _groupID = _x;
    private _group = _y;

    if (isNull _group) then {
        continue;
    };

    private _units = units _group;

    [
        "saveDynamicGroups",
        format [
            "Gruppe geprüft | ID=%1 | Einheiten=%2",
            _groupID,
            count _units
        ]
    ] call TAG_fnc_debugLog;


    // GroupCreated kann ausgelöst werden, bevor Einheiten
    // hinzugefügt wurden. Vorhandene Daten nicht überschreiben.

    if (_units isNotEqualTo []) then {


        // Vorhandene Besetzung beibehalten, statt sie bei jedem
        // Autosave vollständig durch die aktuelle Einheitenliste zu ersetzen.

        private _previousGroupData = _savedGroups getOrDefault [
            _groupID,
            createHashMap
        ];

        private _unitData = +(
            _previousGroupData getOrDefault [
                "Units",
                []
            ]
        );

        private _usedUnitIDs = [];

        // Ältere Einträge ohne UnitID nachträglich kennzeichnen.

        {
            private _record = _x;

            if (_record isEqualType createHashMap) then {

                private _unitUID = _record getOrDefault [
                    "UnitID",
                    ""
                ];

                if (_unitUID isEqualTo "") then {

                    private _nextUID = _forEachIndex + 1;

                    _unitUID = format [
                        "%1_unit_%2",
                        _groupID,
                        _nextUID
                    ];

                    while { _unitUID in _usedUnitIDs } do {
                        _nextUID = _nextUID + 1;

                        _unitUID = format [
                            "%1_unit_%2",
                            _groupID,
                            _nextUID
                        ];
                    };

                    _record set [
                        "UnitID",
                        _unitUID
                    ];
                };

                _usedUnitIDs pushBackUnique _unitUID;
            };

        } forEach _unitData;


        private _currentUnitIDs = [];

        {
            private _unit = _x;

            private _unitUID = _unit getVariable [
                "TAG_DynamicUnitUID",
                ""
            ];

            // Bereits gespeicherte Einheiten nach Möglichkeit
            // anhand ihrer Klasse zuordnen, falls sie noch keine
            // Kennung besitzen.

            if (_unitUID isEqualTo "") then {

                private _matchIndex = _unitData findIf {
                    (_x getOrDefault ["Class", ""]) isEqualTo (typeOf _unit)
                    && { _x getOrDefault ["Alive", true] }
                    && {
                        !(
                            (_x getOrDefault ["UnitID", ""])
                            in _currentUnitIDs
                        )
                    }
                };

                if (_matchIndex >= 0) then {

                    _unitUID = (
                        _unitData select _matchIndex
                    ) get "UnitID";

                } else {

                    private _nextUID = 1;

                    _unitUID = format [
                        "%1_unit_%2",
                        _groupID,
                        _nextUID
                    ];

                    while { _unitUID in _usedUnitIDs } do {
                        _nextUID = _nextUID + 1;

                        _unitUID = format [
                            "%1_unit_%2",
                            _groupID,
                            _nextUID
                        ];
                    };

                    _usedUnitIDs pushBackUnique _unitUID;
                };

                _unit setVariable [
                    "TAG_DynamicUnitUID",
                    _unitUID
                ];
            };

            _unit setVariable [
                "TAG_DynamicGroupID",
                _groupID
            ];

            _currentUnitIDs pushBackUnique _unitUID;


            // Aktuellen Zustand dieser konkreten Einheit erfassen.

            private _unitRecord = createHashMapFromArray [
                ["UnitID", _unitUID],
                ["Class", typeOf _unit],
                ["Alive", alive _unit],
                ["Position", getPosWorld _unit],
                ["VectorDir", vectorDir _unit],
                ["VectorUp", vectorUp _unit],
                ["Loadout", getUnitLoadout _unit],
                ["Damage", damage _unit],
                ["HitPoints", getAllHitPointsDamage _unit],
                ["Rank", rank _unit],
                ["Skill", skill _unit]
            ];

            private _recordIndex = _unitData findIf {
                (_x getOrDefault ["UnitID", ""]) isEqualTo _unitUID
            };

            if (_recordIndex >= 0) then {

                _unitData set [
                    _recordIndex,
                    _unitRecord
                ];

            } else {

                _unitData pushBack _unitRecord;

                _usedUnitIDs pushBackUnique _unitUID;
            };

        } forEach _units;


        // Gespeicherte Einheiten, die nicht mehr in der Gruppe
        // auftauchen, behalten ihren Datensatz, gelten aber als gefallen.
        // Das setzt voraus, dass Gruppenmitglieder nicht absichtlich
        // in andere Gruppen verschoben werden.

        {
            private _unitUID = _x getOrDefault [
                "UnitID",
                ""
            ];

            if !(_unitUID in _currentUnitIDs) then {
                _x set [
                    "Alive",
                    false
                ];
            };

        } forEach _unitData;



        private _currentWaypoint = currentWaypoint _group;
        

        [
            "saveDynamicGroups",
            format [
                "Speicherfunktion aufgerufen | Registrierte Gruppen=%1 | IDs=%2",
                count TAG_DynamicGroups,
                str (keys TAG_DynamicGroups)
            ]
        ] call TAG_fnc_debugLog;


        private _waypointData = [];

        {
            private _waypoint = _x;
            private _waypointIndex = _waypoint select 1;

            // Nur den aktuellen und nachfolgende Wegpunkte sichern.

            if (_waypointIndex >= _currentWaypoint) then {

                _waypointData pushBack (createHashMapFromArray [
                    ["Index", _waypointIndex],
                    ["Position", waypointPosition _waypoint],
                    ["Type", waypointType _waypoint],
                    ["Behaviour", waypointBehaviour _waypoint],
                    ["CombatMode", waypointCombatMode _waypoint],
                    ["Speed", waypointSpeed _waypoint],
                    ["Formation", waypointFormation _waypoint],
                    ["CompletionRadius", waypointCompletionRadius _waypoint],
                    ["Timeout", waypointTimeout _waypoint],
                    ["Statements", waypointStatements _waypoint]
                ]);
            };

        } forEach waypoints _group;


        private _groupData = createHashMapFromArray [
            ["Side", side _group],
            ["GroupID", _groupID],
            ["GroupIDName", groupId _group],
            ["Behaviour", behaviour leader _group],
            ["CombatMode", combatMode _group],
            ["SpeedMode", speedMode _group],
            ["Formation", formation _group],
            ["CurrentWaypoint", _currentWaypoint],
            ["Units", _unitData],
            ["Waypoints", _waypointData]
        ];


        _savedGroups set [
            _groupID,
            _groupData
        ];


        [
            "saveDynamicGroups",
            format [
                "Zustand erfasst | ID=%1 | Einheiten=%2 | Wegpunkte=%3",
                _groupID,
                count _unitData,
                count _waypointData
            ]
        ] call TAG_fnc_debugLog;


        [
            "saveDynamicGroups",
            format [
                "Dynamische Gruppe gespeichert | ID=%1 | Einheiten=%2 | Wegpunkte=%3",
                _groupID,
                count _unitData,
                count _waypointData
            ]
        ] call TAG_fnc_debugLog;
    };

} forEach TAG_DynamicGroups;


TAG_SaveData set [
    "DynamicGroups",
    _savedGroups
];


[
    "saveDynamicGroups",
    format [
        "HashMap aktualisiert | Gespeicherte Gruppen=%1 | IDs=%2",
        count _savedGroups,
        str (keys _savedGroups)
    ]
] call TAG_fnc_debugLog;


// Kampagnendaten dauerhaft speichern.

[] call TAG_fnc_saveCampaign;
