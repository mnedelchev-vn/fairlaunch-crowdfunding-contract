//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Ownable.sol";

contract FairlaunchProgramContract is Ownable {
    uint32 public time_to_react = 86400;
    uint64 public start_time;
    address public token_address;
    bool public cancel_fairlaunch = false;
    bool public liquidity_added = false;
    uint8 public team_share; // percentage
    uint64 public end_time;
    uint64 constant private scaling = 10 ** 18;
    uint128 public min_deposit;
    uint128 public max_deposit;
    uint256 public tokens_for_claiming;
    uint256 public tokens_for_liquidity;
    uint256 public total_eth_deposited;
    IUniswapV2Factory UniswapV2Factory;
    IUniswapV2Router02 UniswapV2Router02;
    IERC20 ERC20;

    mapping(address => uint256) public deposits;

    constructor(
        uint64 _start_time,
        uint64 _end_time,
        uint8 _team_share,
        address _token_address,
        address _WETH_address,
        address _UniswapV2Factory_address,
        address _UniswapV2Router02_address,
        uint128 _min_deposit,
        uint128 _max_deposit
    ) {
        require(_start_time < _end_time, "Error: Invalid start and end time of the fairlaunch.");
        require(_team_share > 0 && _team_share <= 50, "Error: Team share can be only between 1 and 50 percentages.");
        require(_token_address != address(0), "Error: Invalid token address.");
        require(_UniswapV2Factory_address != address(0), "Error: Invalid UniswapV2Factory address.");
        require(_UniswapV2Router02_address != address(0), "Error: Invalid UniswapV2Router02 address.");

        start_time = _start_time;
        end_time = _end_time;
        team_share = _team_share;
        min_deposit = _min_deposit;
        max_deposit = _max_deposit;
        token_address = _token_address;
        ERC20 = IERC20(token_address);
        UniswapV2Router02 = IUniswapV2Router02(_UniswapV2Router02_address);
        UniswapV2Factory = IUniswapV2Factory(_UniswapV2Factory_address);

        // approve Uniswap router in order to add liquidity at later stage
        ERC20.approve(_UniswapV2Router02_address, ERC20.totalSupply());

        require(
            UniswapV2Factory.getPair(token_address, _WETH_address) == address(0),
            "Error: Uniswap pool already existing."
        );
    }

    event DepositTokens(
        address indexed _address,
        uint256 _tokens_for_claiming,
        uint256 _tokens_for_liquidity
    );

    event CreatePoolAndAddLiquidity(
        address indexed _address,
        uint256 _tokens_for_liquidity,
        uint256 _total_eth_deposited
    );

    event CancelFairlaunch(address indexed _address, uint256 _amount);

    event DepositETH(address indexed _address, uint256 _amount);

    event ClaimTokens(address indexed _address, uint256 _amount);

    event WithdrawETH(address indexed _address, uint256 _amount);

    /*
    * Used by the fairlaunch to deposit the tokens for the fairlaunch
    */
    function depositTokens(
        uint256 _tokens_for_claiming,
        uint256 _tokens_for_liquidity
    ) external onlyOwner {
        require(tokens_for_claiming == 0 && tokens_for_liquidity == 0, "Error: Tokens already deposited.");
        require(_tokens_for_claiming > _tokens_for_liquidity, "Error: Tokens for claiming have to be lesser than tokens for liquidity to create incentive for users to join early at the crowdfunding.");
        ERC20.transferFrom(_msgSender(), address(this), _tokens_for_claiming + _tokens_for_liquidity);
        tokens_for_claiming = _tokens_for_claiming;
        tokens_for_liquidity = _tokens_for_liquidity;

        emit DepositTokens(_msgSender(), tokens_for_claiming, tokens_for_liquidity);
    }

    /*
    * Used by the fairlaunch creator to transfer the collected liquidity to Uniswap and enable token claims
    */
    function createPoolAndAddLiquidity() external onlyOwner {
        require(hasDepositsFinished(), "Error: Deposits are still active.");
        require(total_eth_deposited != 0 && tokens_for_liquidity != 0, "Error: Invalid contract balances. Cannot proceed with adding Uniswap liquidity.");

        uint256 _team_share = (total_eth_deposited * team_share) / 100;
        uint256 eth_for_liquidity = total_eth_deposited - _team_share;

        // providing liquidity
        (uint amountToken, uint amountETH,) = UniswapV2Router02.addLiquidityETH{value : eth_for_liquidity}(
            token_address,
            tokens_for_liquidity,
            tokens_for_liquidity,
            eth_for_liquidity,
            owner(),
            block.timestamp + 600
        );
        require(amountToken == tokens_for_liquidity && amountETH == eth_for_liquidity, "Error: Method addLiquidityETH failed.");

        // enable token withdrawals
        liquidity_added = true;

        // sending team share to the owner
        payable(owner()).transfer(_team_share);

        emit CreatePoolAndAddLiquidity(_msgSender(), tokens_for_liquidity, total_eth_deposited);
    }

    /*
    * Used by the fairlaunch creator to cancel the fairlaunch
    */
    function cancelFairlaunch() external onlyOwner {
        require(!cancel_fairlaunch, "Error: Fairlaunch already cancelled.");
        cancel_fairlaunch = true;

        // owner withdrawing previously deposited tokens
        ERC20.transfer(owner(), tokens_for_claiming + tokens_for_liquidity);

        emit CancelFairlaunch(_msgSender(), tokens_for_claiming + tokens_for_liquidity);
    }

    /*
    * Method where users participate in the fairlaunch
    */
    function depositETH() external payable {
        require(areDepositsActive(), "Error: Deposits not active yet.");
        require(msg.value >= min_deposit && msg.value + deposits[_msgSender()] <= max_deposit, "Error: Invalid deposit amount.");
        require(!cancel_fairlaunch, "Error: Fairlaunch cancelled.");

        deposits[_msgSender()] += msg.value;
        total_eth_deposited += msg.value;

        emit DepositETH(_msgSender(), msg.value);
    }

    /*
    * After liquidity is added to Uniswap with this method users are able to claim their token share
    */
    function claimTokens() external returns (uint256) {
        require(hasDepositsFinished(), "Error: Deposits are still active. You can withdraw once they finish.");
        require(getCurrentTokenShare() > 0, "Error: Invalid deposit amount.");
        require(!cancel_fairlaunch, "Error: Fairlaunch cancelled.");
        require(liquidity_added, "Error: Claiming have not yet started.");

        uint256 userTokens = getCurrentTokenShare();
        deposits[_msgSender()] = 0;
        ERC20.transfer(_msgSender(), userTokens);

        emit ClaimTokens(_msgSender(), userTokens);

        return userTokens;
    }

    /*
    * If the fairlaunch is cancelled users are able to withdraw their previously deposited ETH
    */
    function withdrawETH() external returns (uint256) {
        require(cancel_fairlaunch, "Error: Fairlaunch not cancelled.");
        require(getCurrentTokenShare() > 0 && deposits[_msgSender()] > 0, "Error: Invalid deposit amount.");

        uint256 user_eth = deposits[_msgSender()];
        deposits[_msgSender()] = 0;

        payable(_msgSender()).transfer(user_eth);

        emit WithdrawETH(_msgSender(), user_eth);

        return user_eth;
    }

    /*
    * Returning the current token share for the current user
    */
    function getCurrentTokenShare() public view returns (uint256) {
        if (deposits[_msgSender()] > 0) {
            return (((deposits[_msgSender()] * scaling) / total_eth_deposited) * tokens_for_claiming) / scaling;
        } else {
            return 0;
        }
    }

    function areDepositsActive() public view returns (bool) {
        return block.timestamp > start_time &&
        block.timestamp < end_time &&
        tokens_for_claiming != 0 &&
        tokens_for_liquidity != 0;
    }

    function hasDepositsFinished() public view returns (bool) {
        return block.timestamp > start_time && block.timestamp > end_time;
    }
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        int deadline
    ) external payable returns (
        uint amountToken,
        uint amountETH,
        uint liquidity
    );
}

interface IERC20 {
    function transferFrom(address _from, address _to, uint256 _tokens) external returns (bool success);

    function transfer(address _to, uint _tokens) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function totalSupply() external returns (uint256);
}