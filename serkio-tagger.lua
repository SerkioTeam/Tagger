local mp = require('mp')
local tagger = {}

tagger.active = false
tagger.marking_active = false
tagger.tag_hud_active = false

---------------------------------------------------------------------
-- Deletes a tag instance on the timeline, if the tag is no longer
-- associated with any time on the timeline - remove it entirely.
function tagger:delete_tag()
    mp.osd_message('Delete this tag? [y/n]')
end

---------------------------------------------------------------------
-- Selects a tag as `chosen`, so when the user presses `m` we know
-- which tag to associate with that particular part of the timeline.
-- If the tag doesn't exist, it's first created, then selected.
function tagger:choose_tag()
    mp.osd_message('Enter a tag')
end

---------------------------------------------------------------------
-- Associates the chosen tag with a unit of time on the timeline.
-- This must be pressed twice, once to begin the selection and again
-- to end it.
function tagger:mark_tag()
    if self.marking_active then
        mp.osd_message('Marking the end of a tag')
    else
        mp.osd_message('Marking the beginning of a tag')
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
        mp.osd_message('Tag heads up display activated')
    else
        mp.osd_message('Tag heads up display disabled')
    end
end

---------------------------------------------------------------------
-- Changes a tag's start time. It first looks to see if we're
-- `on top` of a tag, if we're not it will look for a tag `in front`
-- of our current position.
function tagger:change_tag_in()
    mp.osd_message('Change tag `in` time')
end

---------------------------------------------------------------------
-- Changes a tag's end time. It first looks to see if we're `on top`
-- of a tag, if we're not it will look for a tag `behind` our current
-- position.
function tagger:change_tag_out()
    mp.osd_message('Change tag `out` time')
end

---------------------------------------------------------------------
-- Load all tags from a JSON file.
function tagger:load_tags()
    mp.osd_message('Load tags from file')
end

---------------------------------------------------------------------
-- Save all tags to a JSON file.
function tagger:save_tags()
    mp.osd_message('Save tags from file')
end

---------------------------------------------------------------------
-- Toggles the tagger plugin and controls normal mode keybindings.
function tagger:toggle_existence()
    self.active = not self.active

    if self.active then
        mp.osd_message('Serkio activated')
        mp.msg.info('Serkio tagger activated')
    else
        mp.osd_message('Serkio deactivated')
        mp.msg.info('Serkio tagger deactivated')
    end

    if self.active then
        for i=1, #self.normal_bindings do
            mp.add_forced_key_binding(
                self.normal_bindings[i][1],
                self.normal_bindings[i][2],
                self.normal_bindings[i][3]
            )
        end
    else
        for i=1, #self.normal_bindings do
            mp.remove_key_binding(self.normal_bindings[i][2])
        end
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
