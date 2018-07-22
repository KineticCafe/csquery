defmodule CSQuery.NoFieldValuesError do
  defexception [:message]

  def exception(operator) do
    %__MODULE__{message: "Expression for operator `#{operator}` has no field values."}
  end
end

defmodule CSQuery.TooManyFieldValuesError do
  defexception [:message]

  def exception({operator, size}) do
    msg = "Expression for operator `#{operator}` has #{size} fields, but should only have one."
    %__MODULE__{message: msg}
  end
end

defmodule CSQuery.MultipleWordsRequiredError do
  defexception message: "Expression field value for operator `near` requires multiple words."
end

defmodule CSQuery.StringRequiredError do
  defexception [:message]

  def exception(operator) do
    msg = "Expression field value for operator `#{operator}` must be a string value."
    %__MODULE__{message: msg}
  end
end

defmodule CSQuery.RangeRequiredError do
  defexception message: "Expression field value for operator `range` must be a range."
end

defmodule CSQuery.UnknownOperatorError do
  defexception [:message]

  def exception(operator) do
    %__MODULE__{message: "Unknown operator `#{operator}` provided."}
  end
end

defmodule CSQuery.OpenRangeError do
  defexception message: "CSQuery.Range types may not be open on both upper and lower bounds."
end

defmodule CSQuery.RangeValueTypeError do
  defexception message:
                 "CSQuery.Range types must be compatible (numbers, dates, and strings may not be mixed)."
end
