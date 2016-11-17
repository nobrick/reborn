defmodule Machine.Adapters.CloudForest.Predictor do
  @moduledoc """
  Data predictor for CloudForest.
  """

  alias Machine.Adapters.CloudForest.DataWriter

  @test_path "test.trans.fm"
  @predictions_path "predictions.tsv"
  @forest_path "forest.sf"

  @doc """
  Predicts the data.
  """
  def predict(opts \\ []) do
    predictions_path = opts[:predictions_path] || @predictions_path
    test_path = opts[:test_path] || @test_path
    forest_path = opts[:forest_path] || @forest_path
    args = "-preds=#{predictions_path} -fm=#{test_path} " <>
           "-rfpred=#{forest_path}"
    {result, 0} = System.cmd("applyforest", String.split(args))
    IO.puts result
  end

  @doc """
  Saves the target data for backtesting.
  """
  def save_data(target_chunk, opts \\ []) do
    test_path = opts[:test_path] || @test_path
    DataWriter.save_data(DataWriter, test_path, [target_chunk])
  end

  @precision 7

  @doc """
  Reads the prediction from the given `predictions_path`.
  """
  def read_prediction(predictions_path \\ @predictions_path) do
    [label, predicted, actual] =
      File.open!(predictions_path, [:read], fn(file) ->
        IO.read(file, :all) |> String.split
      end)
    {label, _} = Integer.parse(label)
    [label, parse_float(predicted), parse_float(actual)]
  end

  defp parse_float(string) do
    Float.parse(string) |> elem(0) |> Float.round(@precision)
  end
end
