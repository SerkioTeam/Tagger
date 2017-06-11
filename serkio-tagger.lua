local tagger = {}
local mpv_loaded, mp = pcall(require, 'mp')

tagger.mp = mp
tagger.active = false
tagger.marking_active = false
tagger.tag_hud_active = false
tagger.chosen_tag = ''
tagger.input_tag_string = ''

-- modes are: normal and input
tagger.mode = 'normal'

---------------------------------------------------------------------
-- Stub MPV library for running unit tests under `busted`
if not mpv_loaded then
    tagger.mp = {}

    function tagger.mp.osd_message(message) end
    function tagger.mp.log(level, message) end
    function tagger.mp.add_forced_key_binding(key, name, fn) end
    function tagger.mp.remove_key_binding(key, name, fn) end
end

---------------------------------------------------------------------
-- Display message on screen and in console, if specified.
function tagger:message(message, console)
    self.mp.osd_message(message)

    if console then
        self.mp.log('info', message)
    end
end

---------------------------------------------------------------------
-- Creates a tag if it doesn't exist.
function tagger:create_tag(name)
    -- Stub: return `true` if tag was created.
end

---------------------------------------------------------------------
-- Deletes a tag instance on the timeline, if the tag is no longer
-- associated with any time on the timeline - remove it entirely.
function tagger:delete_tag()
    self:message('Delete this tag? [y/n]')
end

---------------------------------------------------------------------
-- Switches the tagger into `input` mode in order to input a tag.
function tagger:choose_tag()
    self.mode = 'input'
    self:message('Enter a tag')

    self:remove_keybindings(self.normal_bindings)
    self:add_keybindings(self.enter_bindings)
end

---------------------------------------------------------------------
-- Takes input from the user so they can enter a tag name. It then
-- creates that tag if necessary and `chooses` it, so when the user
-- presses `m` (mark) we know which tag to associate with that
-- particular part of the timeline.
function tagger:tag_input_handler(char)
    -- `enter` and `escape` behave quite similar
    if char == 'enter'  or char == 'esc' then
        if char == 'enter' then
            -- a dash isn't allowed as the end character
            if self.input_tag_string:sub(-1) == '-' then
                self.input_tag_string = self.input_tag_string:sub(1, -2)
            end

            if self.input_tag_string:len() > 0 then
                if self:create_tag(self.input_tag_string) then
                    self:message(string.format('%q created and chosen', self.input_tag_string))
                else
                    self:message(string.format('%q chosen', self.input_tag_string))
                end

                self.chosen_tag = self.input_tag_string
            end
        end

        -- reset input buffer
        self.input_tag_string = ''

        -- switch back to normal mode
        self.mode = 'normal'
        self:remove_keybindings(self.enter_bindings)
        self:add_keybindings(self.normal_bindings)
    -- backspace
    elseif char == 'bs' then
        self.input_tag_string = self.input_tag_string:sub(1, -2)
        self:message(string.format('Tag: %s', self.input_tag_string))
    -- a-z, A-Z and dash (`-`)
    else
        if char == '-' then
            -- a dash isn't allowed as the first character
            if self.input_tag_string:len() == 0 then
                do return end
            end

            -- no more than one dash can exist between words
            if self.input_tag_string:sub(-1) == '-' then
                do return end
            end
        end

        self.input_tag_string = self.input_tag_string .. char:lower()
        self:message(string.format('Tag: %s', self.input_tag_string))
    end
end

---------------------------------------------------------------------
-- Associates the chosen tag with a unit of time on the timeline.
-- This must be pressed twice, once to begin the selection and again
-- to end it.
function tagger:mark_tag()
    if self.marking_active then
        self:message('Marking the end of a tag')
    else
        self:message('Marking the beginning of a tag')
    end

    self.marking_active = not self.marking_active
end

---------------------------------------------------------------------
-- Toggles the `tag heads up display`, which shows all tags
-- associated with the current video. Highlighting `active` ones as
-- the video is played.
function tagger:toggle_tag_hud()
    self.tag_hud_active = not self.tag_hud_active

    if self.tag_hud_active then
        self:message('Tag heads up display activated')
    else
        self:message('Tag heads up display disabled')
    end
end

---------------------------------------------------------------------
-- Changes a tag's start time. It first looks to see if we're
-- `on top` of a tag, if we're not it will look for a tag `in front`
-- of our current position.
function tagger:change_tag_in()
    self:message('Change tag `in` time')
end

---------------------------------------------------------------------
-- Changes a tag's end time. It first looks to see if we're `on top`
-- of a tag, if we're not it will look for a tag `behind` our current
-- position.
function tagger:change_tag_out()
    self:message('Change tag `out` time')
end

---------------------------------------------------------------------
-- Load all tags from a JSON file.
function tagger:load_tags()
    self:message('Load tags from file')
end

---------------------------------------------------------------------
-- Save all tags to a JSON file.
function tagger:save_tags()
    self:message('Save tags from file')
end

---------------------------------------------------------------------
-- Takes a table of keybindings and enables them
function tagger:add_keybindings(bindings)
    for i=1, #bindings do
        self.mp.add_forced_key_binding(
            bindings[i][1],
            bindings[i][2],
            bindings[i][3]
        )
    end
end

---------------------------------------------------------------------
-- Takes a table of keybindings and disables them
function tagger:remove_keybindings(bindings)
    for i=1, #bindings do
        self.mp.remove_key_binding(bindings[i][2])
    end
end

---------------------------------------------------------------------
-- Toggles the tagger plugin and controls normal mode keybindings.
function tagger:toggle_existence()
    self.active = not self.active

    if self.active then
        self:message('Serkio activated', true)
        self:add_keybindings(self.normal_bindings)
    else
        self:message('Serkio deactivated', true)
        self:remove_keybindings(self.normal_bindings)
    end
end

-- `normal mode` keybindings
tagger.normal_bindings = {
    {'d', 'delete-tag', function () return tagger:delete_tag() end},
    {'t', 'choose-tag', function () return tagger:choose_tag() end},
    {'m', 'mark-tag', function () return tagger:mark_tag() end},
    {'v', 'toggle-tag-hud', function () return tagger:toggle_tag_hud() end},
    {'i', 'change-tag-in', function () return tagger:change_tag_in() end},
    {'o', 'change-tag-out', function () return tagger:change_tag_out() end},
    {'l', 'load-tags', function () return tagger:load_tags() end},
    {'s', 'save-tags', function () return tagger:save_tags() end},
}

-- `enter mode` keybindings
tagger.enter_bindings = {
    {
        'space', 'space',
        function () return tagger:tag_input_handler('-') end
    },
    {
        'bs', 'bs',
        function () return tagger:tag_input_handler('bs') end
    },
    {
        'enter', 'enter',
        function () return tagger:tag_input_handler('enter') end
    },
    {
        'esc', 'esc',
        function () return tagger:tag_input_handler('esc') end
    }
}

letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-'

for i = 1, letters:len() do
    local c = letters:sub(i, i)

    table.insert(
        tagger.enter_bindings,
        {c, c, function () return tagger:tag_input_handler(c) end}
    )
end

tagger.mp.add_forced_key_binding(
    'ctrl+t',
    'toggle-tagger',
    function () return tagger:toggle_existence() end
)

return tagger
