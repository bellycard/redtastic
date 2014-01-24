Redistat [![Build Status](https://travis-ci.org/bellycard/redistat.png?branch=master)](https://travis-ci.org/bellycard/redistat) [![Coverage Status](https://coveralls.io/repos/bellycard/redistat/badge.png)](https://coveralls.io/r/bellycard/redistat)
========

*Some description of what this is here*

Installation
------------

```
$ gem install redistat
```

or in your **Gemfile**

``` ruby
gem 'redistat'
```

and run:

```
$ bundle install
```

Then initialize redistat in your application & connect it with a redis instance:

``` ruby
$redis = Redis.new
Redistat::Connection.establish_connection($redis, 'namespace')
```
\* *specifying a namespace is optional and is used to avoid key collisions if multiple applications are using the same instance of Redis.*

Usage
-----

### Defining a Redistat Model

First, create a Redistat Model:

``` ruby
class Checkins < Redistat::Model
  type :counter
  resolution :days
end
```

The class must inherit from Redistat::Model and provide some attributes:
* **type:** *Required*.  The data type of the model.  Valid values include:
  * :counter
  * :unique
  * :mosaic (more on types [below](https://github.com/bellycard/redistat#redistat-types)).
* **resolution:** *Optional*.  The degree of fidelity you would like to store this model at.  Valid values include:
  * :days
  * :weeks
  * :months
  * :years
  * nil

\* *Note that methods requesting results at a higher resolution than that of the model will not work.  Using a lower resolution will result in less memory utilization and will generally see faster query response times.*

### Using Redistat Models

Incrementing / decrementing counters:

``` ruby
Checkins.increment(id: 1, timestamp: '2014-01-01')
Checkins.decrement(id: 1, timestamp: '2014-01-01')
```

Find a value of a counter for a single / day / week / month / year:

``` ruby
Checkins.find(id: 1, year: 2014, month: 1, day: 5)  # Day
Checkins.find(id: 1, year: 2014, week:  2)          # Week
Checkins.find(id: 1, year: 2014, month: 1)          # Month
Checkins.find(id: 1, year: 2014)                    # Year
```

Find the aggregate total over a dataspan:

``` ruby
Checkins.aggregate(id: 1, start_date: '2014-01-01', end_date: '2014-01-05')
```

Get the aggregate total + data points for each date at the specified interval:

``` ruby
Checkins.aggregate(id: 1, start_date: '2014-01-01', end_date: '2014-01-05', interval: :days)
```

### Multiple Ids

The above methods also have support for multiple ids.

Incrementing / decrementing multiple ids in one request:

``` ruby
Checkins.increment(id: [1001, 1002, 2003], timestamp: '2014-01-01')
Checkins.decrement(id: [1001, 1002, 2003], timestamp: '2014-01-01')
```

Find for mutiple ids at once:

``` ruby
Checkins.find(id: [1001, 1002, 2003], year: 2014, month: 1, day: 5)
```

Aggregations across mutiple ids can be quite powerful:

``` ruby
Checkins.aggregate(id: [1001, 1002, 2003], start_date: '2014-01-01', end_date: '2014-01-05')
```

As well as aggregating across mutiple ids w/ data points at the specified interval:

``` ruby
Checkins.aggregate(id: [1001, 1002, 2003], start_date: '2013-01-01', end_date: '2014-01-05', interval: :days)
```

### Redistat Types

#### Counters

Counters are just what they appear to be - counters of things.  Examples of using counters is shown in the previous two sections.

#### Unique Counters

Unique counters are used when an event with the same unique_id should not be counted twice. A general example of this could be a counter for the number of users that visited a place. In this case the "id" parameter would represent the id of the place and the unique_id would be the users id.

**Examples**

Incrementing / Decrementing (adding / removing a unique_id from a set for a particular id / time):
``` ruby
Customers.increment(id: 1, timestamp: '2014-01-05', unique_id: 1000)
Customers.decrement(id: 1, timestamp: '2014-01-05', unique_id: 1000)
```

Find:
``` ruby
Customers.find(id: 1, year: 2014, month: 1, day: 5, unique_id: 1000) # Returns true or false
```

Find the aggregate total over a datespan (this would only return the *unique* aggregate total):
``` ruby
Customers.aggregate(id: 1, start_date: '2014-01-01', end_date: '2014-01-05')
```

Find the aggregate total + data points for each point at a specified interval (again, this returns not only the unique aggregate total, but also the unique total for each interval data point ~ being each day / week / month / year...etc)
``` ruby
Customers.aggregate(id: 1, start_date: '2014-01-01', end_date: '2014-01-05', interval: :days)
```

Unique counters also support querying mutiple ids.  For example, we can find the unique aggregate totals across multiple ids by doing:
``` ruby
Customers.aggregate(id: [1,2,3], start_date: '2014-01-01', end_date: '2014-01-05', interval: :days)
```

#### Mosaics

### Misc

#### Script Manager

Redistat also provides access to the *Redistat::ScriptManager* class which it uses internally to pre-load & provide an interface to running Lua Scripts on Redis.  Although it is used by Redistat to run its own scripts, anybody can use it to run their own custom scripts defined in their application:

Create a script: *./lib/scripts/hello.lua*
``` lua
return 'hello'
```
Tell ScriptManager to pre-load your scripts (after initializing Redistat)
``` ruby
Redistat::ScriptManager.load_scripts('./lib/scripts')
```

Now you can easily use your script anywhere in your application:
``` ruby
puts Redistat::ScriptManager.hello # prints 'hello'
```

with every script having the ability to accept parameters for the KEYS & ARGV arrays:
```ruby
  keys = []
  argv = []
  Redistat::ScriptManager.hello(keys, argv)
```

Performance
-----------

Contributing
------------

TODOS
-----
* Set elapsed expiration times for each resolution of a model (ie. keys of resolution days expire in 1 year, months expire in 2 years...etc).
* For large, multi-id aggregations, set batch size & do aggregations in serveral batches rather than all in one lua run to prevent long running lua scripts from blocking any other redis operation.
* Support for hourly resolutions








