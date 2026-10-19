
/*
    Author: Djinn

    Description:
    Zentrale Konfiguration des Persistenzframeworks.

    Ausführung: Server
*/

// =====================================================
// Diary-Persistenz
// =====================================================

TAG_DiaryPrefixPlayer = "PLAY:";
TAG_DiaryPrefixGroup  = "GRP:";
TAG_DiaryPrefixSide   = "SIDE:";
TAG_DiaryPrefixAll    = "ALL:";

// =====================================================
// Konfiguration veröffentlichen
// =====================================================

{
    publicVariable _x;
} forEach [
    "TAG_DiaryPrefixPlayer",
    "TAG_DiaryPrefixGroup",
    "TAG_DiaryPrefixSide",
    "TAG_DiaryPrefixAll"
];

diag_log "[PERSISTENCE] Zentrale Konfiguration geladen.";
