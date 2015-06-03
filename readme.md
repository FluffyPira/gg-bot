## GG-bot
New and improved. GG-bot.

A bot that builds its corpus, solely from posts tagged #GamerGate. Could be easily modified to fit any search term or tag.

As bot is based on [twitter_ebooks](https://github.com/mispy/twitter_ebooks), it is best to consult that page for instruction on how to properly set up the bot. Oauth may be required to complete this. I made a [fancy guide](http://tumblr.fluffypira.sexy/post/111262086438/i-am-ebooks-and-so-can-you) that explains how to set up a twitter bot as well.

To build corpus simply uncomment two lines in bots.rb, run the command 'ebooks start' in the folder, have the first run simply build the corpus file. After the file is build, the bot should crash. Type 'ebooks consume corpus/<botname>.txt' and re-run the bot (ebooks start). 

I promise that _eventually_ I will build a second script to build a corpus.