# SalesProvider

## About The Project
The goal of the SalesProvider is to provide a simple inheritable contract that can be used to manage sales of tokens on the Ethereum blockchain with the aid of Chainlink Price Feeds.

The sales of tokens can be completed in a variety of ways:

- Fixed ERC20 Pricing
- Fixed Eth Pricing
- ERC20/USD Pegged Pricing using Chainlink Price Feeds
- Eth/USD Pegged Pricing using Chainlink Price Feeds
- Dutch Auction ERC20 Pricing
- Dutch Auction Eth Pricing

For Dutch Auctions, the algorithm defaults to linear interpolation. This can be overridden by an implementing contract.

## Chainlink Price Feeds

Documentation on Chainlink Price Feeds
https://docs.chain.link/data-feeds/price-feeds

Price Feed Contract Addresses for testnets and mainnet
https://docs.chain.link/data-feeds/price-feeds/addresses


## Roadmap

- [ ] Improve general repo and code quality (workflows, comments, etc.)
- [ ] Add more documentation on benefits of using SalesProvider
- [ ] Maintain full test coverage
- [ ] Add NPM package
- [ ] Provide examples of usage
- [ ] Potentially allow for forks/contributors in future

## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

## Contact

- Westy (owner) - [@westy_dev](https://twitter.com/Westy_Dev)