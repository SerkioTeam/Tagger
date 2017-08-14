describe('Serkio tagger', function()
    describe('Entering tag', function()
        tagger = require('serkio-tagger')

        -- utility function to repeatedly call `tag_input_handler`
        local function input(chars)
            for k, v in pairs(chars) do
                tagger:tag_input_handler(v)
            end
        end

        describe('Return keypress', function()
            it('Should switch to normal mode without input',
            function()
                input({'enter'})
                assert.are_equal('normal', tagger.state.mode)
            end)

            it('Should switch to normal mode with input',
            function()
                input({'b', 'u', 'b', 'b', 'l', 'e', 'g', 'u', 'm', 'enter'})
                assert.are_equal('normal', tagger.state.mode)
            end)

            it('Should clear input buffer',
            function()
                input({'i', 'c', 'e', '-', 'k', 'i', 'n', 'g', 'enter'})
                assert.are_equal('', tagger.state.input_tag_string)
            end)

            it('Should choose tag if input is provided',
            function()
                input({'f', 'i', 'n', 'n', 'enter'})
                assert.are_equal('finn', tagger.state.chosen_tag)
            end)

            it('Should select a tag',
            function()
                stub(tagger, 'select_tag')
                input({'j', 'a', 'k', 'e', 'enter'})
                assert.stub(tagger.select_tag).was.called()
                tagger.select_tag:revert()
            end)
        end)

        describe('Escape keypress', function()
            it('Should switch to normal mode without input',
            function()
                input({'esc'})
                assert.are_equal('normal', tagger.state.mode)
            end)

            it('Should switch to normal mode with input',
            function()
                input({'b', 'e', 'e', 'm', 'o', 'esc'})
                assert.are_equal('normal', tagger.state.mode)
            end)

            it('Should discard tag input',
            function()
                input({'m', 'a', 'r', 'c', 'e', 'l', 'i', 'n', 'e', 'esc'})
                assert.are_equal('', tagger.state.input_tag_string)
            end)

            it('Should not change the current chosen tag',
            function()
                tagger.state.chosen_tag = 'peppermint-butler'
                input({'t', 'h', 'e', '-', 'l', 'i', 'c', 'h', 'esc'})
                assert.are_equal('peppermint-butler', tagger.state.chosen_tag)
            end)
        end)

        describe('Backspace keypress', function()
            it('Should delete the last character if input exists',
            function()
                tagger.state.input_tag_string = 'tree-forta'
                input({'bs'})
                assert.are_equal('tree-fort', tagger.state.input_tag_string)
            end)

            it('Should do nothing if there is no input',
            function()
                tagger.state.input_tag_string = ''
                input({'bs'})
                assert.are_equal('', tagger.state.input_tag_string)
            end)
        end)

        describe('Clean input', function()
            it('Should convert uppercase letters to lowercase',
            function()
                input({'F', 'o', 'R', 'e', 'S', 't'})
                assert.are_equal('forest', tagger.state.input_tag_string)
            end)

            it('Should not allow two or more dashes in a row',
            function()
                tagger.state.input_tag_string = ''
                input({'l', '-', '-', 'm', '-', '-', 'o'})
                assert.are_equal('l-m-o', tagger.state.input_tag_string)
            end)

            it('Should not allow a tag to start with a dash',
            function()
                tagger.state.input_tag_string = ''
                input({'-'})
                assert.are_equal('', tagger.state.input_tag_string)
            end)

            it('Should not allow a tag to end with a dash',
            function()
                tagger.state.input_tag_string = ''
                tagger.state.chosen_tag = ''
                input({'c', 'a', 'v', 'e', '-', 'enter'})
                assert.are_equal('cave', tagger.state.chosen_tag)
            end)
        end)
    end)
    describe('utility functions', function()
        local tagger = require('serkio-tagger')

        it('`colour` should convert colours correctly', function()
            assert.are_equal(
                '{\\1a&HFF&\\1c&HCCBBAA&}',
                tagger.colour(1, 'AABBCC00')
            )
        end)
    end)
    describe('time conversion functionality', function()
        local tagger = require('serkio-tagger')

        it('`ms_to_time` should convert milliseconds to `HH:MM:SS.mmm` format', function()
            assert.are_equal('01:03:03.007', tagger.ms_to_time(3783007))
        end)

        it('`time_to_ms` should convert a `HH:MM:SS.mmm` time string to milliseconds', function()
            assert.are_equal(7, tagger.time_to_ms('00:00:00.007'))
            assert.are_equal(3007, tagger.time_to_ms('00:00:03.007'))
            assert.are_equal(183007, tagger.time_to_ms('00:03:03.007'))
            assert.are_equal(3783007, tagger.time_to_ms('01:03:03.007'))
        end)
    end)

    describe('tag data api', function()
        local tagger = require('serkio-tagger')

        it('`remove_tag` should remove a tag instance', function()
            tagger.data.tags = {jake={{1, 5}, {12, 13}}}

            tagger:remove_tag('jake', 1, 5)
            assert.are_same({jake={{12, 13}}}, tagger.data.tags)
        end)

        it('`remove_tag` should remove a tag if no more instances exist', function()
            tagger.data.tags = {jake={{1, 5}}, finn={{1, 5}}}

            tagger:remove_tag('jake', 1, 5)
            assert.are_same({finn={{1, 5}}}, tagger.data.tags)
        end)

        it('`add_tag` should add a tag instance', function()
            tagger.data.tags = {}

            tagger:add_tag('jake', 1, 5)
            assert.are_same({jake={{1, 5}}}, tagger.data.tags)

            tagger:add_tag('jake', 3, 6)
            assert.are_same({jake={{1, 5}, {3, 6}}}, tagger.data.tags)
        end)

        it('`add_tag` should order the start position before the end position', function()
            tagger.data.tags = {}

            tagger:add_tag('jake', 5, 1)
            assert.are_same({jake={{1, 5}}}, tagger.data.tags)
        end)

        it('`add_tag` should order tags chronologically', function()
            tagger.data.tags = {}
            tagger:add_tag('jake', 3, 5)
            tagger:add_tag('jake', 1, 2)
            tagger:add_tag('jake', 7, 9)
            assert.are_same({jake={{1, 2}, {3, 5}, {7, 9}}}, tagger.data.tags)
        end)

        it('`add_tag` should merge tags if they overlap', function()
            tagger.data.tags = {jake={{3, 4}, {5, 7}}}
            tagger:add_tag('jake', 1, 3)
            assert.are_same({jake={{1, 4}, {5, 7}}}, tagger.data.tags)
        end)

        it('`order_tags` should order all tags if called without tag name', function()
            tagger.data.tags = {jake={{5, 7}, {3, 4}}, finn={{2, 3}, {1, 2}}}
            tagger:order_tags()
            assert.are_same(
                {jake={{3, 4}, {5, 7}}, finn={{1, 2}, {2, 3}}},
                tagger.data.tags
            )
        end)

        it('`order_tags` should only order a single tag if called with a tag name', function()
            tagger.data.tags = {jake={{5, 7}, {3, 4}}, finn={{2, 3}, {1, 2}}}
            tagger:order_tags('jake')
            assert.are_same(
                {jake={{3, 4}, {5, 7}}, finn={{2, 3}, {1, 2}}},
                tagger.data.tags
            )
        end)

        it('`push_tag` should push a tag instances end position forward', function()
            tagger.data.tags = {jake={{1, 5}}}
            tagger:push_tag('jake', 1, 5, 6)
            assert.are_same({jake={{1, 6}}}, tagger.data.tags)
        end)

        it('`pull_tag` should pull a tag instances start position backward', function()
            tagger.data.tags = {jake={{2, 5}}}
            tagger:pull_tag('jake', 2, 5, 1)
            assert.are_same({jake={{1, 5}}}, tagger.data.tags)
        end)

        it('`tag_is_equal` should return true if a tag is equal to time positions', function()
            assert.is_true(tagger.tag_is_equal({1, 3}, 1, 3))
        end)

        it('`tag_is_equal` should return false if a tag is not equal to time positions', function()
            assert.is_false(tagger.tag_is_equal({2, 3}, 1, 3))
        end)

        it('`tag_exists_at` should return true if a tag exists at a time position', function()
            assert.is_true(tagger.tag_exists_at({1, 5}, 4))
        end)

        it('`tag_exists_at` should return false if a tag does not exist at a time position', function()
            assert.is_false(tagger.tag_exists_at({2, 5}, 1))
            assert.is_false(tagger.tag_exists_at({2, 5}, 6))
        end)

        it('`get_tags` should return a table of all tags', function()
            tagger.data.tags = {jake={}, finn={}, treehouse={}}
            assert.are_same({'finn', 'jake', 'treehouse'}, tagger:get_tags())
        end)

        it('`get_tags` should return a table of all tags which exist at a time position', function()
            tagger.data.tags = {jake={{6, 9}, {1, 3}}, finn={{3, 4}}, treehouse={{2, 3}}}
            assert.are_same({'jake', 'treehouse'}, tagger:get_tags(2))
        end)

        it('`get_tag_times` should return the start and end times of any matching tag instance', function()
            tagger.data.tags = {jake={{1, 3}, {5, 7}}, finn={{1, 2}}}
            assert.are_same({5, 7}, tagger:get_tag_times('jake', 6))
        end)
    end)
end)
