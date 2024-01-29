## Setup

1. Install Foundry by following the instructions from [their repository](https://github.com/foundry-rs/foundry#installation).
2. Copy the `.env.example` file to `.env` and fill in the variables.
3. Install the dependencies by running: `yarn install`. In case there is an error with the commands, run `foundryup` and try them again.

## Build

```bash
yarn build
```

## Running tests

```bash
yarn test
```

## Deploy & verify

### Setup

Configure the `.env` variables.

### Local

Start up anvil:
```shell
$ anvil
```

Deploy:
```bash
yarn deploy:localhost
```

Update auction config:
```bash
cast send $CONTRACT_ADDRESS "updateConfig(uint64,uint64,uint256,uint256)" 1704369600 1704373200 1000000000000000000 200000000000000000 --private-key $LOCAL_PRIVATE_KEY
```

### Sepolia

```bash
yarn deploy:sepolia
```