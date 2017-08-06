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
                assert.are_equal('normal', tagger.mode)
            end)

            it('Should switch to normal mode with input',
            function()
                input({'b', 'u', 'b', 'b', 'l', 'e', 'g', 'u', 'm', 'enter'})
                assert.are_equal('normal', tagger.mode)
            end)

            it('Should clear input buffer',
            function()
                input({'i', 'c', 'e', '-', 'k', 'i', 'n', 'g', 'enter'})
                assert.are_equal('', tagger.input_tag_string)
            end)

            it('Should choose tag if input is provided',
            function()
                input({'f', 'i', 'n', 'n', 'enter'})
                assert.are_equal('finn', tagger.chosen_tag)
            end)

            it('Should try to create a tag',
            function()
                stub(tagger, 'create_tag')
                input({'j', 'a', 'k', 'e', 'enter'})
                assert.stub(tagger.create_tag).was.called()
            end)
        end)

        describe('Escape keypress', function()
            it('Should switch to normal mode without input',
            function()
                input({'esc'})
                assert.are_equal('normal', tagger.mode)
            end)

            it('Should switch to normal mode with input',
            function()
                input({'b', 'e', 'e', 'm', 'o', 'esc'})
                assert.are_equal('normal', tagger.mode)
            end)

            it('Should discard tag input',
            function()
                input({'m', 'a', 'r', 'c', 'e', 'l', 'i', 'n', 'e', 'esc'})
                assert.are_equal('', tagger.input_tag_string)
            end)

            it('Should not change the current chosen tag',
            function()
                tagger.chosen_tag = 'peppermint-butler'
                input({'t', 'h', 'e', '-', 'l', 'i', 'c', 'h', 'esc'})
                assert.are_equal('peppermint-butler', tagger.chosen_tag)
            end)
        end)

        describe('Backspace keypress', function()
            it('Should delete the last character if input exists',
            function()
                tagger.input_tag_string = 'tree-forta'
                input({'bs'})
                assert.are_equal('tree-fort', tagger.input_tag_string)
            end)

            it('Should do nothing if there is no input',
            function()
                tagger.input_tag_string = ''
                input({'bs'})
                assert.are_equal('', tagger.input_tag_string)
            end)
        end)

        describe('Clean input', function()
            it('Should convert uppercase letters to lowercase',
            function()
                input({'F', 'o', 'R', 'e', 'S', 't'})
                assert.are_equal('forest', tagger.input_tag_string)
            end)

            it('Should not allow two or more dashes in a row',
            function()
                tagger.input_tag_string = ''
                input({'l', '-', '-', 'm', '-', '-', 'o'})
                assert.are_equal('l-m-o', tagger.input_tag_string)
            end)

            it('Should not allow a tag to start with a dash',
            function()
                tagger.input_tag_string = ''
                input({'-'})
                assert.are_equal('', tagger.input_tag_string)
            end)

            it('Should not allow a tag to end with a dash',
            function()
                tagger.input_tag_string = ''
                tagger.chosen_tag = ''
                input({'c', 'a', 'v', 'e', '-', 'enter'})
                assert.are_equal('cave', tagger.chosen_tag)
            end)
        end)
    end)
    describe('utility functions', function()
        local tagger = require('serkio-tagger')

        it('`colour` should convert colours correctly', function()
            assert.are_equal(
                '{\\1a&HFF&\\1c&HCCBBAA&}',
                tagger:colour(1, 'AABBCC00')
            )
        end)
    end)
end)
