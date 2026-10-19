
/*
    Author: Djinn

    Description:
    Stellt die gespeicherten Diary-Daten für eine Spielereinheit bereit
    und sperrt deren Autosave bis zur Restore-Bestätigung.

    Die passenden Buckets werden wie bisher ausgewählt.
    Anschließend werden ihre Einträge pro Diary-Subject anhand
    des gespeicherten RecordIndex sortiert.

    Ausführung: Server, via RemoteExec
*/

if (!isServer) exitWith {};

private _remoteOwner = remoteExecutedOwner;
private _sender = objNull;

{
    if (owner _x isEqualTo _remoteOwner) exitWith {
        _sender = _x;
    };
} forEach allPlayers;

if (isNull _sender) exitWith {
    diag_log format [
        "[PERSISTENCE][DIARY] Restore-Anfrage abgelehnt | Owner=%1 | Grund=Spielereinheit nicht gefunden",
        _remoteOwner
    ];
};

private _unitName = vehicleVarName _sender;

if (_unitName isEqualTo "") exitWith {
    diag_log format [
        "[PERSISTENCE][DIARY] Restore-Anfrage abgelehnt | Owner=%1 | Grund=Leerer Einheitenname",
        _remoteOwner
    ];
};

if (isNil "TAG_DiaryRestoreReady") then {
    TAG_DiaryRestoreReady = createHashMap;
};

// Autosave für diese Einheit bis zur Bestätigung sperren.
TAG_DiaryRestoreReady set [
    _unitName,
    false
];

private _entries = TAG_SaveData getOrDefault [
    "DiaryEntries",
    createHashMap
];

private _diaryData = [];

private _groupKey = format [
    "GRP:%1|%2",
    str (side _sender),
    groupId (group _sender)
];

private _sideKey = format [
    "SIDE:%1",
    str (side _sender)
];

private _playerKey = format [
    "PLAY:%1",
    _unitName
];

private _bucketKeys = [
    _playerKey,
    _groupKey,
    _sideKey,
    "ALL:ALL"
];

{
    private _bucketKey = _x;
    private _bucket = _entries getOrDefault [
        _bucketKey,
        []
    ];

    if (_bucket isEqualType []) then {
        {
            if (
                _x isEqualType []
                && {count _x >= 10}
                && {(_x param [9, -1]) isEqualType 0}
                && {(_x param [9, -1]) >= 0}
            ) then {
                _diaryData pushBack (+_x);
            } else {
                diag_log format [
                    "[PERSISTENCE][DIARY] Ungültiger Eintrag übersprungen | Einheit=%1 | Bucket=%2",
                    _unitName,
                    _bucketKey
                ];
            };
        } forEach _bucket;
    } else {
        diag_log format [
            "[PERSISTENCE][DIARY] Ungültiger Bucket übersprungen | Einheit=%1 | Bucket=%2",
            _unitName,
            _bucketKey
        ];
    };
} forEach _bucketKeys;

// -----------------------------------------------------
// Reihenfolge pro Diary-Subject wiederherstellen
// -----------------------------------------------------

// Die Reihenfolge der Subjects selbst ist unerheblich.
// Innerhalb jedes Subjects entscheidet ausschließlich RecordIndex.
private _subjectIDs = [];

{
    private _subjectID = _x param [0, ""];

    if !(_subjectID isEqualTo "") then {
        _subjectIDs pushBackUnique _subjectID;
    };
} forEach _diaryData;

private _sortedDiaryData = [];

{
    private _subjectID = _x;

    private _subjectEntries = _diaryData select {
        (_x param [0, ""]) isEqualTo _subjectID
    };

    // Stabil aufsteigend nach RecordIndex sortieren.
    // Bei gleichem Index bleibt die bisherige Reihenfolge erhalten.
    while {count _subjectEntries > 0} do {

        private _bestPosition = 0;
        private _bestIndex = (
            _subjectEntries select 0
        ) param [9, 0];

        if (count _subjectEntries > 1) then {
            for "_i" from 1 to ((count _subjectEntries) - 1) do {
                private _candidateIndex = (
                    _subjectEntries select _i
                ) param [9, 0];

                if (_candidateIndex < _bestIndex) then {
                    _bestPosition = _i;
                    _bestIndex = _candidateIndex;
                };
            };
        };

        _sortedDiaryData pushBack (
            _subjectEntries deleteAt _bestPosition
        );
    };

} forEach _subjectIDs;

_diaryData = _sortedDiaryData;

["sendDiaryRestore", format [
    "Restore-Daten versendet | Einheit=%1 | Anzahl=%2 | Subjects=%3",
    _unitName,
    count _diaryData,
    count _subjectIDs
]] call TAG_fnc_debugLog;

// Auch einen leeren Datenbestand senden, damit der Client
// den abgeschlossenen Restore bestätigen kann.
[_diaryData] remoteExecCall [
    "TAG_fnc_applyDiaryEntries",
    _remoteOwner
];
