= omnifocus

home :: https://github.com/seattlerb/omnifocus
rdoc :: http://seattlerb.rubyforge.org/omnifocus

== DESCRIPTION:

Synchronizes bug tracking systems to omnifocus.

== FEATURES/PROBLEMS:

* Pluggable to work with multiple bug tracking systems (BTS).
* Creates projects in omnifocus if needed.
* Creates tasks for multiple projects in omnifocus.
* Marks tasks complete if they've been closed in the BTS.

== SYNOPSIS:

    % of sync
    scanning ticket RF#3802
    removing parsetree # 314159
    creating parsetree # 3802
    ...

== Known Plugins:

+ omnifocus-bugzilla       by kushali
+ omnifocus-github         by zenspider
+ omnifocus-pivotaltracker by vanska
+ omnifocus-redmine        by kushali
+ omnifocus-rt             by kushali
+ omnifocus-rubyforge      by zenspider
+ omnifocus-lighthouse     by juliengrimault

== REQUIREMENTS:

* mechanize
* rb-appscript

== INSTALL:

* sudo gem install omnifocus

== LICENSE:

(The MIT License)

Copyright (c) Ryan Davis, seattle.rb

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
