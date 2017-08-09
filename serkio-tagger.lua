local tagger = {}
local mpv_loaded, mp = pcall(require, 'mp')
local ass_loaded, assdraw = pcall(require, 'mp.assdraw')

tagger.mp = mp
tagger.active = false
tagger.marking_active = false
tagger.tag_hud_active = false
tagger.chosen_tag = ''
tagger.input_tag_string = ''
tagger.rendered_string = ''
tagger.start_time = ''  -- for demo
tagger.end_time = ''    -- for demo

-- modes are: normal and input
tagger.mode = 'normal'

-- only one message should be displayed at a time,
-- this is why there isn't a queue of any kind.
tagger.message = {}
tagger.message_styles = {
    notification={
        bg='FE4365B2',
        border='FE4365FF'
    },
    warning={
        bg='FF0000B3',
        border='FF0000FF'
    }
}

---------------------------------------------------------------------
-- Stub MPV library for running unit tests under `busted`
if not mpv_loaded then
    tagger.mp = {}

    function tagger.mp.add_forced_key_binding(key, name, fn) end
    function tagger.mp.add_periodic_timer(time, fn) end
    function tagger.mp.get_time() end
    function tagger.mp.log(level, message) end
    function tagger.mp.osd_message(message) end
    function tagger.mp.remove_key_binding(key, name, fn) end
end

---------------------------------------------------------------------
-- Stub ASS library for running unit tests under `busted`
if not ass_loaded then
    tagger.ass = {}

    function tagger.ass.append() end
    function tagger.ass.draw_start() end
    function tagger.ass.draw_stop() end
    function tagger.ass.pos() end
    function tagger.ass.round_rect_cw() end
end


---------------------------------------------------------------------
-- Converts RRGGBBAA to ASS format
function tagger:colour(id, colour)
    local alpha = string.format(
        '\\%da&H%X&', id, 0xff - tonumber(colour:sub(7, 8), 16)
    )

    -- RGB to BGR
    colour = colour:sub(5, 6) .. colour:sub(3, 4) .. colour:sub(1, 2)

    return '{' .. alpha .. string.format('\\%dc&H%s&', id, colour) .. '}'
end


---------------------------------------------------------------------
-- Reset the notification message
function tagger:clear_message()
    self.message = {
        -- the text to display
        content = '',

        -- duration of message display in seconds
        duration = 1.5,

        -- available styles: notification, warning
        style = 'notification',

        -- is the message time bound?
        time_bound = true,

        -- is the message showing?
        active = false,
    }
end

---------------------------------------------------------------------
-- Create a message
function tagger:show_message(message, time_bound, style)
    self.message.content = message
    self.message.time_bound = time_bound or false
    self.message.style = style or 'notification'
    self.message.active = true

    -- kill old message timer so it won't interfere with this message
    if message_timer then
        message_timer:kill()
    end

    -- start a periodic timer to clear the message when necessary
    if self.message.time_bound then
        local start_time = self.mp.get_time()

        message_timer = self.mp.add_periodic_timer(0.05, function()
            if self.message.active then
                if self.mp.get_time() >= start_time + self.message.duration then
                    self:clear_message()
                    message_timer:kill()
                end
            end
        end)
    end
end


---------------------------------------------------------------------
-- Render a message
function tagger:render_message(screenx, screeny)
    if not self.message.active then
        return
    end

    -- Pixel counts for font size 64
    local text_size = {upper_w=36, lower_w=28, height=45}

    local msg_pixel_width = self:string_pixel_width(
        self.message.content,
        text_size.upper_w,
        text_size.lower_w
    )

    local box_width = msg_pixel_width + (text_size.upper_w * 2)
    local box_height = text_size.height * 4

    -- rounded rectangle box
    self.ass:new_event()

    -- background
    self.ass:append(
        self:colour(1, self.message_styles[self.message.style].bg)
    )

    -- border
    self.ass:append(
        self:colour(3, self.message_styles[self.message.style].border)
    )
    self.ass:append('{\\bord1}')

    self.ass:pos(0, 0)
    self.ass:draw_start()
    self.ass:round_rect_cw(
        (screenx - box_width) / 2,  -- top left x
        (screeny - box_height) / 2, -- top left y
        (screenx + box_width) / 2,  -- bottom right x
        (screeny + box_height) / 2, -- bottom right y
        28                          -- border radius
    )
    self.ass:draw_stop()

    -- message
    self.ass:new_event()
    self.ass:pos(screenx / 2, screeny / 2)

    -- text colour
    self.ass:append(self:colour(1, 'FFFFFFFF'))

    -- bold, no border, font size, center align
    self.ass:append('{\\b1}{\\bord0}{\\fs64}{\\an5}')
    self.ass:append(self.message.content)
end


---------------------------------------------------------------------
-- Utility function to work out the width of a string in pixels.
-- Useful for creating container boxes.
function tagger:string_pixel_width(text, upper_width, lower_width)
    local count = 0

    for i=1, #text do
        local s = text:sub(i, i)

        if s == string.upper(s) then
            count = count + upper_width
        else
            count = count + lower_width
        end
    end

    return count
end


---------------------------------------------------------------------
-- Creates a tag if it doesn't exist.
function tagger:create_tag(name)
    -- Stub: return `true` if tag was created.
end


