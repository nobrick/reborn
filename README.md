# Reborn
## Architecture
* Dirk: data archiving
* Caravan: data fetching
* Azor: ord monitoring and controlling
* Machine: pattern predicting
* Huo: huo client
* Mutt: slack messaging and management
* Utils: common utilities

## the machine
### Backtest
- [ ] Calculate Maximum Drawdown (MDD).
- [ ] Calculate all-time alpha, beta, sharpe ratio in seq_list and csv output.
- [ ] Allow setting `chunk_size` without restarting the app.
- [ ] Plot data graph.
- [ ] Dynamically removes the target fields from lookups fields.
- [ ] Try MS LightGBM.
- [ ] Save simulation result to a file for later uses.
- [x] Need a fetch_chunks(`time_start`, `time_end`) version.
- [x] Clean up the data directory automatically.
- [x] Include additional info(eg. time ranges for target and sample chunks) in the result.
- [x] Checks if the two periods (`target_chunks` and `lookup_chunks`) conflict each other instead of outputing results.

### Control

### Slack
* Fix test issue

### Caravan.Wheel.Interval
- [x] Remove conflicting k15 points.
- [x] `insert_all` with `:on_conflict` option.

### Azor ord
* Finish implementing Ords transition processes
    - Persist the orders.
    - Implement Huo.Order.RequestsBuffer(for rate threshold)
    - Support stop-loss and stop-profit ords. Also consider trailing amount and percentage. See [Btcc stop_order API](https://www.btcc.com/apidocs/spot-exchange-trade-json-rpc-api#buystoporder)
    - Support ord canceling along with watcher pids management in Ords.Manager
    - ~~Implement Ords.Tracker~~
* Sync the states with persistence (PostgreSQL or Mnesia, ETS, DETS or others)
* Take note of TDD and finish up unit tests
* Use ex_machina for fixtures, ex. ords
* Timeout for Azor.Ords.Watcher and Tracker
* Manager.cancel_ord/2 terminates the associated watcher and tracker if alive
* Watcher and tracker pid may be outdated, since they may crash. Therefore we need to remove the watcher and tracker references when they crash(may monitor the process), and be able to lookup their new reference when they restart after crashes.
    - Choice 1: General process registry (to implement the required behavior and lookup via name registration mechanism). Just as `:name` option in GenSever, we may use a tuple including `:ord_id` as the unique reference to identify and lookup the process. BTW. The general process registry makes convenience for testing.
    - Choice 2: Watcher / tracker registry (to implement a gen server).
    - Choice 3: Use gen_stage for Manager (to notify the watchers and trackers)
    - Choice 4: Use Gproc library
* ~~Clarify Dirk.Ord states~~
* ~~Support ord dependency watch (ex. we expect ord.1 follows ord.2)~~
* ~~Implement WatcherSupervisor~~

### Issues
* Ords.Manager may crash
* Pids may be outdated after processes crash and restart.
* ~~The Manager pid stored in Watcher may be outdated when Manager crashes~~

### Random forest
* [CloudForest](https://github.com/ryanbressler/CloudForest)
* [OOB Error @ Wiki](https://en.wikipedia.org/wiki/Out-of-bag_error)
* [OOB Error @ Quora](https://www.quora.com/What-is-the-out-of-bag-error-in-Random-Forests)

### Timeout issue

### Normalize K15
* ~~Keep `d_la` deltas~~
* Keep deltas for other attributes
* Resolve duplicate K15 records with different `vo`

### Further reading
[NimbleCSV](https://github.com/plataformatec/nimble_csv)
[Microsoft/LightGBM](https://github.com/Microsoft/LightGBM/tree/master/examples/regression)

### Archived reading
[CAP](https://codahale.com/you-cant-sacrifice-partition-tolerance/)
[Process Registry](https://m.alphasights.com/process-registry-in-elixir-a-practical-example-4500ee7c0dcc#.j2e19r1xm)
[Gproc Registry](https://github.com/uwiger/gproc)
