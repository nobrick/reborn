defmodule Machine.Adapters.CloudForest.Predictor do
  @moduledoc """
  Data predictor for CloudForest.
  """

  alias Machine.Adapters.CloudForest.DataWriter

  @compile {:inline, parse_float: 1}

  @test_name "test.trans.fm"
  @predictions_name "predictions.tsv"
  @forest_name "forest.sf"

  @doc """
  Predicts the data.
  """
  def predict(dir_path) do
    args = "-preds=#{@predictions_name} -fm=#{@test_name} " <>
           "-rfpred=#{@forest_name}"
    {result, err_code} = System.cmd("applyforest", String.split(args),
                                    cd: dir_path)
    if err_code != 0 do
      raise "applyforest returns non-zero code #{err_code}.\n#{result}"
    end
  end

  @doc """
  Saves the target data for backtesting.

  ## Options

      - `id`: The target label. -1 by default.
      - `actual`: The actual target value. -1.0 by default.
  """
  def save_test(dir_path, target_tl, opts \\ []) do
    test_path = Path.join(dir_path, @test_name)
    DataWriter.save_test(DataWriter, test_path, target_tl, opts)
  end

  @precision 7

  @doc """
  Reads the prediction from the given `predictions_path`.
  """
  def read_prediction(dir_path) do
    predictions_path = Path.join(dir_path, @predictions_name)
    [label, predicted, actual] =
      File.open!(predictions_path, [:read], fn(file) ->
        IO.read(file, :all) |> String.split
      end)
    {label, _} = Integer.parse(label)
    {label, parse_float(predicted), parse_float(actual)}
  end

  defp parse_float(string) do
    Float.parse(string) |> elem(0) |> Float.round(@precision)
  end
end
