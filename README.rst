Serkio Tagger
=============

An easy to use script / plugin for `mpv <https://mpv.io>`_ to annotate
videos with tags while you watch them.

Initially created to allow non-technical individuals to help build
datasets which could be used to train machine learning models. It's been
open sourced as it could potentially have many more uses.

`Click here <https://www.youtube.com/watch?v=ILiBkTo9qWo>`_ to see a
demo of Serkio Tagger displaying all the tags in a video while you watch
it.

.. image:: https://raw.github.com/SerkioTeam/Tagger/master/demo-video/readme.gif
    :alt: Demo of `Serkio Tagger` in `heads up display` mode
    :align: center
    :target: https://www.youtube.com/watch?v=ILiBkTo9qWo


Who's this for?
---------------

Movie buffs, celeb fans, trivia lovers, vloggers and video producers,
marketers, journalists, researchers and machine learning enthusiasts.


Installation
------------

1. Install `mpv <https://mpv.io>`_.
2. Copy ``serkio-tagger.lua`` into ``~/.config/mpv/scripts``
   (``%appdata%\mpv\scripts`` on Windows). Alternatively, you can use
   the ``--script serkio-tagger.lua`` option each time you run **mpv**.
3. When **mpv** is running, press ``Ctrl+t`` to enable Serkio Tagger.

`Click here <https://mpv.io/manual/master/#lua-scripting>`_ for more
information on **mpv** scripts.


Running the Demo
----------------

To see how existing tags are displayed, run the following command within
this repository.

.. code-block:: bash

    $ mpv --script=serkio-tagger.lua demo-video/Adventure-Time-intro.mkv

Then enable Serkio Tagger by pressing ``Ctrl+t`` within **mpv**, and
finally press ``v`` to view all current tags.
