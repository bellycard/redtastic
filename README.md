Redtastic [![Build Status](https://travis-ci.org/bellycard/redtastic.png?branch=master)](https://travis-ci.org/bellycard/redtastic) [![Coverage Status](https://coveralls.io/repos/bellycard/redtastic/badge.png?branch=master)](https://coveralls.io/r/bellycard/redtastic?branch=master) [![Gem Version](https://badge.fury.io/rb/redtastic.png)](http://badge.fury.io/rb/redtastic)
========

Redtastic!  Why?  Because using Redis for analytics is fantastic!

Redtastic provides a interface for storing, retriveing, and aggregating time intervalled data.  Applications of Redtastic include developing snappy dashboards containing daily / monthly / yearly counts over time.  Additionally Redtastic allows for the "mashing-up" of different statistics, allowing the drilling down of data into specific subgroups (such as "Number of unique customers who are also male, android users...etc").

Redtastic is backed by [Redis](http://redis.io) - so it's super fast.

Installation
------------

```
$ gem install redtastic
```

or in your **Gemfile**

``` ruby
gem 'redtastic'
```

and run:

```
$ bundle install
```

Then initialize Redtastic in your application & connect it with a redis instance:

``` ruby
$redis = Redis.new
Redtastic::Connection.establish_connection($redis, 'namespace')
```
\* *specifying a namespace is optional and is used to avoid key collisions if multiple applications are using the same instance of Redis.*

Usage
-----

### Defining a Redtastic Model

First, create a Redtastic Model:

``` ruby
class Checkins < Redtastic::Model
  type :counter
  resolution :days
end
```

The class must inherit from Redtastic::Model and provide some attributes:
* **type:** *Required*.  The data type of the model.  Valid values include:
  * :counter
  * :unique (more on types [below](https://github.com/bellycard/Redtastic#Redtastic-types)).
* **resolution:** *Optional*.  The degree of fidelity you would like to store this model at.  Valid values include:
  * :days
  * :weeks
  * :months
  * :years
  * nil

\* *Note that methods requesting results at a higher resolution than that of the model will not work.  Using a lower resolution will result in less memory utilization and will generally see faster query response times.*

### Using Redtastic Models

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

### Redtastic Types

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

#### Attributes

Attributes are unique counters that are not associated with an id, and can be thought of as a type of "global" group.  This can be mashed up with other unique counters that are associated with ids to give the same result as if they were associated with that id.  The main advantages to using this technique are:

* Save a tremendous amount of memory by not storing this data, for ever resolution interval, for every id
* Easier to update / maintain / rebuilding data is much quicker ( instead of having to update at every interval / id, you can just update it once at the "global" level)

This is best explained with the example below.

Say you have a unique counter "Customers", and a unique couner "Males".  Instead of storing them both at the id & daily level we can get the number of males / day / id with the following:

```ruby
class Customers < Redtastic::Model
  type :unique
  resolution :days
end

class Males < Redtastic::Model
  type :unique
end
```

then to mash up Customers against Males, just use the attributes parameter:

```ruby
Customers.aggregate(id: 1, start_date: '2014-01-01', end_date: '204-01-09', attrbiutes: [:males])
```

You can even mash up multiple attributes.  Suppose I want to see all the customers who are Male and Android Users.  First add the AndroidUsers class:

```ruby
class AndroidUsers < Redtastic::Model
  type :unique
end
```

then just add that into the query:

```ruby
Customers.aggregate(id: 1, start_date: '2014-01-01', end_date: '2014-01-09', attributes: [:males, :android_users])
```

and just like every other example, attributes can be used in aggregations accross multiple ids:

```ruby
Customers.aggregate(id: [1,2,3], start_date: '2014-01-01', end_date: '2014-01-09', attributes: [:males, :android_users])
```

All the methods available to unique counters can be used for unique counters acting as global attributes, with a few simplifications.  Obviously, if it does not have a resolution and is not associated with an id, then there is no need to pass those parameters into any of those.

For example, adding / removing a unique_id to a global attribute set:

```ruby
Males.increment(unique_id: 1000)
Males.decrement(unique_id: 1000)
```

or seeing if a unique_id is in a global set:

```ruby
Males.find(unique_id: 1000)
```

### Misc

#### Script Manager

Redtastic also provides access to the *Redtastic::ScriptManager* class which it uses internally to pre-load & provide an interface to running Lua Scripts on Redis.  Although it is used by Redtastic to run its own scripts, anybody can use it to run their own custom scripts defined in their application:

Create a script: *./lib/scripts/hello.lua*
``` lua
return 'hello'
```
Tell ScriptManager to pre-load your scripts (after initializing Redtastic)
``` ruby
Redtastic::ScriptManager.load_scripts('./lib/scripts')
```

Now you can easily use your script anywhere in your application:
``` ruby
puts Redtastic::ScriptManager.hello # prints 'hello'
```

with every script having the ability to accept parameters for the KEYS & ARGV arrays:
```ruby
  keys = []
  argv = []
  Redtastic::ScriptManager.hello(keys, argv)
```

Performance
-----------

Contributing
------------

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

TODOS
-----
* Set elapsed expiration times for each resolution of a model (ie. keys of resolution days expire in 1 year, months expire in 2 years...etc).
* For large, multi-id aggregations, set batch size & do aggregations in serveral batches rather than all in one lua run to prevent long running lua scripts from blocking any other redis operation.
* Support for hourly resolutions








