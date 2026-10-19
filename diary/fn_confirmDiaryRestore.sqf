/*
    Author: Djinn

    Description:
    Bestätigt den abgeschlossenen Diary-Restore einer Spielereinheit.

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
        "[PERSISTENCE][DIARY] Restore-Bestätigung abgelehnt | Owner=%1 | Grund=Spielereinheit nicht gefunden",
        _remoteOwner
    ];
};

private _unitName = vehicleVarName _sender;

if (_unitName isEqualTo "") exitWith {
    diag_log format [
        "[PERSISTENCE][DIARY] Restore-Bestätigung abgelehnt | Owner=%1 | Grund=Leerer Einheitenname",
        _remoteOwner
    ];
};

if (isNil "TAG_DiaryRestoreReady") then {
    TAG_DiaryRestoreReady = createHashMap;
};

private _restoreState = TAG_DiaryRestoreReady getOrDefault [
    _unitName,
    nil
];

if (isNil "_restoreState") then {

    diag_log format [
        "[PERSISTENCE][DIARY] Restore-Bestätigung abgelehnt | Einheit=%1 | Grund=Kein ausstehender Restore",
        _unitName
    ];

} else {

    if (_restoreState isNotEqualTo false) then {

        diag_log format [
            "[PERSISTENCE][DIARY] Restore-Bestätigung ignoriert | Einheit=%1 | Grund=Restore war bereits bestätigt",
            _unitName
        ];

    } else {

        TAG_DiaryRestoreReady set [
            _unitName,
            true
        ];

        diag_log format [
            "[PERSISTENCE][DIARY] Restore bestätigt | Einheit=%1",
            _unitName
        ];
    };
};
