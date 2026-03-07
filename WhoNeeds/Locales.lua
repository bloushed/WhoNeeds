local _, ns = ...
local addon = ns and ns.Addon or _G.WhoNeeds

local locales = {
    enUS = {
        LOOTS = "Loots",
        SIMULATIONS = "Simulations",
        SETTINGS = "Settings",
        EMPTY_LOOT = "No boss loot seen yet.",
        SIMULATION_LABEL = "Simulation",
        SIMULATION_HINT = "Paste a full item link for the most accurate test. Owner is optional.",
        FORCE_INTEREST = "Force interest for test sims",
        SIM_BUTTON = "Sim Loot",
        SELECT_INSTANCE = "Select Instance...",
        DELETE_INSTANCE = "Delete Instance",
        USABLE_ONLY = "Usable only",
        OWN_DROPS = "Own drops",
        PAGE = "Page %d / %d",
        PREVIOUS = "Previous",
        NEXT = "Next",
        ASK_BUTTON = "MP",
        FAST_ASK = "Fast MP",
        NEED = "Need!",
        PASS = "Pass",
        YOU = "You",
        OWNER = "Owner",
        WAITING = "Waiting",
        NO_DATA_LOOTER = "No data from looter",
        UNKNOWN_TYPE = "Unknown type",
        MISC = "Misc",
        SCORE = "Score: ",
        INTERESTED = "Interested: ",
        NOBODY_YET = "nobody yet",
        ASK_TOOLTIP = "Choose a whisper to send to %s.",
        FAST_ASK_TITLE = "Fast Ask Messages & Templates",
        FAST_ASK_DESC = "Check the button to define which phrase is used by the Fast Ask button.\nEdit the text fields to customize your messages when asking for loots.",
        LANGUAGE = "Language:",
        AUTO_OPEN = "Open on boss loot",
        AUTO_OPEN_DESC = "Automatically open the addon when a boss loot drops in a group.",
        
        -- Status
        BIS = "BiS",
        UPGRADE = "Upgrade",
        SIDEGRADE = "Sidegrade",
        PASS_STATUS = "Pass",
        
        -- Reasons
        REASON_CLASS_WEAP = "Class cannot equip this weapon",
        REASON_CLASS_SHIELD = "Class cannot equip shields",
        REASON_CLASS_ARMOR = "Class cannot equip it",
        REASON_WRONG_ARMOR = "Wrong armor type",
        REASON_UNKNOWN_WEAP = "Unknown weapon slot",
        REASON_NOT_EQUIPPABLE = "Not equippable",
        REASON_MISSING = "Missing item",
        REASON_UNKNOWN_SLOT = "Unknown slot",
        REASON_LOWER_ILVL = "Lower item level",
        
        -- Stats
        CRIT = "Crit",
        HASTE = "Haste",
        MASTERY = "Mastery",
        VERS = "Vers",
        STAMINA = "Stamina",
        STRENGTH = "Strength",
        AGILITY = "Agility",
        INTELLECT = "Intellect",
    },
    frFR = {
        LOOTS = "Butin",
        SIMULATIONS = "Simulations",
        SETTINGS = "Paramètres",
        EMPTY_LOOT = "Aucun butin de boss pour le moment.",
        SIMULATION_LABEL = "Simulation",
        SIMULATION_HINT = "Collez le lien complet (Shift+Clic) pour une précision parfaite. L'owner est optionnel.",
        FORCE_INTEREST = "Forcer l'intérêt (tests)",
        SIM_BUTTON = "Simuler",
        SELECT_INSTANCE = "Sélectionner l'instance...",
        DELETE_INSTANCE = "Supprimer",
        USABLE_ONLY = "Équipable uniq.",
        OWN_DROPS = "Mes loots",
        PAGE = "Page %d / %d",
        PREVIOUS = "Précédent",
        NEXT = "Suivant",
        ASK_BUTTON = "MP",
        FAST_ASK = "Fast MP",
        NEED = "Besoin !",
        PASS = "Pass",
        YOU = "Vous",
        OWNER = "Owner",
        WAITING = "En attente",
        NO_DATA_LOOTER = "Aucune info du looteur",
        UNKNOWN_TYPE = "Type inconnu",
        MISC = "Divers",
        SCORE = "Score: ",
        INTERESTED = "Intéressé(s): ",
        NOBODY_YET = "personne",
        ASK_TOOLTIP = "Sélectionnez un message à envoyer formellement à %s.",
        FAST_ASK_TITLE = "Messages 'Demande Rapide'",
        FAST_ASK_DESC = "Cochez la phrase à envoyer directement via le bouton de Demande Rapide.\nÉditez les lignes de textes ci-dessous pour personnaliser vos phrases.",
        LANGUAGE = "Langue :",
        AUTO_OPEN = "Ouverture auto.",
        AUTO_OPEN_DESC = "Ouvrir l'addon automatiquement lors d'un loot de boss en groupe.",
        
        -- Status
        BIS = "BiS",
        UPGRADE = "Amélioration",
        SIDEGRADE = "Alternatif",
        PASS_STATUS = "Pass",
        
        -- Reasons
        REASON_CLASS_WEAP = "Classe incompatible (arme)",
        REASON_CLASS_SHIELD = "Classe incompatible (bouclier)",
        REASON_CLASS_ARMOR = "Classe incompatible (armure)",
        REASON_WRONG_ARMOR = "Mauvais type d'armure",
        REASON_UNKNOWN_WEAP = "Slot d'arme inconnu",
        REASON_NOT_EQUIPPABLE = "Non équipable",
        REASON_MISSING = "Item introuvable",
        REASON_UNKNOWN_SLOT = "Slot inconnu",
        REASON_LOWER_ILVL = "iLvl trop bas",
        
        -- Stats
        CRIT = "Crit",
        HASTE = "Hâte",
        MASTERY = "Maîtrise",
        VERS = "Poly.",
        STAMINA = "Endurance",
        STRENGTH = "Force",
        AGILITY = "Agilité",
        INTELLECT = "Intelligence",
    }
}

addon.L = setmetatable({}, {
    __index = function(t, key)
        -- Fallback chain: locale user set -> WoW Client locale -> enUS -> empty string
        local lang = addon.db and addon.db.options and addon.db.options.language
        if not lang or lang == "AUTO" then
            lang = GetLocale()
        end
        if not locales[lang] then
            lang = "enUS"
        end
        
        local text = locales[lang][key]
        if not text then
            text = locales["enUS"][key] or key
        end
        return text
    end
})
