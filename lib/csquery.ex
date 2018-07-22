defmodule CSQuery do
  @moduledoc """
  A query builder for the AWS [CloudSearch][] [structured search syntax][sss].
  This query builder is largely inspired by [csquery for Python][csquery.py].
  The queries built with this library are raw input to the `q` parameter of a
  CloudSearch request when `q.parser=structured`.

  CSQuery provides two ways of building a query:

  *   A DSL-style approach like the Python implementation:

      ```
      iex> and!([title: "star", actor: "Harrison Ford", boost: 2]) |> to_query()
      "(and boost=2 title:'star' actor:'Harrison Ford')"
      ```

  *   A structured parser:

      ```
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

  It is also possible to mix and match the forms (but please avoid this):

      iex> parse(and: [
      ...>  not!(["test", field: "genres"]),
      ...>  or: [
      ...>    term: ["star", field: "title", boost: 2],
      ...>    term: ["star", field: "plot"]
      ...>  ]
      ...> ]) |> to_query
      "(and (not field=genres 'test') (or (term boost=2 field=title 'star') (term field=plot 'star')))"

  ### Supported Field Value Data Types:

  *   Strings:

      ```
      iex> term!(["STRING"]) |> to_query
      "(term 'STRING')"
      ```

  *   Ranges:

      ```
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

      ```
      iex> term!([10]) |> to_query
      "(term 10)"

      iex> term!([3.14159]) |> to_query
      "(term 3.14159)"
      ```

  *   DateTime (`t:DateTime.t/0`):

      ```
      iex> %DateTime{
      ...>  year: 2018, month: 7, day: 21,
      ...>  hour: 17, minute: 55, second: 0,
      ...>  time_zone: "America/Toronto", zone_abbr: "EST",
      ...>  utc_offset: -14_400, std_offset: 0
      ...> } |> List.wrap() |> term! |> to_query
      "(term '2018-07-21T17:55:00-04:00')"
      ```

  *   Terms:

      ```
      iex> or!(["(and 'star' 'wars')", "(and 'star' 'trek')"]) |> to_query
      "(or (and 'star' 'wars') (and 'star' 'trek'))"
      ```

  ## ExAws.CloudSearch Support

  The forthcoming ExAws.CloudSearch library will recognize CSQuery-generated
  expressions and configure its query request so that the structured parser is
  used.

  [CloudSearch]: https://docs.aws.amazon.com/cloudsearch/
  [sss]: https://docs.aws.amazon.com/cloudsearch/latest/developerguide/search-api.html#structured-search-syntax
  [csquery.py]: https://github.com/tell-k/csquery
  """

  @operators ~w(and near not or phrase prefix range term)a
  @doc "Return the list of supported expression operators."
  @spec operators :: list(atom)
  def operators, do: @operators

  alias CSQuery.{Expression, FieldValue, OperatorOption}

  @doc """
  Create an unnamed field value matcher.

      iex> field(3)
      %CSQuery.FieldValue{value: 3}

      iex> CSQuery.FieldValue.to_value(field(3))
      "3"

      iex> field({1990, 2000})
      %CSQuery.FieldValue{value: %CSQuery.Range{first: 1990, last: 2000}}
  """
  @spec field(FieldValue.values()) :: FieldValue.t()
  defdelegate field(value), to: FieldValue, as: :new

  @doc """
  Create an optionally-named field value matcher.

      iex> field("title", 3)
      %CSQuery.FieldValue{name: "title", value: 3}

      iex> field(nil, 3)
      %CSQuery.FieldValue{name: nil, value: 3}

      iex> field(:year, {1990, 2000})
      %CSQuery.FieldValue{name: :year, value: %CSQuery.Range{first: 1990, last: 2000}}
  """
  @spec field(FieldValue.names(), FieldValue.values()) :: FieldValue.t()
  defdelegate field(name, value), to: FieldValue, as: :new

  @doc """
  Create an operator option.
  """
  @spec option(OperatorOption.names(), any) :: OperatorOption.t()
  defdelegate option(name, value), to: OperatorOption, as: :new

  @doc """
  Creates an `and` expression.

      (and boost=N EXPRESSION1 EXPRESSION2 ... EXPRESSIONn)

  ## Examples

  Find any document that has both 'star' and 'space' in the title.

      iex> and!(title: "star", title: "space") |> to_query
      "(and title:'star' title:'space')"

      iex> parse(and: [title: "star",  title: "space"]) |> to_query
      "(and title:'star' title:'space')"

  Find any document that has 'star' in the title, 'Harrison Ford' in actors,
  and the year is any time before 2000.

      iex> parse(and: [title: "star", actors: "Harrison Ford", year: {nil, 2000}]) |> to_query
      "(and title:'star' actors:'Harrison Ford' year:{,2000])"

      iex> and!(title: "star", actors: "Harrison Ford", year: {nil, 2000}) |> to_query
      "(and title:'star' actors:'Harrison Ford' year:{,2000])"

  Find any document that has 'star' in the title, 'Harrison Ford' in actors,
  and the year is any time after 2000. Note that the option name *must* be an
  atom.

      iex> and!([
      ...>   option(:boost, 2),
      ...>   field("title", "star"),
      ...>   field("actors", "Harrison Ford"),
      ...>    field("year", {2000, nil})
      ...> ]) |> to_query
      "(and boost=2 title:'star' actors:'Harrison Ford' year:[2000,})"

      iex> parse(and: [
      ...>   option(:boost, 2),
      ...>   field("title", "star"),
      ...>   field("actors", "Harrison Ford"),
      ...>    field("year", {2000, nil})
      ...> ]) |> to_query
      "(and boost=2 title:'star' actors:'Harrison Ford' year:[2000,})"

  Find any document that contains the words 'star' and 'trek' in any text or
  text-array field.

      iex> and!(["star", "trek"]) |> to_query
      "(and 'star' 'trek')"

      iex> parse(and: ["star", "trek"]) |> to_query
      "(and 'star' 'trek')"
  """
  @spec and!(keyword) :: Expression.t() | no_return
  def and!(list), do: Expression.new(:and, list)

  @doc """
  Creates an `or` expression.

      (or boost=N EXPRESSION1 EXPRESSION2 ... EXPRESSIONn)

  ## Examples

  Find any document that has 'star' or 'space' in the title.

      iex> or!(title: "star", title: "space") |> to_query
      "(or title:'star' title:'space')"

      iex> parse(or: [title: "star",  title: "space"]) |> to_query
      "(or title:'star' title:'space')"

  Find any document that has 'star' in the title, 'Harrison Ford' in actors,
  or the year is any time before 2000.

      iex> parse(or: [title: "star", actors: "Harrison Ford", year: {nil, 2000}]) |> to_query
      "(or title:'star' actors:'Harrison Ford' year:{,2000])"

      iex> or!(title: "star", actors: "Harrison Ford", year: {nil, 2000}) |> to_query
      "(or title:'star' actors:'Harrison Ford' year:{,2000])"

  Find any document that has 'star' in the title, 'Harrison Ford' in actors,
  or the year is any time after 2000. Note that the option name *must* be an
  atom.

      iex> or!([
      ...>   option(:boost, 2),
      ...>   field("title", "star"),
      ...>   field("actors", "Harrison Ford"),
      ...>    field("year", {2000, nil})
      ...> ]) |> to_query
      "(or boost=2 title:'star' actors:'Harrison Ford' year:[2000,})"

      iex> parse(or: [
      ...>   option(:boost, 2),
      ...>   field("title", "star"),
      ...>   field("actors", "Harrison Ford"),
      ...>    field("year", {2000, nil})
      ...> ]) |> to_query
      "(or boost=2 title:'star' actors:'Harrison Ford' year:[2000,})"

  Find any document that contains the words 'star' or 'trek' in any text or
  text-array field.

      iex> or!(["star", "trek"]) |> to_query
      "(or 'star' 'trek')"

      iex> parse(or: ["star", "trek"]) |> to_query
      "(or 'star' 'trek')"
  """
  @spec or!(keyword) :: Expression.t() | no_return
  def or!(list), do: Expression.new(:or, list)

  @doc """
  Creates a `not` expression.

      (not boost=N EXPRESSION)

  ## Examples

  Find any document that does not have 'star' or 'space' in the title.

      iex> not!([or!([title: "star", title: "space"])]) |> to_query
      "(not (or title:'star' title:'space'))"

      iex> [title: "star", title: "space"] |>
      ...> or!() |> List.wrap() |> not!() |> to_query
      "(not (or title:'star' title:'space'))"

      iex> parse(not: [or: [title: "star",  title: "space"]]) |> to_query
      "(not (or title:'star' title:'space'))"

  Find any document that does not have both 'Harrison Ford' in actors and a
  year before 2010.

      iex> parse(not: [and: [actors: "Harrison Ford", year: {nil, 2010}]]) |> to_query
      "(not (and actors:'Harrison Ford' year:{,2010]))"

      iex> not!([and!(actors: "Harrison Ford", year: {nil, 2010})]) |> to_query
      "(not (and actors:'Harrison Ford' year:{,2010]))"

  Find any document that does not contain the words 'star' or 'trek' in any
  text or text-array field.

      iex> not!([or!(["star", "trek"])]) |> to_query
      "(not (or 'star' 'trek'))"

      iex> parse(not: [or: ["star", "trek"]]) |> to_query
      "(not (or 'star' 'trek'))"

  If more than one expression is provided, `CSQuery.TooManyFieldValuesError`
  will be raised.

      iex> not!(["star", "space", boost: 2]) |> to_query
      ** (CSQuery.TooManyFieldValuesError) Expression for operator `not` has 2 fields, but should only have one.

  """
  @spec not!(keyword) :: Expression.t() | no_return
  def not!(list), do: Expression.new(:not, list)

  @doc """
  Creates a `near` expression.

      (near boost=N distance=N field=FIELD 'STRING')

  ## Examples

  Find any document that contains the words 'teenage' and 'vampire' within two
  words of each other in the plot field.

      iex> near!(["teenage vampire", boost: 2, distance: 2, field: "plot"]) |> to_query
      "(near boost=2 distance=2 field=plot 'teenage vampire')"

      iex> parse(near: ["teenage vampire", boost: 2, distance: 2, field: "plot"]) |> to_query
      "(near boost=2 distance=2 field=plot 'teenage vampire')"

  Find any document that contains the words 'teenage' and 'vampire' within
  three words in any text or text-array field.

      iex> near!(["teenage vampire", distance: 3]) |> to_query
      "(near distance=3 'teenage vampire')"

      iex> parse(near: ["teenage vampire", distance: 3]) |> to_query
      "(near distance=3 'teenage vampire')"

  If the field value is a string but does not contain a space,
  `CSQuery.Expression.MultipleWordsRequiredError` will be raised.

      iex> near!(["word"]) |> to_query
      ** (CSQuery.MultipleWordsRequiredError) Expression field value for operator `near` requires multiple words.

  If the field value is not a string,
  `CSQuery.Expression.NearFieldValuemustBeString` will be raised.

      iex> near!([2000, boost: 2, distance: 2, field: "title"]) |> to_query
      ** (CSQuery.StringRequiredError) Expression field value for operator `near` must be a string value.

  """
  @spec near!(keyword) :: Expression.t() | no_return
  def near!(list), do: Expression.new(:near, list)

  @doc """
  Creates a `phrase` expression.

      (phrase boost=N field=FIELD 'STRING')

  ## Examples

  Find any document that contains the exact phrase 'teenage vampire' in the
  plot field.

      iex> phrase!(["teenage vampire", boost: 2, field: "plot"]) |> to_query
      "(phrase boost=2 field=plot 'teenage vampire')"

      iex> parse(phrase: ["teenage vampire", boost: 2, field: "plot"]) |> to_query
      "(phrase boost=2 field=plot 'teenage vampire')"

  Find any document that contains the exact phrase 'teenage vampire' in any
  text or text-array field.

      iex> phrase!(["teenage vampire"]) |> to_query
      "(phrase 'teenage vampire')"

      iex> parse(phrase: ["teenage vampire"]) |> to_query
      "(phrase 'teenage vampire')"

  If more than one field value is provided, `CSQuery.TooManyFieldValuesError`
  will be raised.

      iex> phrase!(["teenage", "vampire"]) |> to_query
      ** (CSQuery.TooManyFieldValuesError) Expression for operator `phrase` has 2 fields, but should only have one.

  If the field value is not a string, `CSQuery.StringRequiredError` will be
  raised.

      iex> phrase!([2000, boost: 2, field: "title"]) |> to_query
      ** (CSQuery.StringRequiredError) Expression field value for operator `phrase` must be a string value.

  """
  @spec phrase!(keyword) :: Expression.t() | no_return
  def phrase!(list), do: Expression.new(:phrase, list)

  @doc """
  Creates a `prefix` expression.

      (prefix boost=N field=FIELD 'STRING')

  ## Examples

  Find any document that has a word starting with 'teen' in the title field.

      iex> prefix!(["teen", boost: 2, field: "title"]) |> to_query
      "(prefix boost=2 field=title 'teen')"

      iex> parse(prefix: ["teen", boost: 2, field: "title"]) |> to_query
      "(prefix boost=2 field=title 'teen')"

  Find any document that contains a word starting with 'teen' in any text or
  text-array field.

      iex> prefix!(["teen"]) |> to_query
      "(prefix 'teen')"

      iex> parse(prefix: ["teen"]) |> to_query
      "(prefix 'teen')"

  If there is more than one field provided, `CSQuery.TooManyFieldValuesError`
  will be raised.

      iex> prefix!(["star", "value"]) |> to_query
      ** (CSQuery.TooManyFieldValuesError) Expression for operator `prefix` has 2 fields, but should only have one.

  If the field value is not a string, `CSQuery.StringRequiredError` will be
  raised.

      iex> prefix!([2000]) |> to_query
      ** (CSQuery.StringRequiredError) Expression field value for operator `prefix` must be a string value.
  """
  @spec prefix!(keyword) :: Expression.t() | no_return
  def prefix!(list), do: Expression.new(:prefix, list)

  @doc """
  Creates a `range` expression.

      (range boost=N field=FIELD RANGE)

  ## Examples

  Find any document that has a number between 1990 and 2000 in any field.

      iex> range!([{1990, 2000}]) |> to_query
      "(range [1990,2000])"

      iex> parse(range: [{1990, 2000}]) |> to_query
      "(range [1990,2000])"

  Find any document that has a number up to 2000 in any field.

      iex> range!([{nil, 2000}]) |> to_query
      "(range {,2000])"

      iex> parse(range: [{nil, 2000}]) |> to_query
      "(range {,2000])"

  Find any document that has a number equal to or greater than 1990 in any
  field.

      iex> range!([{1990, nil}]) |> to_query
      "(range [1990,})"

      iex> parse(range: [{1990, nil}]) |> to_query
      "(range [1990,})"

  Find any document that has a number between 2004 and 2006 in the date field,
  inclusive, converted from an Elixir `t:Range.t/0` type.

      iex> range!([2004..2006, field: "date"]) |> to_query
      "(range field=date [2004,2006])"

      iex> parse(range: [2004..2006, field: "date"]) |> to_query
      "(range field=date [2004,2006])"

  Find any document that has a number between 1990 and 2000 in the date field,
  but includes neither 1990 nor 2000.

      iex> range!([
      ...>   CSQuery.Range.new(%{first?: 1990, last?: 2000}),
      ...>   field: "date",
      ...>   boost: 2
      ...> ]) |> to_query
      "(range boost=2 field=date {1990,2000})"

      iex> parse(range: [
      ...>   CSQuery.Range.new(%{first?: 1990, last?: 2000}),
      ...>   field: "date",
      ...>   boost: 2
      ...> ]) |> to_query
      "(range boost=2 field=date {1990,2000})"

  Ranges may also be specified as strings.

      iex> range!(["[1990,2000]"]) |> to_query
      "(range [1990,2000])"
      iex> range!(["[1990,}"]) |> to_query
      "(range [1990,})"
      iex> range!(["{,2000]"]) |> to_query
      "(range {,2000])"
      iex> range!(["{1990,2000}"]) |> to_query
      "(range {1990,2000})"

      iex> parse(range: ["[1990,2000]"]) |> to_query
      "(range [1990,2000])"
      iex> parse(range: ["[1990,}"]) |> to_query
      "(range [1990,})"
      iex> parse(range: ["{,2000]"]) |> to_query
      "(range {,2000])"
      iex> parse(range: ["{1990,2000}"]) |> to_query
      "(range {1990,2000})"

  If there are multiple values provided, `CSQuery.TooManyFieldValuesError` will
  be raised.

      iex> range!(["one", "two"]) |> to_query
      ** (CSQuery.TooManyFieldValuesError) Expression for operator `range` has 2 fields, but should only have one.

  If there value provided is not a range, `CSQuery.RangeRequiredError` will be
  raised.

      iex> range!([2000]) |> to_query
      ** (CSQuery.RangeRequiredError) Expression field value for operator `range` must be a range.
  """
  @spec range!(keyword) :: Expression.t() | no_return
  def range!(list), do: Expression.new(:range, list)

  @doc """
  Creates a `term` expression.

      (term boost=N field=FIELD 'STRING'|VALUE)

  > Warning: The parser does not currently enforce a single term value, so it
  > is possible to create an invalid query. The following test should fail.

      iex> term!(["star", "space", boost: 2]) |> to_query
      ** (CSQuery.TooManyFieldValuesError) Expression for operator `term` has 2 fields, but should only have one.

  ## Examples

  Find any document with a term 2000 in the year field.

      iex> term!([2000, field: "year", boost: 2]) |> to_query
      "(term boost=2 field=year 2000)"

      iex> parse(term: [2000, field: "year", boost: 2]) |> to_query
      "(term boost=2 field=year 2000)"

  Find any document with a term 'star' in any text or text-array field.

      iex> term!(["star"]) |> to_query
      "(term 'star')"

      iex> parse(term: ["star"]) |> to_query
      "(term 'star')"
  """
  @spec term!(keyword) :: Expression.t() | no_return
  def term!(list), do: Expression.new(:term, list)

  @doc """
  Parse a structured description of the query to build to produce an
  expression. An exception will be raised if an invalid expression is
  constructed.

  An empty keyword list as a document returns `nil`.

      iex> parse([])
      nil

  If an error occurs during parsing, an exception will be raised, as per the
  operator documentation. If an unknown operator is provided,
  `CSQuery.UnknownOperatorError` will be raised. If no field values are
  provided for an operator, `CSQuery.NoFieldValuesError` will be raised.

      iex> parse(foo: [])
      ** (CSQuery.UnknownOperatorError) Unknown operator `foo` provided.

      iex> parse(and: [])
      ** (CSQuery.NoFieldValuesError) Expression for operator `and` has no field values.

  If more than one condition is at the top level of the structured query
  document, a list of queries will be returned.

      iex> parse(and: ["star", "wars"], and: ["star", "trek"]) |> to_query
      ["(and 'star' 'wars')", "(and 'star' 'trek')"]

  Detailed examples of `CSQuery.parse/1` are found in the documentation for
  `CSQuery.and!/1`, `CSQuery.near!/1`, `CSQuery.not!/1`, `CSQuery.or!/1`,
  `CSQuery.phrase!/1`, `CSQuery.prefix!/1`, `CSQuery.range!/1`, and
  `CSQuery.term!/1`.
  """
  @spec parse(keyword) :: nil | Expression.t() | list(Expression.t()) | no_return
  def parse(query) do
    case Expression.new(query) do
      [] -> nil
      [expr] -> expr
      result -> result
    end
  end

  @doc """
  Convert a query expression (`t:CSQuery.Expression.t/0`) to a string, or a
  list of query expressions to a list of strings.
  """
  @spec to_query(list(Expression.t())) :: list(String.t())
  @spec to_query(Expression.t()) :: String.t()
  defdelegate to_query(expr), to: Expression
end
