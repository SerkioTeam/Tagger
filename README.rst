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


Creating Tags
-------------

Tags consist of a ``name``, ``start time`` and an ``end time``. You can
create as many tags as you like.

Let's say you have a 70 second video-clip and a dog walks into the video
around 10 seconds in and then walks off at 40 seconds::


  00:00                                                                                          01:10
  +--------------------------------------------------------------------------------------------------+
            |                                |
        dog enters                       dog leaves


1. Start **mpv**, e.g. ``mpv --script=serkio-tagger.lua dog-video.mp4``
2. Enable Serkio Tagger with ``ctrl+t``.
3. Select the ``dog`` tag by pressing ``t``, then typing **dog** and
   pressing ``Enter`` (the tag is created if it doesn't exist).
4. Press ``m`` to mark the ``start time`` of a tag, then press ``m``
   again to mark the ``end time`` of a tag.

You can press ``m`` as many times as you like, so if the dog kept
reappearing, you can tag every instance of it.

Tags will be saved with a file named after the video filename (in the
same directory). For example: ``dog-video.mp4`` tags will be saved in
``dog-video.json``.


Tag File Format
---------------

Tags are saved in the following JSON format with ``start`` and ``end``
times being saved in milliseconds:

.. code-block:: javascript

    {
      "name": "dog-video.mp4",
      "filename": "dog-video.mp4",
      "duration": "00:01:10.011",
      "tags": {
        "dog": [
          [
            10031,
            40310
          ],
          [
            50032,
            90783
          ]
        ],
        "table": [
          [
            1032,
            42030
          ]
      }
    }

With this example we can see:

* ``dog`` appears twice in the video (*00:10* to *00:40*, and again
  between *00:50* and *01:30*).
* ``table`` appears once in the video (*00:01* to *00:42*).

Tagging Tips
------------

* Pausing the video (``space``) and stepping through it
  *frame-by-frame* (``,`` and ``.``) makes it easier to precisely tag
  things (additionally, holding down ``,`` or ``.`` skips through frames
  faster).
* To find out if something is big enough to be worth tagging, you can
  use the **box tool**. Click anywhere on the video, then click and
  drag to draw a box over the thing you want to tag. If the percentage
  number turns green, it's an indicator that it's big enough to tag.
* You're not limited to tagging objects, you could tag *sounds*,
  *actors*, *scenes*, *actions*… absolutely anything.

Running the Test Suite
----------------------

Install `busted <https://olivinelabs.com/busted/>`_ and run:

.. code-block:: bash

    $ busted serkio-tagger-tests.lua
