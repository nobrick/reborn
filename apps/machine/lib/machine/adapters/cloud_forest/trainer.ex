defmodule Machine.Adapters.CloudForest.Trainer do
  @moduledoc """
  Data trainer for CloudForest.
  """

  alias Machine.Adapters.CloudForest.DataWriter

  @samples_name "samples.trans.fm"
  @forest_name "forest.sf"

  @doc """
  Trains the data.
  """
  def learn(dir_path) do
    args =
      "-train=#{@samples_name} -rfpred=#{@forest_name} -target=N:d_la0 " <>
      "-nTrees=100 -mTry=.33 -oob=false -nCores=1" |> String.split
    {result, 0} = System.cmd("growforest", args, cd: dir_path)
    IO.puts result
  end

  @doc """
  Saves the data for training.
  """
  def save_data(dir_path, chunks) do
    samples_path = Path.join(dir_path, @samples_name)
    DataWriter.save_data(DataWriter, samples_path, chunks)
  end
end
