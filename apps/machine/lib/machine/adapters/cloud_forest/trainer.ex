defmodule Machine.Adapters.CloudForest.Trainer do
  @moduledoc """
  Data trainer for CloudForest.
  """

  alias Machine.Adapters.CloudForest.DataWriter

  @samples_path "samples.trans.fm"
  @forest_path "forest.sf"

  @doc """
  Trains the data.
  """
  def learn(opts \\ []) do
    samples_path = opts[:samples_path] || @samples_path
    forest_path = opts[:forest_path] || @forest_path
    args = "-train=#{samples_path} -rfpred=#{forest_path} -target=N:d_la0 " <>
           "-nTrees=100 -mTry=.33 -oob=false -nCores=1" |> String.split
    {result, 0} = System.cmd("growforest", args)
    IO.puts result
  end

  @doc """
  Saves the data for training.
  """
  def save_data(chunks, opts \\ []) do
    samples_path = opts[:samples_path] || @samples_path
    DataWriter.save_data(DataWriter, samples_path, chunks)
  end
end
