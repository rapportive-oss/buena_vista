BuenaVista Rails plugin
=======================

The BuenaVista plugin makes your views nice. :)

There are some things you want to do in your Rails templates which make them nicer
for human consumption, but which are actually a bit tricky to do in practice. So it's
very tempting to get lazy and just do the simple thing instead. However, if you
really care about your user experience, you know that attention to detail matters.

In the BuenaVista plugin, we have collected a few reusable tools and helpers which
make it easier to implement those details which make your application beautiful and
delightful. See below for the things included.

To add BuenaVista to your Rails project:

    $ ./script/plugin install git://github.com/rapportive-oss/buena_vista.git

To use BuenaVista's view helpers, add the following to your `ApplicationHelper`
(or other helper modules):

    module ApplicationHelper
      include BuenaVista::ViewHelpers
    end


Intelligent truncation
----------------------

Sometimes we want to show the user the beginning of a chunk of text, and give them
the option to expand the rest if they are interested. Fair enough. So we have to
decide at what point we truncate the text. The obvious way of doing this is:

    visible, hidden = text[0...VISIBLE_LENGTH] + '...', text[VISIBLE_LENGTH..-1]

...but of course that will truncate your text without any regard for the content.
Don't you hate it when a website truncates text in the middle of a word? I think
it's really ugly and it tells the user that we don't really care about them as a
human being.

Enter `BuenaVista::ViewHelpers#truncate_text`, which does truncation *nicely*.
It will prefer to break at the end of a sentence or paragraph, if possible; if
there's no sentence boundary nearby, it tries other punctuation; if that's not
convenient, at least it puts the split between two words. Only in very exceptional
cases do we split a word part way through.


More to come
------------

From time to time we will extract reusable bits from the Rapportive codebase and
add them to this plugin.

Patches are welcome. Please fork the repository, make sure you add tests for your
changes, and send us a GitHub pull request.


Who made this?
--------------

We are [Rapportive](http://rapportive.com), a San Francisco startup making email
a better place. We currently have a browser extension for Gmail which provides
information from social networks and business applications in a sidebar next to
your conversations.

By the way, we are hiring -- and if you're the sort of person who likes to explore
stuff on GitHub (as you are apparently doing), and you'd like to work with code
like this, you're exactly the kind of person we'd like to talk to. So please
[get in touch](http://rapportive.com)!

Copyright (c) 2010 Rapportive, Inc. Released under the terms of the MIT license.