---------------------------------------------------------------------
-- Render the current tag
function tagger:render_current_tag(screenx, screeny)
    local tag = 'lumpy-space-princess'

    -- Pixel counts for font size 35
    local text_size = {upper_w=20, lower_w=15, height=32}

    -- Box offset
    local offset = {x=5, y=5}

    local msg_pixel_width = self:string_pixel_width(
        tag,
        text_size.upper_w,
        text_size.lower_w
    )

    local box_width = msg_pixel_width + text_size.upper_w
    local box_height = text_size.height * 3

    -- prevent an odd looking box for smaller tags
    box_width = box_width < 200 and 200 or box_width

    -- rounded rectangle box
    self.ass:new_event()

    -- background
    self.ass:append(self:colour(1, 'FE4365FF'))

    -- border
    self.ass:append(self:colour(3, '83AF9BFF') .. '{\\bord5}')

    self.ass:pos(0, 0)
    self.ass:draw_start()
    self.ass:round_rect_cw(
        offset.x,               -- top left x
        offset.y,               -- top left y
        box_width + offset.x,   -- bottom right x
        box_height + offset.y,  -- bottom right y
        45                      -- border radius
    )
    self.ass:draw_stop()

    -- tag text
    self.ass:new_event()
    self.ass:pos((box_width + offset.x) / 2, (box_height + offset.y) / 2 + 8)

    -- text and shadow colours
    self.ass:append(self:colour(1, '772231FF') .. self:colour(3, 'F96883FF'))

    -- bold, border, font size, center align
    self.ass:append('{\\b1}{\\bord0.5}{\\fs35}{\\an2}')
    self.ass:append(tag)

    -- time
    self.ass:new_event()
    self.ass:pos((box_width + offset.x) / 2, (box_height + offset.y) / 2 + 8)

    -- text and shadow colours
    self.ass:append(self:colour(1, '772231FF') .. self:colour(3, 'F96883FF'))

    -- thin border, font size, center align
    self.ass:append('{\\bord0.1}{\\fs25}{\\an8}')

    if self.start_time == '' then
        self.start_time = self.mp.get_property_osd('time-pos')
        self.ass:append(self.start_time)
    else
        self.ass:append(self.start_time)
    end

    if self.end_time == '' then
        self.ass:append(' — ' .. self.mp.get_property_osd('time-pos'))
    end
end

---------------------------------------------------------------------
-- The main draw function. This calls all render functions.
function tagger:draw(screenx, screeny)
    tagger.ass = assdraw.ass_new()

    self:render_current_tag(screenx, screeny)
    self:render_message(screenx, screeny)

    return self.ass.text
end

---------------------------------------------------------------------
-- Deletes a tag instance on the timeline, if the tag is no longer
-- associated with any time on the timeline - remove it entirely.
function tagger:delete_tag()
    self:show_message('Delete this tag? [y/n]', false, 'warning')
end

---------------------------------------------------------------------
-- Switches the tagger into `input` mode in order to input a tag.
function tagger:choose_tag()
    self.mode = 'input'
    self:show_message('Enter a tag')

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
                    self:show_message(string.format('%q created and chosen', self.input_tag_string))
                else
                    self:show_message(string.format('%q chosen', self.input_tag_string))
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
        self:show_message(string.format('Tag: %s', self.input_tag_string))
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
        self:show_message(string.format('Tag: %s', self.input_tag_string))
    end
end

---------------------------------------------------------------------
-- Associates the chosen tag with a unit of time on the timeline.
-- This must be pressed twice, once to begin the selection and again
-- to end it.
function tagger:mark_tag()
    if self.marking_active then
        self:show_message('Marking the end of a tag')
    else
        self:show_message('Marking the beginning of a tag')
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
        self:show_message('Tag heads up display activated')
    else
        self:show_message('Tag heads up display disabled')
    end
end

---------------------------------------------------------------------
-- Changes a tag's start time. It first looks to see if we're
-- `on top` of a tag, if we're not it will look for a tag `in front`
-- of our current position.
function tagger:change_tag_in()
    self:show_message('Change tag `in` time')
end

---------------------------------------------------------------------
-- Changes a tag's end time. It first looks to see if we're `on top`
-- of a tag, if we're not it will look for a tag `behind` our current
-- position.
function tagger:change_tag_out()
    self:show_message('Change tag `out` time')
end

---------------------------------------------------------------------
-- Load all tags from a JSON file.
function tagger:load_tags()
    self:show_message('Load tags from file')
end

---------------------------------------------------------------------
-- Save all tags to a JSON file.
function tagger:save_tags()
    self:show_message('Save tags from file')
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
    local screenx, screeny, aspect = self.mp.get_osd_size()

    self.active = not self.active

    if self.active then
        self:show_message('Serkio activated', true)
        self:add_keybindings(self.normal_bindings)

        -- enable gui (checks for gui updates every 50ms)
        gui = self.mp.add_periodic_timer(0.05, function()
            rendered = self:draw(screenx, screeny)

            if self.rendered_string ~= rendered then
                self.mp.set_osd_ass(screenx, screeny, rendered)
                self.rendered_string = rendered
            end
        end)
    else
        self:remove_keybindings(self.normal_bindings)

        -- disable gui
        gui:kill()
        self.mp.set_osd_ass(screenx, screeny, '')
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

-- call `clear_message` on startup to initialise a default message
tagger:clear_message()

return tagger
