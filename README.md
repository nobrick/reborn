# Reborn
## Architecture
* Dirk: data archiving
* Caravan: data fetching
* Azor: ord monitoring and controlling
* Daydream: pattern predicting
* Huo: huo client
* Utils: common utilities

## Todo
### Azor ord
* ~~Clarify Dirk.Ord states~~
* Finish implementing Ords transition processes
    - ~~Implement Ords.Tracker~~
    - Implement Huo.Order.RequestsBuffer(for rate threshold)
    - Support stop-loss and stop-profit ords. Also consider trailing amount and percentage. See [Btcc stop_order API](https://www.btcc.com/apidocs/spot-exchange-trade-json-rpc-api#buystoporder)
    - Support ord canceling along with watcher pids management in Ords.Manager
* ~~Support ord dependency watch (ex. we expect ord.1 follows ord.2)~~
* ~~Implement WatcherSupervisor~~
* Sync the states with persistence (PostgreSQL or Mnesia, ETS, DETS or others)
* Take note of TDD and finish up unit tests
* Use ex_machina for fixtures, ex. ords
* Timeout for Azor.Ords.Watcher and Tracker

### Issues
* The Ords.Manager pid stored in Watcher may be outdated when Manager crashes.

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
[CAP](https://codahale.com/you-cant-sacrifice-partition-tolerance/)
[Alchemist.vim](https://github.com/slashmili/alchemist.vim)
