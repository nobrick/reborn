defmodule Reverie.Brain do
  @moduledoc """
  The brain.
  """

  import Task.Supervisor, only: [start_child: 2]
  alias Machine.Adapters.CloudForest.{Trainer, Predictor}
  alias Machine.Corr
  alias Reverie.TemporaryTaskSup

  @corr_filters Application.get_env(:reverie, :corr_filters)
  @data_storage_path Application.get_env(:reverie, :data_storage_path)

  def predict(target_tl, chunks) do
    dir_path = make_data_dir()
    corr_chunks = Corr.find_corr_chunks(chunks, target_tl)
    result =
      case Corr.filter_corr_chunks(corr_chunks, @corr_filters) do
        {:ok, logs, filtered} ->
          Trainer.save_data(dir_path, Stream.map(filtered, & elem(&1, 0)))
          Trainer.learn(dir_path)
          Predictor.save_test(dir_path, target_tl)
          Predictor.predict(dir_path)
          [status: :ok, logs: logs, pred: Predictor.read_prediction(dir_path)]
        {:error, logs} ->
          [status: :error, logs: logs, pred: {-1, nil, nil}]
      end
    start_child(TemporaryTaskSup, fn -> File.rm_rf!(dir_path) end)
    result
  end

  defp make_data_dir do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time
    token = Enum.take_random(?a..?z, 3)
    path = Path.join(@data_storage_path,
                     "#{y}-#{m}-#{d}-#{hh}-#{mm}-#{ss}-#{token}")
    File.mkdir!(path)
    path
  end
end
