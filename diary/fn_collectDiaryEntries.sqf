
/*
    Author: Djinn

    Description:
    Liest Diary-Subjects und Einträge des lokalen Spielers aus.
    Ergänzt Geltungsbereich, Zuordnungsschlüssel und die
    ursprüngliche Position innerhalb des Diary-Subjects.

    Datenformat:
    [
        Subject-ID,
        Subject-Titel,
        Subject-Bild,
        Eintragstitel,
        Beschreibung,
        Icon,
        Scope,
        ScopeKey,
        ScopeValid,
        RecordIndex
    ]

    Ausführung: Client
*/

if (!hasInterface) exitWith {};

params [
    ["_requestId", -1, [0]]
];

if (_requestId < 0) exitWith {};

waitUntil {
    sleep 0.1;
    !isNull player
};

// Auf die zentrale Konfiguration warten.
waitUntil {
    sleep 0.1;

    !isNil "TAG_DiaryPrefixPlayer"
    && {!isNil "TAG_DiaryPrefixGroup"}
    && {!isNil "TAG_DiaryPrefixSide"}
    && {!isNil "TAG_DiaryPrefixAll"}
};

private _diaryData = [];
private _subjects = allDiarySubjects player;

private _playerKey = vehicleVarName player;
private _groupKey = groupId (group player);
private _sideKey = str (side player);

["collectDiaryEntries", format [
    "Erfassung gestartet | Anfrage=%1 | Subjects=%2 | Spieler=%3 | Gruppe=%4 | Seite=%5",
    _requestId,
    count _subjects,
    _playerKey,
    _groupKey,
    _sideKey
]] call TAG_fnc_debugLog;

{
    private _subjectID = _x param [0, ""];
    private _subjectTitle = _x param [1, ""];
    private _subjectPicture = _x param [2, ""];

    if (_subjectID in [
        "Players",
        "Units",
        "cba_help_docs"
    ]) then {
        continue;
    };

    if !(_subjectID isEqualTo "") then {

        private _records = player allDiaryRecords _subjectID;

        {
            private _recordIndex = _forEachIndex;

            private _recordTitle = _x param [1, ""];
            private _description = _x param [2, ""];
            private _icon = _x param [3, ""];

            private _scope = "PLAY";
            private _scopeKey = _playerKey;
            private _scopeValid = false;

            if (
                _recordTitle find TAG_DiaryPrefixPlayer isEqualTo 0
            ) then {
                _scope = "PLAY";
                _scopeKey = _playerKey;
                _scopeValid = true;
            } else {
                if (
                    _recordTitle find TAG_DiaryPrefixGroup isEqualTo 0
                ) then {
                    _scope = "GRP";
                    _scopeKey = format [
                        "%1|%2",
                        _sideKey,
                        _groupKey
                    ];
                    _scopeValid = !(_groupKey isEqualTo "");
                } else {
                    if (
                        _recordTitle find TAG_DiaryPrefixSide isEqualTo 0
                    ) then {
                        _scope = "SIDE";
                        _scopeKey = _sideKey;
                        _scopeValid = true;
                    } else {
                        if (
                            _recordTitle find TAG_DiaryPrefixAll isEqualTo 0
                        ) then {
                            _scope = "ALL";
                            _scopeKey = "ALL";
                            _scopeValid = true;
                        };
                    };
                };
            };

            _diaryData pushBack [
                _subjectID,
                _subjectTitle,
                _subjectPicture,
                _recordTitle,
                _description,
                _icon,
                _scope,
                _scopeKey,
                _scopeValid,
                _recordIndex
            ];

            ["collectDiaryEntries", format [
                "Eintrag erfasst | Index=%1 | Scope=%2 | Schlüssel=%3 | Gültig=%4 | Titel=%5",
                _recordIndex,
                _scope,
                _scopeKey,
                _scopeValid,
                _recordTitle
            ]] call TAG_fnc_debugLog;

        } forEach _records;
    };
} forEach _subjects;

["collectDiaryEntries", format [
    "Erfassung abgeschlossen | Anfrage=%1 | Gesamt=%2",
    _requestId,
    count _diaryData
]] call TAG_fnc_debugLog;

[
    _requestId,
    _diaryData
] remoteExecCall [
    "TAG_fnc_reportDiaryEntries",
    2
];
