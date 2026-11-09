local _, ns = ...

-- English is the fallback for any client language not listed below.
local L = {
    FIX_BUTTON = "Fix Resolution",
    DETECTED   = "Detected: %dx%d",
    TARGET     = "Target: %dx%d",
    NO_API     = "this version of WoW does not provide the required functions; the addon is disabled.",
    OK         = "resolution is correct (%dx%d).",
    APPLYING   = "Applying...",
    FAILED     = "could not reach the target resolution (current: %dx%d; target: %dx%d).",
    APPLY_ERROR = "display error: %s",
}

local translations = {
    frFR = {
        FIX_BUTTON = "Corriger la résolution",
        DETECTED   = "Détectée : %dx%d",
        TARGET     = "Cible : %dx%d",
        NO_API     = "cette version de WoW ne fournit pas les fonctions nécessaires ; l'addon est désactivé.",
        OK         = "la résolution est correcte (%dx%d).",
        APPLYING   = "Correction en cours…",
        FAILED     = "la résolution cible n'a pas été atteinte (actuelle : %dx%d ; cible : %dx%d).",
        APPLY_ERROR = "erreur d'affichage : %s",
    },
    deDE = {
        FIX_BUTTON = "Auflösung korrigieren",
        DETECTED   = "Erkannt: %dx%d",
        TARGET     = "Ziel: %dx%d",
        NO_API     = "diese WoW-Version stellt die benötigten Funktionen nicht bereit; das Addon ist deaktiviert.",
        OK         = "die Auflösung ist korrekt (%dx%d).",
        APPLYING   = "Wird angewendet…",
        FAILED     = "die Zielauflösung wurde nicht erreicht (aktuell: %dx%d; Ziel: %dx%d).",
        APPLY_ERROR = "Anzeigefehler: %s",
    },
    esES = {
        FIX_BUTTON = "Corregir resolución",
        DETECTED   = "Detectada: %dx%d",
        TARGET     = "Objetivo: %dx%d",
        NO_API     = "esta versión de WoW no ofrece las funciones necesarias; el addon está desactivado.",
        OK         = "la resolución es correcta (%dx%d).",
        APPLYING   = "Aplicando…",
        FAILED     = "no se ha alcanzado la resolución objetivo (actual: %dx%d; objetivo: %dx%d).",
        APPLY_ERROR = "error de visualización: %s",
    },
    itIT = {
        FIX_BUTTON = "Correggi risoluzione",
        DETECTED   = "Rilevata: %dx%d",
        TARGET     = "Obiettivo: %dx%d",
        NO_API     = "questa versione di WoW non fornisce le funzioni necessarie; l'addon è disattivato.",
        OK         = "la risoluzione è corretta (%dx%d).",
        APPLYING   = "Applicazione in corso…",
        FAILED     = "la risoluzione desiderata non è stata raggiunta (attuale: %dx%d; desiderata: %dx%d).",
        APPLY_ERROR = "errore di visualizzazione: %s",
    },
    ptBR = {
        FIX_BUTTON = "Corrigir resolução",
        DETECTED   = "Detectada: %dx%d",
        TARGET     = "Alvo: %dx%d",
        NO_API     = "esta versão do WoW não fornece as funções necessárias; o addon está desativado.",
        OK         = "a resolução está correta (%dx%d).",
        APPLYING   = "Aplicando…",
        FAILED     = "a resolução desejada não foi alcançada (atual: %dx%d; desejada: %dx%d).",
        APPLY_ERROR = "erro na exibição: %s",
    },
    ruRU = {
        FIX_BUTTON = "Исправить разрешение",
        DETECTED   = "Обнаружено: %dx%d",
        TARGET     = "Цель: %dx%d",
        NO_API     = "эта версия WoW не предоставляет нужных функций; аддон отключён.",
        OK         = "разрешение правильное (%dx%d).",
        APPLYING   = "Применение…",
        FAILED     = "не удалось установить целевое разрешение (текущее: %dx%d; целевое: %dx%d).",
        APPLY_ERROR = "ошибка отображения: %s",
    },
    koKR = {
        FIX_BUTTON = "해상도 수정",
        DETECTED   = "감지됨: %dx%d",
        TARGET     = "목표: %dx%d",
        NO_API     = "이 WoW 버전은 필요한 기능을 제공하지 않아 애드온이 비활성화되었습니다.",
        OK         = "해상도가 올바릅니다 (%dx%d).",
        APPLYING   = "적용 중…",
        FAILED     = "목표 해상도를 적용하지 못했습니다 (현재: %dx%d; 목표: %dx%d).",
        APPLY_ERROR = "디스플레이 오류: %s",
    },
    zhCN = {
        FIX_BUTTON = "修复分辨率",
        DETECTED   = "检测到：%dx%d",
        TARGET     = "目标：%dx%d",
        NO_API     = "此版本的魔兽世界未提供所需功能，插件已禁用。",
        OK         = "分辨率正确（%dx%d）。",
        APPLYING   = "正在应用…",
        FAILED     = "未能达到目标分辨率（当前：%dx%d；目标：%dx%d）。",
        APPLY_ERROR = "显示错误：%s",
    },
    zhTW = {
        FIX_BUTTON = "修正解析度",
        DETECTED   = "偵測到：%dx%d",
        TARGET     = "目標：%dx%d",
        NO_API     = "此版本的魔獸世界未提供所需功能，插件已停用。",
        OK         = "解析度正確（%dx%d）。",
        APPLYING   = "正在套用…",
        FAILED     = "未能達到目標解析度（目前：%dx%d；目標：%dx%d）。",
        APPLY_ERROR = "顯示錯誤：%s",
    },
}
translations.esMX = translations.esES -- same wording works for both
-- enGB clients report "enUS", so they use the English defaults.

local locale = GetLocale and GetLocale() or "enUS"
local selected = translations[locale]
if selected then
    for key, value in pairs(selected) do
        L[key] = value
    end
end

ns.L = L
