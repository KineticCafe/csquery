# CSQuery

[![Build Status][build_status_svg]][build status]

A query builder for the AWS [CloudSearch][] [structured search
syntax][sss]. This query builder is largely inspired by [csquery for
Python][csquery.py].

## Installation

`CSQuery` is a pure library, so it only needs to be added to your dependencies.

```elixir
@deps [
  csquery: "~> 1.0"
  # OR: {:csquery, github: "KineticCafe/csquery"}
]

def deps: @deps
```

## Introduction and Usage

`CSQuery` is a structured search syntax query builder for AWS CloudSearch. It
serves one purpose: build a structured query. It does not integrate with
any networking library. The queries built with this library are raw input to
the `q` parameter of a CloudSearch request when `q.parser=structured`.

It does not support, and will not support, other query parsers provided by AWS
CloudSearch (simple, lucene, or dismax). Other libraries may be able to provide
structured query building for those parsers.

CSQuery provides two ways of building a query:

*   A DSL-style approach like the Python implementation:

    ```elixir
    iex> and!([title: "star", actor: "Harrison Ford", boost: 2]) |> to_query()
    "(and boost=2 title:'star' actor:'Harrison Ford')"
    ```

*   A structured parser:

    ```elixir
    iex> parse(and: [title: "star", actor: "Harrison Ford", boost: 2]) |>
    ...> to_query()
    "(and boost=2 title:'star' actor:'Harrison Ford')"
    ```

The structured parser feels like it fits better in the style of Elixir,
especially with complex queries (see below). Both are supported (and are
implemented the same way). The documentation for each operator is on the
DSL-like functions below (as with `and!/1`), but examples are given for both
forms.

### Complex Queries

A complex query can be built with sufficient nesting:

```elixir
iex> and!([
...>  not!(["test", field: "genres"]),
...>  or!([
...>    term!(["star", field: "title", boost: 2]),
...>    term!(["star", field: "plot"])
...>  ])
...> ]) |> to_query
"(and (not field=genres 'test') (or (term boost=2 field=title 'star') (term field=plot 'star')))"

iex> parse(and: [
...>  not: ["test", field: "genres"],
...>  or: [
...>    term: ["star", field: "title", boost: 2],
...>    term: ["star", field: "plot"]
...>  ]
...> ]) |> to_query
"(and (not field=genres 'test') (or (term boost=2 field=title 'star') (term field=plot 'star')))"
```

It is also possible to mix and match the forms (but please avoid this):

```elixir
iex> parse(and: [
...>  not!(["test", field: "genres"]),
...>  or: [
...>    term: ["star", field: "title", boost: 2],
...>    term: ["star", field: "plot"]
...>  ]
...> ]) |> to_query
"(and (not field=genres 'test') (or (term boost=2 field=title 'star') (term field=plot 'star')))"
```

### Supported Field Value Data Types:

*   Strings:

    ```elixir
    iex> term!(["STRING"]) |> to_query
    "(term 'STRING')"
    ```

*   Ranges:

    ```elixir
    iex> range!([1..2]) |> to_query
    "(range [1,2])"

    iex> range!([{nil, 10}]) |> to_query
    "(range {,10])"

    iex> range!([{10, nil}]) |> to_query
    "(range [10,})"

    iex> range!([CSQuery.Range.new(%{first?: 0, last?: 101})]) |> to_query
    "(range {0,101})"
    ```

*   Numbers:

    ```elixir
    iex> term!([10]) |> to_query
    "(term 10)"

    iex> term!([3.14159]) |> to_query
    "(term 3.14159)"
    ```

*   DateTime (`t:DateTime.t/0`):

    ```elixir
    iex> %DateTime{
    ...>  year: 2018, month: 7, day: 21,
    ...>  hour: 17, minute: 55, second: 0,
    ...>  time_zone: "America/Toronto", zone_abbr: "EST",
    ...>  utc_offset: -14_400, std_offset: 0
    ...> } |> List.wrap() |> term! |> to_query
    "(term '2018-07-21T17:55:00-04:00')"
    ```

*   Terms:

    ```elixir
    iex> or!(["(and 'star' 'wars')", "(and 'star' 'trek')"]) |> to_query
    "(or (and 'star' 'wars') (and 'star' 'trek'))"
    ```

## ExAws.CloudSearch Support

The forthcoming ExAws.CloudSearch library will recognize CSQuery-generated
expressions and configure its query request so that the structured parser is
used.

## Community and Contributing

We welcome your contributions, as described in [Contributing.md][]. Like all
Kinetic Cafe [open source projects][], is under the Kinetic Cafe Open Source
[Code of Conduct][kccoc].

[build status svg]: https://travis-ci.org/KineticCafe/csquery.svg?branch=master
[build status]: https://travis-ci.org/KineticCafe/csquery
[Hex.pm]: https://hex.pm
[Contributing.md]: Contributing.md
[open source projects]: https://github.com/KineticCafe
[kccoc]: https://github.com/KineticCafe/code-of-conduct
[CloudSearch]: https://docs.aws.amazon.com/cloudsearch/
[sss]: https://docs.aws.amazon.com/cloudsearch/latest/developerguide/search-api.html#structured-search-syntax
[csquery.py]: https://github.com/tell-k/csquery
