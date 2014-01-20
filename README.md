Redistat [![Build Status](https://travis-ci.org/bellycard/redistat.png?branch=master)](https://travis-ci.org/bellycard/redistat)
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

And run:

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
  * :mosaic (more on types below).
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

*The above methods also have support for multiple ids*.

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

#### Unique Counters

#### Mosaics







