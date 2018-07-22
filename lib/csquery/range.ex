defmodule CSQuery.Range do
  @moduledoc """
  An AWS CloudSearch structured query syntax representation of ranges that may
  be inclusive or exclusive, open or closed, and may be constructed of
  integers, floats, `t:DateTime.t/0` values, or (in some cases) strings.

  > A brief note about notation: `{` and `}` denote *exclusive* range bounds;
  > `[` and `]` denote *inclusive* range bounds.

  ## Inclusive or Exclusive Ranges

  Ranges that are inclusive cover the entire range, including the boundaries of
  the range. These are typical of Elixir `t:Range.t/0` values. The Elixir range
  `1..10` is all integers from `1` through `10`. `CSQuery.Range` values may be
  lower-bound exclusive, upper-bound exclusive, or both-bound exclusive.

  *   `[1,10]`: lower- and upper-bound inclusive. Integers `1` through `10`.
  *   `{1,10}`: lower- and upper-bound exclusive; Integers `2` through `9`.
  *   `{1,10]`: lower-bound exclusive, upper-bound inclusive. Integers `2`
      through `10`.
  *   `[1,10}`: lower-bound inclusive, upper-bound exclusive. Integers `1`
      through `9`.

  ## Open or Closed Ranges

  An open range is one that omits either the upper or lower bound.
  Representationally, an omitted bound must be described as exclusive.

  *   `{,10]`: Open range for integers up to `10`.
  *   `[10,}`: Open range for integers `10` or larger.

  Logically, a fully open range (`{,}`) is possible, but is meaningless in the
  context of a search, so a `CSQuery.OpenRangeError` will be thrown.

      iex> new({nil, nil})
      ** (CSQuery.OpenRangeError) CSQuery.Range types may not be open on both upper and lower bounds.

      iex> new(%{})
      ** (CSQuery.OpenRangeError) CSQuery.Range types may not be open on both upper and lower bounds.

  ## Range Types

  Elixir range values are restricted to integers. CloudSearch ranges may be:

  *   Integers:

      ```
      iex> new({1, 10}) |> to_value
      "[1,10]"
      ```

  *   Floats:

      ```
      iex> new({:math.pi(), :math.pi() * 2}) |> to_value
      "[3.141592653589793,6.283185307179586]"
      ```

  *   Mixed numbers:

      ```
      iex> new({1, :math.pi() * 2}) |> to_value
      "[1,6.283185307179586]"
      ```

  *   Timestamps

      ```
      iex> start = %DateTime{
      ...>  year: 2018, month: 7, day: 21,
      ...>  hour: 17, minute: 55, second: 0,
      ...>  time_zone: "America/Toronto", zone_abbr: "EST",
      ...>  utc_offset: -14_400, std_offset: 0
      ...> }
      iex> finish = %DateTime{
      ...>  year: 2018, month: 7, day: 21,
      ...>  hour: 19, minute: 55, second: 0,
      ...>  time_zone: "America/Toronto", zone_abbr: "EST",
      ...>  utc_offset: -14_400, std_offset: 0
      ...> }
      iex> new({start, finish}) |> to_value
      "['2018-07-21T17:55:00-04:00','2018-07-21T19:55:00-04:00']"
      ```

  *   Strings

      ```
      iex> new({"a", "z"}) |> to_value
      "['a','z']"
      ```

  integers, floats, timestamps, or strings.

  `CSQuery.Range` construction looks for compatible types (integers and floats
  may be mixed, but neither timestamps nor strings may be mixed with other
  types), and a `CSQuery.RangeValueTypeError` will be thrown if incompatible
  types are found.

      iex> new(%{first: 3, last: "z"})
      ** (CSQuery.RangeValueTypeError) CSQuery.Range types must be compatible (numbers, dates, and strings may not be mixed).

      iex> new(%{first: DateTime.utc_now(), last: "z"})
      ** (CSQuery.RangeValueTypeError) CSQuery.Range types must be compatible (numbers, dates, and strings may not be mixed).
  """

  @typedoc "Supported values for CSQuery.Range values."
  @type value :: nil | integer | float | DateTime.t() | String.t()

  @type t :: %__MODULE__{first: value, first?: value, last: value, last?: value}

  defstruct [:first, :first?, :last, :last?]

  @doc """
  Create a new `CSQuery.Range` value.
  """
  @spec new(Range.t()) :: t
  def new(%Range{first: first, last: last}), do: %__MODULE__{first: first, last: last}

  @spec new({nil | number, nil | number}) :: t | no_return
  @spec new({nil | String.t(), nil | String.t()}) :: t | no_return
  @spec new({nil | DateTime.t(), nil | DateTime.t()}) :: t | no_return
  def new({_, _} = value), do: build(value)

  @spec new(map) :: t | no_return
  def new(%{} = range), do: build(range)

  def to_value(%{first: first, first?: first?, last: last, last?: last?}) do
    lower(value(first), value(first?)) <> "," <> upper(value(last), value(last?))
  end

  def is_range_string?(value) do
    value
    |> String.split(",")
    |> case do
      [low, high] ->
        (String.starts_with?(low, "[") || String.starts_with?(low, "{")) &&
          (String.ends_with?(high, "]") || String.ends_with?(high, "}"))

      _ ->
        false
    end
  end

  defp value(nil), do: nil

  defp value(value) when is_number(value), do: value

  defp value(value) when is_binary(value), do: "'#{value}'"

  defp value(%DateTime{} = value), do: "'#{DateTime.to_iso8601(value)}'"

  @blank [nil, ""]

  defp lower(f, f?) when f in @blank and f? in @blank, do: "{"

  defp lower(f, f?) when f in @blank, do: "{#{f?}"

  defp lower(f, _), do: "[#{f}"

  defp upper(l, l?) when l in @blank and l? in @blank, do: "}"

  defp upper(l, l?) when l in @blank, do: "#{l?}}"

  defp upper(l, _), do: "#{l}]"

  defp build({first, last}), do: valid?(%__MODULE__{first: first, last: last})

  defp build(%{} = range), do: valid?(struct(__MODULE__, range))

  defp valid?(%__MODULE__{} = range) do
    case valid?(Map.values(range)) do
      true -> range
      exception when is_atom(exception) -> raise(exception)
    end
  end

  defp valid?([_, nil, nil, nil, nil]), do: CSQuery.OpenRangeError

  defp valid?([_, a, b, c, d])
       when (is_nil(a) or is_number(a)) and (is_nil(b) or is_number(b)) and
              (is_nil(c) or is_number(c)) and (is_nil(d) or is_number(d)),
       do: true

  defp valid?([_, a, b, c, d])
       when (is_nil(a) or is_binary(a)) and (is_nil(b) or is_binary(b)) and
              (is_nil(c) or is_binary(c)) and (is_nil(d) or is_binary(d)),
       do: true

  defp valid?([_, a, b, c, d])
       when (is_nil(a) or is_map(a)) and (is_nil(b) or is_map(b)) and (is_nil(c) or is_map(c)) and
              (is_nil(d) or is_map(d)) do
    [a, b, c, d]
    |> Enum.filter(& &1)
    |> Enum.map(&Map.get(&1, :__struct__))
    |> Enum.all?(&(&1 == DateTime))
    |> if(do: true, else: CSQuery.RangeValueTypeError)
  end

  defp valid?(_range), do: CSQuery.RangeValueTypeError
end
