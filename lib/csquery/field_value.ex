defmodule CSQuery.FieldValue do
  @moduledoc """
  A representation of a field value pattern matcher for the AWS CloudSearch
  structured query syntax. If the `CSQuery.FieldValue` does not have a `name`,
  then all text and text-array fields will be searched. If it does have a
  `name`, then only the named field will be searched.
  """

  alias CSQuery.Range, as: CSRange
  alias CSQuery.{Expression, OperatorOption}

  @typedoc "Valid value types for a `t:CSQuery.FieldValue.t/0`."
  @type values ::
          String.t()
          | CSRange.t()
          | Expression.t()
          | number
          | DateTime.t()

  @typedoc """
  Valid name types for a `CSQuery.FieldValue` struct.

  Note that `t:CSQuery.Expression.operators/0` are not valid field names as
  they are reserved keywords in the structured query syntax.
  """
  @type names :: nil | String.t() | atom

  @typedoc "The struct for `CSQuery.FieldValue`."
  @type t :: %__MODULE__{name: names, value: values}

  @enforce_keys [:value]
  defstruct [:name, :value]

  @doc """
  Provide an unnamed `CSQuery.FieldValue` struct for the value provided.

  If the value provided is a `CSQuery.FieldValue` struct, it will be returned.

  If the value provided is a map, the first key and value combination will be
  used to construct the `CSQuery.FieldValue` struct.

      iex> new(%{title: "Star Wars", year: 1990})
      %CSQuery.FieldValue{name: :title, value: "Star Wars"}

  See `new/2` for more information.
  """
  @spec new(nil | t | struct | map | values | Range.t()) :: t | nil
  def new(%__MODULE__{} = value), do: value

  def new(%_mod{} = value), do: new(nil, value)

  def new(%{} = value) do
    with [name | _] <- Map.keys(value), %{^name => value} <- value do
      new(name, value)
    else
      _ -> nil
    end
  end

  def new(value), do: new(nil, value)

  @doc """
  Provide an optionally named `CSQuery.FieldValue` struct. The `value` may be
  one of `t:values/0`, `nil` (which will be converted to `""`), or a `Range`
  (which will be converted to a `CSQuery.Range`).

  If a `CSQuery.FieldValue` struct is provided, a struct with the `name`
  replaced will be returned, effectively naming or renaming the field.

      iex> new(:plot, %CSQuery.FieldValue{value: "war"})
      %CSQuery.FieldValue{name: :plot, value: "war"}

      iex> new(:plot, %CSQuery.FieldValue{name: :title, value: "war"})
      %CSQuery.FieldValue{name: :plot, value: "war"}

  As a special case, when one of the `t:CSQuery.Expression.operators/0` is
  provided as the `name`, a `CSQuery.Expression` will be built inside of a
  `CSQuery.FieldValue` struct.
  """
  def new(name, value)

  for operator <- CSQuery.operators() do
    @spec new(unquote(operator), keyword) :: Expression.t()
    def new(unquote(operator), value), do: new(Expression.new(unquote(operator), value))
  end

  @spec new(names, t) :: t
  def new(name, %__MODULE__{} = value), do: %__MODULE__{value | name: name}

  @spec new(names, values) :: t
  def new(name, value) do
    %__MODULE__{name: name, value: convert(value)}
  end

  @doc """
  Convert the `t:CSQuery.FieldValue.t/0` to a string.
  """
  @spec to_value(t) :: String.t()
  def to_value(%__MODULE__{name: name, value: value}) do
    [name, format(value)]
    |> Enum.filter(& &1)
    |> Enum.join(":")
  end

  defp convert(nil), do: ""

  defp convert(%Range{} = value), do: CSRange.new(value)

  defp convert({_first, _last} = value), do: CSRange.new(value)

  defp convert(value), do: value

  defp format(%CSRange{} = value), do: CSRange.to_value(value)

  defp format(%Expression{} = value), do: Expression.to_query(value)

  defp format(value) when is_number(value), do: to_string(value)

  defp format(%DateTime{} = value), do: "'#{DateTime.to_iso8601(value)}'"

  defp format(%OperatorOption{}), do: nil

  defp format(value) when is_binary(value) do
    cond do
      is_parenthesized?(value) -> value
      CSRange.is_range_string?(value) -> value
      true -> "'#{escape(value)}'"
    end
  end

  defp escape(value), do: String.replace(String.replace(value, "\\", "\\\\"), "'", "\\'")

  defp is_parenthesized?(value) do
    String.starts_with?(value, "(") && String.ends_with?(value, ")")
  end
end
