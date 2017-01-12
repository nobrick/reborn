use Amnesia
require Exquisite
alias Amnesia.Selection

defdatabase Reverie.Database do
  deftable Ord, [:id, :ord_p, :ord_amt, :processed_p, :processed_amt,
           :type, :status], type: :set, index: [:status, :type] do

    ## Readers

    def done!, do: read_at!(:done, :status)

    def canceled!, do: read_at!(:canceled, :status)

    def ongoing! do
      Selection.values(where! status == nil or status == :undone or
                              status == :partial_done)
    end

    def ongoing_ids! do
      Selection.values(where! status == nil or status == :undone or
                              status == :partial_done, select: id)
    end

    ## Writers

    def write_unfetched!(ord_id) do
      write!(%Ord{id: ord_id})
    end

    def write_by_resp!(%{"id" => ord_id, "order_amount" => ord_amt,
        "order_price" => ord_p, "processed_amount" => processed_amt,
        "type" => type_st} = resp) do
      status_st = resp["status"]
      write!(%Ord{id: ord_id, ord_amt: ord_amt, ord_p: ord_p,
                  processed_amt: processed_amt,
                  processed_p: resp["processed_price"],
                  status: status_st && String.to_atom(status_st),
                  type: String.to_atom(type_st)})
    end

    def update_by_resp!(%{"id" => ord_id} = resp) do
      (read!(ord_id) || Ord) |> struct(resp) |> write_by_resp!
    end

    def mark_status!(ids, status)
    when is_list(ids) and status in [:done, :canceled] do
      Enum.map(ids, fn id ->
        ord = read!(id)
        ord && write!(%{ord|status: :done})
      end)
    end
  end
end
