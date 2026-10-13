local ADDON, ns = ...

-- All presentation constants live here. Public seats always use the same palette.
ns.Theme = {
    width = 700, height = 600, miniWidth = 330, miniHeight = 40,
    font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
    fontFlags = "", spacing = 8, border = 1,
    colors = {
        wood = { .075, .043, .034, .98 }, velvet = { .16, .035, .050, .98 },
        panel = { .09, .065, .060, .97 }, brass = { .67, .48, .25, 1 },
        brassDim = { .32, .23, .15, 1 }, ivory = { .94, .87, .72, 1 },
        muted = { .65, .58, .48, 1 }, green = { .47, .75, .59, 1 },
        red = { .88, .38, .31, 1 }, amber = { .89, .70, .39, 1 },
        blue = { .61, .75, .85, 1 }, disabled = { .40, .37, .33, 1 },
    },
    sounds = { turn = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856 },
    animation = { reveal = .22, pulse = .85, token = .24, hover = .18, dismiss = .12 },
    texture = "Interface\\Buttons\\WHITE8X8",
    edge = "Interface\\Buttons\\WHITE8X8",
    assetRoot = "Interface\\AddOns\\TimeBombRP\\Assets\\",
}

function ns.Theme.Asset(name)
    return ns.Theme.assetRoot .. name .. ".tga"
end
