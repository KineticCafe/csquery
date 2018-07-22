defmodule CSQuery.OperatorOption do
  @moduledoc """
  A struct representing an option for one of the structured query syntax
  operators.

  During expression construction, options that are not recognized for a given
  operator will either be discarded (if already a `CSQuery.OperatorOption` struct) or
  be treated as a named field (if part of a keyword list). Options that do not
  have a string value will be discarded.
  """

  @typedoc "Valid option names."
  @type names :: :boost | :distance | :field

  @typedoc "Valid option values."
  @type values :: nil | String.t()

  @typedoc "The struct for `CSQuery.OperatorOption`."
  @type t :: %__MODULE__{name: names, value: values}

  @enforce_keys [:name, :value]
  defstruct [:name, :value]

  @names [:boost, :distance, :field]

  @doc """
  Provide a `CSQuery.OperatorOption` struct (or `nil`).

  `new/1` is mostly used during expression list construction. See `new/2` for
  more information.
  """
  @spec new(t) :: t
  def new(%__MODULE__{} = value), do: value

  @spec new({names, any}) :: t | nil
  def new({name, value}), do: new(name, value)

  @doc """
  Return a `CSQuery.OperatorOption` struct, or `nil` based on the `name` and `value`
  provided.

  `new/2` may return `nil` if:

  * the `name` is not in `t:names/0`;
  * the `value` is `nil`;
  * or the `value` does not conform to the `String.Chars` protocol.
  """
  def new(name, value)

  @spec new(names, nil) :: nil
  def new(_, nil), do: nil

  @spec new(atom, any) :: nil
  def new(name, _) when not (name in @names), do: nil

  @spec new(names, any) :: t | nil
  def new(name, value) do
    %__MODULE__{name: name, value: to_string(value)}
  rescue
    Protocol.UndefinedError -> nil
  end

  @doc """
  Return a string value representation of the `CSQuery.OperatorOption` struct.

  The response format will be `"name=value"`. If the struct `value` is `nil` or
  does not conform to the `String.Chars` protocol, the response will be `""`.
  """

  def to_value(%__MODULE__{value: nil}), do: ""

  def to_value(%__MODULE__{name: name, value: value}) do
    "#{name}=#{value}"
  rescue
    Protocol.UndefinedError -> ""
  end
end
