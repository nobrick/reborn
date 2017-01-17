defmodule Machine.Adapters.CloudForest.Trainer do
  @moduledoc """
  Data trainer for CloudForest.
  """

  alias Machine.Adapters.CloudForest.DataWriter

  @samples_name "samples.trans.fm"
  @forest_name "forest.sf"
  @pattern_key Application.get_env(:machine, :pattern_key)

  @doc """
  Trains the data.
  """
  def learn(dir_path) do
    args =
      "-train=#{@samples_name} -rfpred=#{@forest_name} " <>
      "-target=N:#{@pattern_key}0 -nTrees=100 -mTry=.33 -oob=false -nCores=1"
    args = String.split(args)
    {result, err_code} = System.cmd("growforest", args, cd: dir_path)
    if err_code != 0 do
      raise "growforest returns non-zero code #{err_code}.\n#{result}"
    end
  end

  @doc """
  Saves the data for training.
  """
  def save_data(dir_path, chunks) do
    samples_path = Path.join(dir_path, @samples_name)
    DataWriter.save_data(DataWriter, samples_path, chunks)
  end
end
