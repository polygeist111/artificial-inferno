Nepenthes
=========

This is a tarpit intended to catch web crawlers. Specifically, it
targets crawlers that scrape data for LLMs - but really, like the
plants it is named after, it'll eat just about anything that finds it's
way inside.

It works by generating an endless sequences of pages, each of which with
dozens of links, that simply go back into a the tarpit. Pages are
randomly generated, but in a deterministic way, causing them to appear
to be flat files that never change. Intentional delay is added to
prevent crawlers from bogging down your server, in addition to wasting
their time. Lastly, Markov-babble is added to the pages, to give the
crawlers something to scrape up and train their LLMs on, hopefully
accelerating model collapse.

[You can take a look at what this looks like, here. (Note: VERY slow page loads!)](https://zadzmo.org/nepenthes-demo)

***WARNING***
-------------

THIS IS DELIBERATELY MALICIOUS SOFTWARE INTENDED TO CAUSE HARMFUL
ACTIVITY. DO NOT DEPLOY IF YOU AREN'T FULLY COMFORTABLE WITH WHAT YOU
ARE DOING.

***ANOTHER WARNING***
---------------------

LLM scrapers are relentless and brutal. You may be able to keep them at
bay with this software; but it works by providing them with a
neverending stream of exactly what they are looking for. YOU ARE LIKELY
TO EXPERIENCE SIGNIFICANT CONTINUOUS CPU LOAD.

Great effort has been taken to make Nepenthes more performant and use
the bare minimum of system resources, but it is still trivially easy
to misconfigure in a way that can take your server offline. This is
especially true if some of the agressive, less well behaved crawlers
find your instance.

***YET ANOTHER WARNING***
-------------------------

There is not currently a way to differentiate between web crawlers that
are indexing sites for search purposes, vs crawlers that are training
AI models. ANY SITE THIS SOFTWARE IS APPLIED TO WILL LIKELY DISAPPEAR
FROM ALL SEARCH RESULTS.

So why should I run this, then?
-------------------------------

So that, as I said to
[Ars Technica](https://arstechnica.com/tech-policy/2025/01/ai-haters-build-tarpits-to-trap-and-trick-ai-scrapers-that-ignore-robots-txt/),
we can fight back. Make your website indigestible to scrapers and
grow some spikes.

Instead of rolling over and letting these assholes do what they want,
make them have to work for it instead.

Further questions? I made a [FAQ](/code/nepenthes/FAQ.md) page.


Latest Version
--------------

[Nepenthes 2.3](https://zadzmo.org/downloads/nepenthes/file/nepenthes-2.3.tar.gz)

[Docker Image](https://zadzmo.org/downloads/nepenthes/docker)

[Latest Permalink](https://zadzmo.org/downloads/nepenthes/latest)

[All downloads](https://zadzmo.org/downloads/nepenthes)

[RSS feed of releases](https://zadzmo.org/downloads/nepenthes/rss)


Installation
------------

You can use Docker, or install manually. The latest Dockerfile and
compose.yml can be found at the
[Download Manager.](https://zadzmo.org/downloads/nepenthes/docker/latest)



For Manual installation, you'll need to install Lua. Nepenthes makes use
of the to-close feature, so Lua 5.4 is required. OpenSSL is also needed
for cryptographic functions.

The following Lua modules need to be installed - if they are all present
in your OS's package manager, use that; otherwise you will need to install
Luarocks and use it to install the following:

- [cqueues](https://luarocks.org/modules/daurnimator/cqueues)
- [ossl](https://luarocks.org/modules/daurnimator/luaossl) (aka luaossl)
- [lpeg](https://luarocks.org/modules/gvvaughan/lpeg)
- [lzlib](https://luarocks.org/modules/hisham/lzlib)
	(or [lua-zlib](https://luarocks.org/modules/brimworks/lua-zlib),
	only one of the two needed)
- [unix](https://luarocks.org/modules/daurnimator/lunix) (aka lunix)


Create a nepenthes user (you REALLY don't want this running as root.)
Let's assume the user's home directory is also your install directory.

```sh
useradd -m nepenthes
```

Unpack the tarball:

```sh
cd scratch/
tar -xvzf nepenthes-2.2.tar.gz
cp -r nepenthes-2.2/* /home/nepenthes/
```

Tweak config.yml as you prefer (see below for documentation.) Then you're
ready to start:

```sh
su -l -u nepenthes /home/nepenthes/nepenthes /home/nepenthes/config.yml
```

Sending SIGTERM or SIGINT will shut the process down.


Webserver Configuration
-----------------------

Expected usage is to hide the tarpit behind nginx or Apache, or whatever
else you have implemented your site in. Directly exposing it to the
internet is ill advised. We want it to look as innocent and normal as
possible; in addition HTTP headers can be used to configure the tarpit.

I'll be using nginx configurations for examples. Here's a real world
snippet for the demo above:

```nginx
location /maze/ {
	proxy_pass http://localhost:8893;
	proxy_set_header X-Forwarded-For $remote_addr;
	proxy_buffering off;
}
```


The X-Forwarded-For header is technically optional, but will make your
statistics largely useless.

The proxy_buffering directive is important. LLM crawlers typically
disconnect if not given a response within a few seconds; Nepenthes
counters this by drip-feeding a few bytes at a time. Buffering breaks
this workaround.

Nepenthes versions 1.x used an X-Prefix header; this has been removed.


Nepenthes Configuration
-----------------------

A very simple configuration, that matches the above nginx configuration
block, could be:

```yaml
---
http_host: '::'
http_port: 8893
templates:
  - '/usr/nepenthes/templates'
  - '/home/nepenthes/templates'
seed_file: '/home/nepenthes/seed.txt'

min_wait: 10
max_wait: 65

silos:
  - name: default
    wordlist: '/usr/share/dict/words'
    corpus: '/home/nepenthes/mishmash.txt'
    prefixes:
      - /maze
```

Most of the values should be self-explainatory. The 'silos' directive
is not optional (more on that later), however only one needs to be
defined.

Multiple template directories can be included, so you can bring your
own in from outside the Nepenthes distribution.

Multiple prefixes can be defined per silo. Sending a traffic with a
prefix that is not configured will likely fire the bogon filter, causing
Nepenthes to return a 404 HTTP status.


Markov
------

Nepenthes 2.0 and later keep the corpus entirely in memory; real world
testing shows this is a significant (40x) speedup with roughly the same
memory consumption, as SQLite used a significant amount of memory. The
only downside is startup time has increased, as it the corpus is
re-trained every time. For reasonable corpus sizes (60,000 lines or so)
on modern hardware, this training time at startup is several seconds.

Actual Markov parameters ( tokens generated, etc ) are now controlled
from within the templates.


Templates
---------

Template files consist of a two parts: A YAML prefix, and a Handlebars/
Lustache template. The
[default template](https://svn.zadzmo.org/repo/nepenthes/head/templates/default.lmt)
would be a good reference to look.

The 'markov', 'markov_array', 'link', and 'link_array' sections in the 
YAML portion are used to define variables that are passed to the 
templating engine. All are optional, but not having any would result in
a purely static document for every request.

- markov: Fills a variable with markov babble.
  - name: Variable name passed to the template.
  - min: Minimum number of 'tokens' - words, essentially - of markov slop to generate.
  - max: Maximum number of tokens

- markov_array: Like link_array, creates a random number of markov babble paragraphs.
  - name: Name of array variable passed to the template
  - min_count: Minimum number of paragraphs to generate, by default 2
  - max_count: Maximum number of paragraphs to generate, by default 5
  - markov_min: Minimum tokens per paragraph
  - markov_max: Maximum number of tokens per paragraph

- link: Creates a single named link.
  - name: Variable name passed to the template.
  - depth_min: The smallest number of words to put into the URL
  - depth_max: The largest number of words to put into the URL
  
- link_array: Creates a variable sized array of links.
  - min_count: Size of the smallest list of links to generate
  - max_count: Maximum number of links in the array
  - depth_min: The number smallest of words (from the given wordlist) to put into a URL,
  				ie, '/toque/Messianism/narrowly' has a depth of three.
  - depth_max: The largest number of words


The second portion of the template file is a Lustache template; you
can find detailed documentation at
[Lustache's website](https://olivinelabs.com/lustache/).


Statistics
----------

Nepenthes 2.0 and later do not store persistent statistics. The focus
is now on presenting a snapshot in time; the intent is to offload
detailed analysis to tools intended for such purposes such as an
external SQL database. The configuration variable stats_remember_time
sets the time horizon and defaults to one hour.

The top level /stats gives a broad overview, here's a real example
as I'm writing this:

```sh
curl http://localhost:8893/stats | jq
```
```json
{
  "addresses": 1850,
  "unsent_bytes_percent": 0.13952029418754,
  "hits": 10015,
  "agents": 145,
  "unsent_bytes": 20585,
  "cpu_percent": 1.7462639725424,
  "delay": 56020.624358161,
  "active": 25,
  "bytes_sent": 14733541,
  "uptime": 299516,
  "delay_total": 1936.808651157,
  "bytes_generated_total": 118800,
  "memory_usage": 210422861,
  "cpu_total": 5230.34,
  "bytes_generated": 14754126,
  "cpu": 10.335670266766,
  "bytes_sent_total": 118800,
  "hits_total": 100,
  "bogons": 4
}
```

Here we see, the past hour, 1850 distinct clients ('addresses') reached
the tarpit and made 10015 requests ('hits'), and presented 145 different
user-agent strings ('agents'). They were sent 14 megabytes of trash
('bytes_sent') and collectively waited 56020 seconds - 15 hours! - to
get said garbage ('delay').

There 25 active connections being served ('active') up slop as we speak,
and 20 kilobytes of slop that has been generated already but not sent
('unsent_bytes'). 'unsent_bytes_percent' is intended to be a gauge of
the effectiveness of the delay times: here it's less than 1 percent. If
unsent_bytes_percent rises significantly, it means crawlers are
routinely disconnecting before the request is finished.

Four requests ('bogons') asked for a URL that couldn't possibly be
generated by the configured word list.

To serve these 10015 requests, Nepenthes utilized the CPU for 10 seconds
of the previous hour ('cpu'), computed to be 1.74% of the CPU available
('cpu_percent'). (This isn't intended to be a precise metric; it doesn't
take into account multiple CPU's, and Nepenthes can only utilize one
currently.) 'cpu_total' is as reported by the Lua runtime since Nepenthes
was started; which was 299516 seconds ago ('uptime').

Memory used is 200 megabytes ('memory_usage'), as reported by the Lua
garbage collector.

Nepenthes 2.2 adds a few more: hits_total, bytes_generated_total,
bytes_sent_total, and delay_total. These are the same as hits,
bytes_generated, bytes_sent, and delay - EXCEPT, they are a running
total for the entire uptime of Nepenthes, and not simply a sum of the
rolling buffer.

Speaking of garbage collection: in some cases such as abnormal ends to
an HTTP transaction, like a client disconnecting before receiving all
data, the 'active' metric can read higher than is real. It should
eventually self correct as the garbage collector does it's job.

If you want to see actual agent strings or IP address information, that
can be returned as well:

```sh
curl http://localhost:8893/stats/agents | jq
```
```json
{
  "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko; compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm) Chrome/116.0.1938.76 Safari/537.36": 289,
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15": 3,
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36": 3,
  "Mozilla/5.0 (compatible; SemrushBot/7~bl; +http://www.semrush.com/bot.html)": 516,
  "Mozilla/5.0 (compatible; BLEXBot/1.0; +https://help.seranking.com/en/blex-crawler)": 480,
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:137.0) Gecko/20100101 Firefox/137.0": 9,
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0": 2,
  "Mozilla/5.0 (compatible; Barkrowler/0.9; +https://babbar.tech/crawler)": 146
}
```

```sh
curl http://localhost:8893/stats/addresses | jq
```
```json
{
  "3.224.205.25": 7,
  "44.207.207.36": 9,
  "54.89.90.224": 8,
  "66.249.64.9": 24,
  "2a03:2880:f806::": 2,
  "2a03:2880:f806:8::": 2,
  "2a03:2880:f806:29::": 2,
  "94.74.85.29": 2,
  "111.119.233.225": 1
}
```

Want to see the raw data? There's an endpoint for that too.

```sh
curl http://localhost:8893/stats/buffer | jq
```
```json
[
  {
    "address": "fda0:bb68:b812:d00d:8aae:ddff:fe42:62fe",
    "complete": true,
    "when": 886257.9491666,
    "delay": 19.389002208016,
    "cpu": 0.019220833084546,
    "uri": "/maze/mingelen/sipe/piles/suaharo",
    "id": "1757365444.1",
    "silo": "default",
    "bytes_generated": 1188,
    "agent": "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
    "response": 200,
    "bytes_sent": 1188
  },
  {
    "address": "fda0:bb68:b812:d00d:8aae:ddff:fe42:62fe",
    "complete": true,
    "when": 886291.34533826,
    "delay": 16.663

...etc
```

To facilite data export to an analysis system, the "ID" parameter is
unique to all requests even if Nepenthes is restarted. You can ask
Nepenthes to only send data _after_ a specific ID, preventing duplicates
from being imported:

```sh
curl http://localhost:8893/stats/buffer/from/1757365444.1 | jq
```


Silos
-----

Version 2.0 Provides for Silos, which work similarly in concept to
virtual hosts on a web server. Each silo can have it's own
configuration, including Markov corpus, wordlist, delay times,
statistics, template, etc. This is specified in the configuration YAML.

```yaml
silos:
  - name: fast
    corpus: /vol/nepenthes/corpus-1.txt
    wordlist: /vol/nepenthes/words-1.txt
    default: true
    min_delay: 15
    max_delay: 20
    prefixes:
      - /maze

  - name: slow
    corpus: /vol/nepenthes/corpus-2.txt
    wordlist: /vol/nepenthes/words-2.txt
    template: slowerpage
    min_delay: 200
    max_delay: 300
    prefixes:
      - /theslowhole
```

Silos can share a markov corpus - or also have separate ones. Simply
specify the same filename to share a corpus; Nepenthes won't train it
twice. The same is true of wordlists used to build URLs.


The header X-Silo is used to signify which silo the incoming request
should be put into:

```nginx
location /maze/ {
	proxy_pass http://localhost:8893;
	proxy_set_header X-Silo 'fast';
	proxy_set_header X-Forwarded-For $remote_addr;
	proxy_buffering off;
}

location /theslowhole/ {
	proxy_pass http://localhost:8893;
	proxy_set_header X-Silo 'slow';
	proxy_set_header X-Forwarded-For $remote_addr;
	proxy_buffering off;
}
```

If the X-Silo header is not present, the request will be placed in
the default silo, marked by the 'default' boolean in the configuration
above. Specifying more than one default will cause an error on startup.
If a default silo is not specified, the first silo listed in the
configuration will be assumed to be the default one.


Statics can be filtered on a per-silo basis:

```sh
curl http://localhost:8893/stats/silo/slow | jq
```
```sh
curl http://localhost:8893/stats/silo/slow/agents | jq
```
```sh
curl http://localhost:8893/stats/silo/slow/addresses | jq
```

Configuration File Reference
----------------------------

All possible directives in config.yaml:

 - #### http_host
   Sets the host that Nepenthes will listen on; default is localhost only.

 - #### http_port
   Sets the listening port number; default 8893

 - #### unix_socket
   Sets a path to a unix domain socket to listen on. Default is nil. If
   specified, will override http_host and http_port, and only listen on
   Unix domain sockets.

 - #### nochdir
	If true, do not change directory after daemonization. Default is
	false. Normally only used for development/debugging as it allows for
	relative paths in the configuration, but is bad practice (daemons
	should, in fact, chdir to '/' after forking.

 - #### templates
	Paths to the template files. This should include the '/templates'
	directory inside your Nepenthes installation, and any other
	directories that contain templates you want to use.

 - #### detach
	If true, Nepenthes will fork into the background and redirect
	logging output to Syslog. Default is false.

 - #### log_level
	Log message filtering; This uses the same priorties as syslog.
	Defaults to 'info'.

 - #### pidfile
	Path to drop a pid file after daemonization. If left unset, no pid
	file is created.

 - #### real_ip_header
	Changes the name of the X-Forwarded-For header that	communicates
	the actual client IP address for statistics gathering.

 - #### silo_header
	Changes the name of the X-Silo header that controls silo assignment.

 - #### seed_file
	Specifies location of persistent unique instance identifier. This
	allows two instances with the same corpus to have different looking
	tarpits. If not specified, the seed will not persist, causing pages
	to change if Nepenthes is restarted.

 - #### stats_remember_time
	Sets how long entries remain in the rolling	stats buffer, in
	seconds. Defaults to 3600 (one hour.)

 - #### min_wait
	Default minimum delay time if not specified in a silo configuration.

 - #### max_wait
	Default maximum delay time if not specified in a silo configuration.

 - #### silos
 	Each silo takes the following configuration options:

   - #### name
		Name of the silo, which is matched against the X-Silo header.
		Required to be set.

   - #### template
   		Template file to use in this silo. Default is 'default',
   		included in the Nepenthes distribution.

   - #### min_wait
  		Optional. Minimum delay time in this silo.

   - #### max_wait
   		Optional. Maximum delay time in this silo.

   - #### default
   		Boolean value. If set to 'true', marks this as the default silo.

   - #### corpus
   		Path to a text file containing the markov corpus for training.
   		Required to be set.

   - #### wordlist
   		Path to a dictionary file for URL generation, eg,
   		'/usr/share/dict/words' will work on most systems.
   		Required to be set.

   - #### prefixes
   		A list of URL prefixes that are valid for this silo. Optional.
   		If not set, all pages generated in this silo will have links
   		pointing to the top level of the website.

   - #### zero_delay
   		Optional. Overrides 'min_wait' and 'max_wait' for this silo,
   		short circuits the entirely of the delay code, and shoves the
     	generated page at whatever unfortunate client as fast as they
     	can take it. Use with caution! Some crawlers move fast with very
     	high concurrency, so this could cause high CPU load on your
     	server and/or use significant bandwidth.


License Info
------------

Nepenthes is distributed under the terms of the MIT License, see the
file 'LICENSE' in the source distribution. In addition, the release
tarball contains several 3rd party components, see external/README.
Using or distributing Nepenthes requires agreeing to these license
terms as well. As of v2.0, all are also MIT or X11 licenses; copies
can be find in external/license.


History
-------

Version numbers use a simple process: If the only changes are fully
backwards compatible, the minor number changes. If the user or
administrator needs to change anything after or part of the upgrade, the
major number changes and the minor number resets to zero.

[Legacy 1.x Documentation](https://zadzmo.org/code/nepenthes/version-1-documentation.md)

- #### v1.0:
  Initial release

- #### v1.1:
  Clearer licensing

  Small performance improvements

  Clearer logging

  Corpus reset

  Evasion countermeasures

  Corpus Statistics report endpoint

  Unix domain socket support

- #### v1.2:
  Bugfix in Bogon filter for UTF8 characters

  Fix rare crash with stacktrace

- #### v2.0:
  Total overhaul/refactor

  In-memory corpus

  Silos

  Rolling Stats buffer

  Expandable templates

- #### v2.1:
  New Feature: Zero Delay Mode
  
- #### v2.2:
  New features:
  
  markov_array template option
  
  hits_total, etc metrics added to statistics
  
- #### v2.3:
  Bugfix: Bootstrap often failing during manual installation
