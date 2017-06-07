local mp = require('mp')
local tagger = {}

tagger.active = false
tagger.marking_active = false
tagger.tag_hud_active = false

---------------------------------------------------------------------
-- Display message on screen and in console, if specified
function tagger:message(message, console)
    mp.osd_message(message)

    if console then
        mp.msg.info(message)
    end
end

---------------------------------------------------------------------
-- Deletes a tag instance on the timeline, if the tag is no longer
-- associated with any time on the timeline - remove it entirely.
function tagger:delete_tag()
    self:message('Delete this tag? [y/n]')
end

---------------------------------------------------------------------
-- Selects a tag as `chosen`, so when the user presses `m` we know
-- which tag to associate with that particular part of the timeline.
-- If the tag doesn't exist, it's first created, then selected.
function tagger:choose_tag()
    self:message('Enter a tag')
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
function tagger:add_keybindings(bindings)
    for i=1, #bindings do
        mp.add_forced_key_binding(
            bindings[i][1],
            bindings[i][2],
            bindings[i][3]
        )
    end
end

---------------------------------------------------------------------
function tagger:remove_keybindings(bindings)
    for i=1, #bindings do
        mp.remove_key_binding(bindings[i][2])
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

mp.add_forced_key_binding(
    'ctrl+t',
    'toggle-tagger',
    function () return tagger:toggle_existence() end
)
