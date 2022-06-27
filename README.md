# Fairlaunch crowdfunding contract

The main purpose of the Fairlaunch crowdfunding contract is to enable crowdfunding for a new token and after the fairlaunch crowdfund is done to securely create Uniswap trading pair and provide the collected liquidity.

#### Owner methods breakdown:
* The ```constructor``` is accepting the following parameters:
    * ```_start_time``` - this is the time of the start of the crowdfund. ( Unix timestamp )
    * ```_end_time``` - this is the time of the end of the crowdfund. ( Unix timestamp )
    * ```_team_share``` - this parameter is defining what percentage of the total ETH liquidity will be sent to the token owner.
    * ```_token_address``` - this is the address of the token for which this crowdfunding is being made.
    * ```_WETH_address``` - the contract address of the WETH token.
    * ```_UniswapV2Factory_address``` - the contract address of the Uniswap V2 Factory contract.
    * ```_UniswapV2Router02_address``` - the contract address of the Uniswap V2 Router contract.
    * ```_min_deposit``` - this is the minimum deposit amount to be deposited by the users when contributing to the crowdfunding.
    * ```_max_deposit``` - this is the maximum deposit amount to be deposited by the users when contributing to the crowdfunding.
* Method ```depositTokens``` - this method is built so the crowdfunding owner can deposit the tokens in the contract. The method is accepting the following parameters:
    * ```_tokens_for_claiming``` - this is the amount of tokens to be claimed by the fairlaunch crowdfund contributors.
    * ```_tokens_for_liquidity``` - this is the amount of tokens to be provided for the liquidity of the Uniswap trading pair. By default this value should be lesser than ```_tokens_for_claiming``` to create incentive for the early contributors.
* Method ```createPoolAndAddLiquidity``` - Once contributing deposits are over this method is providing the ```_tokens_for_liquidity``` and the collected ETH amount *( minus the team share )* as liquidity for the Uniswap trading pair. The ETH team share amount is being sent to the owner of the fairlaunch crowdfund after the liquidity is sent to Uniswap.
* Method ```cancelFairlaunch``` - this method is created if for whatever reason the fairlaunch crowdfunding has to be stopped *( during bug, change of the initial parameters, etc )*.

#### Contributors methods breakdown:
* Method ```depositETH``` - this is the method where users are contributing the the fairlaunch crowdfunding.
* Method ```claimTokens``` - once contributing deposits are over and the initial liquidity is provided to Uniswap, contributors will be using this method to claim their token share.
* Method ```withdrawETH``` - if for whatever reason the fairlaunch crowdfunding is cancelled then the contributors have the permission to withdraw the ETH amount which they have previously sent to the contract by using method ```depositETH```.

#### Commands:
* ```npm install``` - Downloading required packages.
* ```npx hardhat test --network rinkeby``` - Firing the tests on the **Rinkeby** network. There are 2 types of tests - first one is faking a successful user deposits and adding of Uniswap liquidity, the second one is successful user deposits, but the owner canceling the fairlaunch for whatever reason and users withdrawing their ETH back. 

**Important** -  In order to execute the tests on Rinkeby network you have to provide 4 testing private keys with rETH balances into your hardhat.config.js file. Create ```.env``` file and paste the following code and paste your private keys:
```
NODE=XYZ
PRIVATE_KEY_OWNER=XYZ
PRIVATE_KEY_USER_1=XYZ
PRIVATE_KEY_USER_2=XYZ
PRIVATE_KEY_USER_3=XYZ
```