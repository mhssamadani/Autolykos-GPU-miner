# Autolykos CUDA-miner

## Prerequisites
(For Ubuntu 16.04 or 18.04)

To compile you need the following:

1. CUDA Toolkit: [installation guide](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html)
2. libcurl library: to install run
```
$ apt install libcurl4-openssl-dev
```
3. OpenSSL library: to install run
```
$ apt install libssl-dev
```

## Install

1. Clone repository to `<YOUR_PATH>`
2. Change directory to `<YOUR_PATH>/autolykos/secp256k1`
3. Run `make`

If `make` completed successfully there will appear an executable
`<YOUR_PATH>/autolykos/secp256k1/auto.out` and (if not already present)
a config file `<YOUR_PATH>/autolykos/secp256k1/config.json` with stub contents.

## Run

- To run the miner you should pass a name of a configuration file `[YOUR_CONFIG]` as an optional argument
- If the filename is not specified, the miner will try to use `<YOUR_PATH>/autolykos/secp256k1/config.json` as a config
- The configuration file must contain json string of the following structure:  
`{ "seed" : "seedstring", "node" : "https://127.0.0.1", "keepPrehash" : false }`

The mode of execution with `keepPrehash` option:
1. `true` -- enable total unfinalized prehashes array (5GB) reusage.
2. `false` -- prehash recalculation for each block.

To run the miner on all available CUDA devices type:
```
$ <YOUR_PATH>/autolykos/secp256k1/auto.out [YOUR_CONFIG]
```

To choose CUDA devices change and use `runner.sh` or directly change environment variable `CUDA_VISIBLE_DEVICES`

Press the key 'q' or 'Q' to exit the miner in a foreground mode.
