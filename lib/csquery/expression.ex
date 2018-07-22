defmodule CSQuery.Expression do
  @moduledoc """
  A representation of an expression in the AWS CloudSearch structured query
  syntax.
  """

  alias CSQuery.{FieldValue, OperatorOption}

  @typedoc "Valid operator names."
  @type operators :: :and | :near | :not | :or | :phrase | :prefix | :range | :term

  @typedoc "The `CSQuery.Expression` struct."
  @type t :: %__MODULE__{
          operator: operators,
          options: list(OperatorOption.t()),
          fields: list(FieldValue.t())
        }

  @enforce_keys [:operator]
  defstruct [:operator, options: [], fields: []]

  @doc """
  Provide a `CSQuery.Expression` struct for the provided value.

  If the value is a keyword list, the `CSQuery.Expression` will be constructed
  from the keyword pairs. Each keyword pair will be parsed as an operator and
  list (effectively calling `new/2` as `&new(elem(&1, 0), elem(&1, 1))`).

  An exception will be raised if there is an invalid expression constructed.

  If the value is a `CSQuery.Expression` struct, it will be returned.

      iex> CSQuery.Expression.new(%CSQuery.Expression{operator: :and})
      %CSQuery.Expression{operator: :and}
  """
  def new(value)

  @spec new(keyword) :: list(t) | no_return
  def new(list) when is_list(list), do: Enum.map(list, &build/1)

  @spec new(t) :: t
  def new(%__MODULE__{} = value), do: value

  @doc """
  Provide a `CSQuery.Expression` struct for the operator and conditions.

  See `CSQuery.and!/1`, `CSQuery.near!/1`, `CSQuery.not!/1`, `CSQuery.or!/1`,
  `CSQuery.phrase!/1`, `CSQuery.prefix!/1`, `CSQuery.range!/1`, and
  `CSQuery.term!/1` for the details on how expressions are built.

  An exception will be raised if there is an invalid expression constructed.
  """

  @rules %{
    [:boost] => [:and, :or],
    [:boost, :field] => [:not, :term, :phrase, :prefix, :range],
    [:boost, :distance, :field] => [:near]
  }

  for {opts, ops} <- @rules, op <- ops do
    @spec new(unquote(op), list) :: t | no_return
    def new(unquote(op), conditions) when is_list(conditions) do
      build(unquote(op), args_for(unquote(op), conditions, unquote(opts)))
    end
  end

  def new(op, _), do: raise(CSQuery.UnknownOperatorError, op)

  @doc """
  Convert the parsed query expression to the AWS CloudSearch structured query
  syntax string.

  If a list of queries is provided, convert each item to structured query
  syntax.
  """
  def to_query(query)

  @spec to_query(nil) :: String.t()
  def to_query(nil), do: ""

  @spec to_query(list(t)) :: list(String.t())
  def to_query(list) when is_list(list), do: Enum.map(list, &to_query/1)

  @spec to_query(t) :: String.t()
  def to_query(%__MODULE__{} = expr) do
    expr =
      [expr.operator, expr.options, expr.fields]
      |> Enum.flat_map(&value_for/1)
      |> Enum.join(" ")

    "(#{expr})"
  end

  defp build({operator, list}), do: new(operator, list)

  defp build(operator, {options, values, named}) do
    options = Enum.map(options, &OperatorOption.new/1)

    fields =
      Enum.map(values, &FieldValue.new/1) ++
        Enum.map(named, &FieldValue.new(elem(&1, 0), elem(&1, 1)))

    validate_fields!(operator, fields)

    %__MODULE__{
      operator: operator,
      options: options,
      fields: fields
    }
  end

  @spec validate_fields!(operators, list(FieldValue.t())) :: :ok | no_return
  defp validate_fields!(op, []), do: raise(CSQuery.NoFieldValuesError, op)

  defp validate_fields!(op, fields)
       when op in [:near, :not, :phrase, :prefix, :range, :term] and length(fields) > 1,
       do: raise(CSQuery.TooManyFieldValuesError, {op, length(fields)})

  defp validate_fields!(:near, [%FieldValue{value: value}]) when is_binary(value) do
    if(String.contains?(value, " "), do: :ok, else: raise(CSQuery.MultipleWordsRequiredError))
  end

  defp validate_fields!(op, [%FieldValue{value: value}])
       when op in [:near, :phrase, :prefix] and not is_binary(value),
       do: raise(CSQuery.StringRequiredError, op)

  defp validate_fields!(:range, [%FieldValue{value: %CSQuery.Range{}}]), do: :ok

  defp validate_fields!(:range, [%FieldValue{value: value}]) when is_binary(value) do
    if(CSQuery.Range.is_range_string?(value), do: :ok, else: raise(CSQuery.RangeRequiredError))
  end

  defp validate_fields!(:range, _), do: raise(CSQuery.RangeRequiredError)

  defp validate_fields!(op, _) when op in [:and, :or], do: :ok

  defp validate_fields!(_, _), do: :ok

  @spec value_for(t) :: list(String.t())
  defp value_for(%__MODULE__{} = expr), do: [to_query(expr)]

  @spec value_for(operators) :: list(String.t())
  defp value_for(operator) when is_atom(operator), do: [to_string(operator)]

  @spec value_for(%FieldValue{} | %OperatorOption{}) :: list(String.t())
  defp value_for(%mod{} = value) when mod in [FieldValue, OperatorOption],
    do: [mod.to_value(value)]

  @spec value_for(list) :: list(String.t())
  defp value_for(list) when is_list(list), do: Enum.map(list, &value_for/1)

  defp args_for(_operator, list, option_keys) do
    list
    |> Enum.filter(& &1)
    |> split_named_values()
    |> extract_options(option_keys)
  end

  defp split_named_values(list) when is_list(list), do: Enum.split_with(list, &is_keyword?/1)

  defp extract_options({named, values}, option_keys) do
    {option_values, values} = extract_option_values(values, option_keys)
    {named_options, named_values} = extract_named_options(named, option_keys)
    {option_values ++ named_options, values, named_values}
  end

  defp extract_option_values(values, option_keys) do
    {options, values} = Enum.split_with(values, &valid_option?(&1, option_keys))
    {options, Enum.reject(values, &is_option?/1)}
  end

  defp extract_named_options(named, option_keys) do
    opts =
      option_keys
      |> Enum.reduce(%{}, &Map.put(&2, &1, Keyword.get(named, &1)))
      |> Enum.filter(&elem(&1, 1))

    {opts, Keyword.drop(named, option_keys)}
  end

  defp is_keyword?({key, _}) when is_atom(key) and not is_nil(key), do: true

  defp is_keyword?(_), do: false

  defp valid_option?(%OperatorOption{name: name}, option_keys), do: name in option_keys

  defp valid_option?(_, _), do: false

  defp is_option?(%OperatorOption{}), do: true

  defp is_option?(_), do: false
end
