local tagger = {}

local active = false

function toggle_tagger()
    active = not active
    print('Serkio tagger ' .. (active and 'enabled' or 'disabled'))
end

mp.add_forced_key_binding('ctrl+t', 'toggle-tagger', toggle_tagger)

return tagger
