# Omnifocus

> Synchronizes bug tracking systems to omnifocus.

[home](https://github.com/seattlerb/omnifocus)
[rdoc](http://docs.seattlerb.org/omnifocus)

## FEATURES/PROBLEMS:

* Pluggable to work with multiple bug tracking systems (BTS).
* Creates projects in omnifocus if needed.
* Creates tasks for multiple projects in omnifocus.
* Marks tasks complete if they've been closed in the BTS.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'omnifocus'
```

And then execute:

    $ bundle

Or install it yourself as:

	$ sudo gem install omnifocus


## REQUIREMENTS:

* mechanize
* rb-appscript

## SYNOPSIS:

```
% of sync
scanning ticket RF#3802
removing parsetree # 314159
creating parsetree # 3802
...
```

## Known Plugins:

+ omnifocus-bugzilla       by kushali
+ omnifocus-github         by zenspider
+ omnifocus-pivotaltracker by vesan
+ omnifocus-redmine        by kushali
+ omnifocus-rt             by kushali
+ omnifocus-rubyforge      by zenspider
+ omnifocus-lighthouse     by juliengrimault
+ omnifocus-trello         by vesan

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
