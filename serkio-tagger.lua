local tagger = {}
local mpv_loaded, mp = pcall(require, 'mp')
local ass_loaded, assdraw = pcall(require, 'mp.assdraw')
local _, utils = pcall(require, 'mp.utils')

tagger.mp = mp
tagger.utils = utils

tagger.state = {
    active=false,
    tag_hud_active=false,
    chosen_tag='',
    input_tag_string='',
    rendered_string='',

    -- modes are: normal and input
    mode='normal',

    -- delete tag state
    delete_tag_state={active=false},

    -- one of two current tag states:
    -- ∙ Actively marking a new tag
    -- ∙ Hovering over an existing tag
    current_tag={
        active=false,
        marking=false,
        start_time='',
        end_time=''
    }
}

-- meta info and tag data for this media file
tagger.data = {}

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
function tagger.colour(id, colour)
    local alpha = string.format(
        '\\%da&H%X&', id, 0xff - tonumber(colour:sub(7, 8), 16)
    )

    -- RGB to BGR
    colour = colour:sub(5, 6) .. colour:sub(3, 4) .. colour:sub(1, 2)

    return '{' .. alpha .. string.format('\\%dc&H%s&', id, colour) .. '}'
end


---------------------------------------------------------------------
-- Return a suitable filename to store tag data
function tagger:get_filename()
    return string.match(
        self.mp.get_property('path'),
        '(.*)%.[^.]+$'
    ) .. '.json'
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
function tagger:show_message(message, time_bound, style, duration)
    self.message.content = message
    self.message.time_bound = time_bound or false
    self.message.style = style or 'notification'
    self.message.duration = duration or self.message.duration
    self.message.active = true

    -- kill old message timer so it won't interfere with this message
    if message_timer ~= nil then
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

    local msg_pixel_width = self.string_pixel_width(
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
        self.colour(1, self.message_styles[self.message.style].bg)
    )

    -- border
    self.ass:append(
        self.colour(3, self.message_styles[self.message.style].border)
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
    self.ass:append(self.colour(1, 'FFFFFFFF'))

    -- bold, no border, font size, center align
    self.ass:append('{\\b1}{\\bord0}{\\fs64}{\\an5}')
    self.ass:append(self.message.content)
end


---------------------------------------------------------------------
-- Utility function to work out the width of a string in pixels.
-- Useful for creating container boxes.
function tagger.string_pixel_width(text, upper_width, lower_width)
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
-- Utility function for splitting strings on a `sep` seperator.
function string:split(sep)
    local sep, fields = sep or ':', {}
    local pattern = string.format('([^%s]+)', sep)
    self:gsub(pattern, function(c) fields[#fields + 1] = c end)

    return fields
end


---------------------------------------------------------------------
-- Adds a tag instance. This also merges tags if they overlap.
function tagger:add_tag(tag, t1, t2)
    local tags = self.data.tags[tag]

    if tags == nil then
        tags = {}
    end

    -- start should always come before the end
    local points = {t1, t2}
    table.sort(points)

    -- merge overlapping tags
    local high = points[2]

    for k, v in pairs(tags) do
        if v[1] >= points[1] and v[1] <= points[2] then
            if v[2] > high then
                high = v[2]
            end

            table.remove(tags, k)
        end
    end

    -- add the new tag
    tags[#tags + 1] = {points[1], high}

    self.data.tags[tag] = tags

    self:order_tags(tag)

    -- save to file
    if mpv_loaded then self:save_data() end
end


---------------------------------------------------------------------
-- Deletes a tag instance. If necessary the tag itself is deleted.
function tagger:remove_tag(tag, t1, t2)
    local tags = self.data.tags[tag]

    for k, v in pairs(tags) do
        if self.tag_is_equal(v, t1, t2) then
            table.remove(tags, k)
        end
    end

    if #tags == 0 then
        tags = nil
    end

    self.data.tags[tag] = tags

    -- save to file
    if mpv_loaded then self:save_data() end
end


---------------------------------------------------------------------
-- Change a tag instances end position to `new_t2`.
function tagger:push_tag(tag, t1, t2, new_t2)
    local tags = self.data.tags[tag]

    for k, v in pairs(tags) do
        if self.tag_is_equal(v, t1, t2) then
            tags[k] = {t1, new_t2}
        end
    end
end


---------------------------------------------------------------------
-- Change a tag instances start position to `new_t1`.
function tagger:pull_tag(tag, t1, t2, new_t1)
    local tags = self.data.tags[tag]

    for k, v in pairs(tags) do
        if self.tag_is_equal(v, t1, t2) then
            tags[k] = {new_t1, t2}
        end
    end

    self:order_tags(tag)
end


---------------------------------------------------------------------
-- Orders tag instances by start position. Tag name optional, if not
-- provided it will order all tags.
function tagger:order_tags(tag)
    local tags = self.data.tags

    if tag == nil then
        for k, _ in pairs(tags) do
            table.sort(tags[k], function(a, b) return a[1] < b[1] end)
        end
    else
        table.sort(tags[tag], function(a, b) return a[1] < b[1] end)
    end

    self.data.tags = tags
end


---------------------------------------------------------------------
-- Returns a table of all tag names. The `position` argument is
-- optional, if provided it will only return tags which have
-- instances existing within `position` on the timeline.
function tagger:get_tags(position)
    local tags = {}

    for k, v in pairs(self.data.tags) do
        if position == nil then
            table.insert(tags, k)
        else
            for i=1, #v do
                if self.tag_exists_at(v[i], position) then
                    table.insert(tags, k)
                    break
                end
            end
        end
    end

    table.sort(tags)

    return tags
end


---------------------------------------------------------------------
-- Searches for a tag that exists within `position`, then returns
-- the matching tag instances start and end time.
function tagger:get_tag_times(tag, position)
    if self.data.tags[tag] == nil then
        return
    end

    for i=1, #self.data.tags[tag] do
        if self.tag_exists_at(self.data.tags[tag][i], position) then
            return self.data.tags[tag][i]
        end
    end
end


---------------------------------------------------------------------
-- Returns `true` if tag is equal to `t1` and `t2`.
function tagger.tag_is_equal(tag, t1, t2)
    return tag[1] == t1 and tag[2] == t2
end


---------------------------------------------------------------------
-- Returns `true` if tag appears at `t`.
function tagger.tag_exists_at(tag, t)
    return t >= tag[1] and t <= tag[2]
end


---------------------------------------------------------------------
-- Converts `HH:MM:SS' time strings to milliseconds.
function tagger.time_to_ms(time_string)
    local t = time_string:split()
    local sec_ms = t[3]:split('.')

    return math.floor(
       tonumber(t[1]) * 3600000 +
       tonumber(t[2]) * 60000 +
       tonumber(sec_ms[1]) * 1000 +
       tonumber(sec_ms[2])
   )
end


---------------------------------------------------------------------
-- Converts milliseconds to a time string of `HH:MM:SS.mmm'.
function tagger.ms_to_time(ms)
    local remaining_ms = math.fmod(ms, 1000)
    local seconds = (ms - remaining_ms) / 1000

    return string.format(
        '%s.%03d',
        os.date('!%X', seconds),
        remaining_ms
    )
end


---------------------------------------------------------------------
-- Creates a tag if it doesn't exist.
function tagger.create_tag(name)
    -- Stub: return `true` if tag was created.
end


---------------------------------------------------------------------
-- Render the current tag
function tagger:render_current_tag()
    if not self.state.current_tag.active then
        return
    end

    -- Pixel counts for font size 35
    local text_size = {upper_w=20, lower_w=15, height=32}

    -- Box offset
    local offset = {x=5, y=5}

    local msg_pixel_width = self.string_pixel_width(
        self.state.chosen_tag,
        text_size.upper_w,
        text_size.lower_w
    )

    local box_width = msg_pixel_width + text_size.upper_w
    local box_height = text_size.height * 3

    -- prevent an odd looking box for smaller tags
    box_width = box_width < 240 and 240 or box_width

    -- rounded rectangle box
    self.ass:new_event()

    -- background
    self.ass:append(self.colour(1, 'FE4365FF'))

    -- border
    self.ass:append(self.colour(3, '83AF9BFF') .. '{\\bord5}')

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
    self.ass:append(self.colour(1, '772231FF') .. self.colour(3, 'F96883FF'))

    -- bold, border, font size, center align
    self.ass:append('{\\b1}{\\bord0.5}{\\fs35}{\\an2}')
    self.ass:append(self.state.chosen_tag)

    -- time
    self.ass:new_event()
    self.ass:pos(
        (box_width + offset.x) / 2 + 4, -- the `4` is a positional fudge
        (box_height + offset.y) / 2 + 8 -- the `8` is a positional fudge
    )

    -- text and shadow colours
    self.ass:append(self.colour(1, '772231FF') .. self.colour(3, 'F96883FF'))

    -- thin border, font size, center align
    self.ass:append('{\\bord0.1}{\\fs25}{\\an8}')

    self.ass:append(self.state.current_tag.start_time)
    self.ass:append(' — ' .. self.state.current_tag.end_time)
end

---------------------------------------------------------------------
-- The main draw function. This calls all render functions.
function tagger:draw(force)
    local screenx, screeny, _ = self.mp.get_osd_size()

    tagger.ass = assdraw.ass_new()

    self:render_current_tag()
    self:render_message(screenx, screeny)

    if forced or self.state.rendered_string ~= self.ass.text then
        self.mp.set_osd_ass(screenx, screeny, self.ass.text)
        self.state.rendered_string = self.ass.text
    end
end

---------------------------------------------------------------------
-- Deletes a tag instance on the timeline, if the tag is no longer
-- associated with any time on the timeline - remove it entirely.
function tagger:delete_tag()
    if not self.state.current_tag.active or self.state.current_tag.marking then
        return
    end

    self.state.delete_tag_state.active = true
    self.state.delete_tag_state.tag = self.state.chosen_tag
    self.state.delete_tag_state.start_time = self.time_to_ms(self.state.current_tag.start_time)
    self.state.delete_tag_state.end_time = self.time_to_ms(self.state.current_tag.end_time)

    self:show_message('Delete this tag? [y/n]', false, 'warning')

    self.mp.set_property_native('pause', true)

    -- force a redraw (the notification doesn't show without this)
    self:draw(true)
end


---------------------------------------------------------------------
-- Confirm a tag deletion.
function tagger:delete_tag_confirm()
    if not self.state.delete_tag_state.active then
        return
    end

    self.mp.set_property_native('pause', false)
    self:remove_tag(
        self.state.delete_tag_state.tag,
        self.state.delete_tag_state.start_time,
        self.state.delete_tag_state.end_time
    )
    self:clear_message()

    self.state.delete_tag_state.active = false
end


---------------------------------------------------------------------
-- Cancel a tag deletion.
function tagger:delete_tag_cancel()
    if not self.state.delete_tag_state.active then
        return
    end

    self.mp.set_property_native('pause', false)
    self.state.delete_tag_state = {}
    self:clear_message()
    self.state.delete_tag_state.active = false
end

---------------------------------------------------------------------
-- Switches the tagger into `input` mode in order to input a tag.
function tagger:choose_tag()
    self.state.mode = 'input'
    self:show_message('Enter a tag')

    self:remove_keybindings(self.normal_bindings)
    self:add_keybindings(self.enter_bindings)
end


---------------------------------------------------------------------
-- Select a tag. A tag needs to be `selected` in order for the user
-- to create mark points and for tag info to be displayed in the top
-- left hand corner.
function tagger:select_tag(tag)
    self.state.chosen_tag = tag
    self:show_message(string.format('%q selected', tag), true)
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
            if self.state.input_tag_string:sub(-1) == '-' then
                self.state.input_tag_string = self.state.input_tag_string:sub(1, -2)
            end

            if self.state.input_tag_string:len() > 0 then
                self:select_tag(self.state.input_tag_string)
            end
        end

        -- reset input buffer
        self.state.input_tag_string = ''

        -- switch back to normal mode
        self.state.mode = 'normal'
        self:remove_keybindings(self.enter_bindings)
        self:add_keybindings(self.normal_bindings)
    -- backspace
    elseif char == 'bs' then
        self.state.input_tag_string = self.state.input_tag_string:sub(1, -2)
        self:show_message(self.state.input_tag_string)
    -- a-z, A-Z and dash (`-`)
    else
        if char == '-' then
            -- a dash isn't allowed as the first character
            if self.state.input_tag_string:len() == 0 then
                do return end
            end

            -- no more than one dash can exist between words
            if self.state.input_tag_string:sub(-1) == '-' then
                do return end
            end
        end

        self.state.input_tag_string = self.state.input_tag_string .. char:lower()
        self:show_message(self.state.input_tag_string)
    end
end

---------------------------------------------------------------------
-- Associates the chosen tag with a unit of time on the timeline.
-- This must be pressed twice, once to begin the selection and again
-- to end it.
function tagger:mark_tag()
    if self.state.chosen_tag == '' then
        self:show_message('Before marking, select a tag with "t"', true, 'warning', 3)
        return
    end

    if self.state.current_tag.marking then
        self:add_tag(
            self.state.chosen_tag,
            self.time_to_ms(self.state.current_tag.start_time),
            self.time_to_ms(self.state.current_tag.end_time)
        )
    else
        self.state.current_tag.start_time = self.mp.get_property_osd('playback-time/full')
        self.state.current_tag.end_time = self.state.current_tag.start_time
    end

    self.state.current_tag.active = not self.state.current_tag.active
    self.state.current_tag.marking = not self.state.current_tag.marking
end

---------------------------------------------------------------------
-- Toggles the `tag heads up display`, which shows all tags
-- associated with the current video. Highlighting `active` ones as
-- the video is played.
function tagger:toggle_tag_hud()
    self.state.tag_hud_active = not self.state.tag_hud_active

    if self.state.tag_hud_active then
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
-- Load all tags and meta data from a JSON file.
function tagger:load_data()
    local json_file = io.open(self:get_filename(), 'r')

    if json_file == nil then
        self.data = {
            name=self.mp.get_property('media-title'),
            duration=self.ms_to_time(self.mp.get_property('duration') * 1000),
            filename=self.mp.get_property('filename'),
            tags={}
        }
    else
        self.data = self.utils.parse_json(json_file:read('*all'))
        json_file:close()
    end
end

---------------------------------------------------------------------
-- Save all tags and meta data to a JSON file.
function tagger:save_data()
    local json_file, _ = io.open(self:get_filename(), 'w')

    if json_file == nil then return end

    json_file:write(string.format('%s', self.utils.format_json(self.data)))
    json_file:close()
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
    local screenx, screeny, _ = self.mp.get_osd_size()
    local last_tick = ''

    self.state.active = not self.state.active

    if self.state.active then
        self:show_message('Serkio activated', true)
        self:add_keybindings(self.normal_bindings)
        self:load_data()

        -- enable GUI (checks for GUI updates every 50ms)
        gui = self.mp.add_periodic_timer(0.05, function()
            self:draw()
        end)

        -- frame by frame tick event to retrieve tag info
        self.mp.register_event('tick', function()
            local pos = self.mp.get_property_osd('playback-time/full')
            current_tick = self.mp.get_property_osd('estimated-frame-number')

            -- only continue if we've changed frames
            if last_tick == current_tick or pos == '' then
                return
            end

            -- this event can be fired after the video has finished,
            -- in which case we don't have access to MPV properties
            if pos == '' then
                return
            end

            -- marking active
            if self.state.current_tag.active and self.state.current_tag.marking then
                self.state.current_tag.end_time = pos
            else
                local tag_times = self:get_tag_times(self.state.chosen_tag, self.time_to_ms(pos))

                -- we are hovering over an existing tag
                if tag_times ~= nil then
                    self.state.current_tag.active = true
                    self.state.current_tag.start_time = self.ms_to_time(tag_times[1])
                    self.state.current_tag.end_time = self.ms_to_time(tag_times[2])
                -- we have just hovered past an existing tag
                elseif self.state.current_tag.active then
                    self.state.current_tag.active = false
                end
            end

            last_tick = current_tick
        end)
    else
        self:remove_keybindings(self.normal_bindings)

        -- disable GUI
        gui:kill()
        self.mp.set_osd_ass(screenx, screeny, '')

        -- disable ticker
        self.mp.unregister_event('tick')
        last_tick = ''
    end
end

-- `normal mode` keybindings
tagger.normal_bindings = {
    {'d', 'delete-tag', function () return tagger:delete_tag() end},
    {'y', 'delete-tag-confirm', function () return tagger:delete_tag_confirm() end},
    {'n', 'delete-tag-cancel', function () return tagger:delete_tag_cancel() end},
    {'t', 'choose-tag', function () return tagger:choose_tag() end},
    {'m', 'mark-tag', function () return tagger:mark_tag() end},
    {'v', 'toggle-tag-hud', function () return tagger:toggle_tag_hud() end},
    {'i', 'change-tag-in', function () return tagger:change_tag_in() end},
    {'o', 'change-tag-out', function () return tagger:change_tag_out() end},
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

local letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-'

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
