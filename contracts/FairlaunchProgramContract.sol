//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./Ownable.sol";


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
        uint deadline
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

contract FairlaunchProgramContract is Ownable {
    bool public cancelFairlaunchBool = false;
    bool public liquidityAdded = false;
    uint64 public startTime;
    address public tokenAddress;
    uint8 public teamShare; // percentage
    uint64 public endTime;
    uint64 constant private SCALING = 10 ** 18;
    uint128 public minDeposit;
    uint128 public maxDeposit;
    uint256 public tokensForClaiming;
    uint256 public tokensForLiquidity;
    uint256 public totalEthDeposited;
    IUniswapV2Factory uniswapV2Factory;
    IUniswapV2Router02 uniswapV2Router02;
    IERC20 erc20Contract;

    mapping(address => uint256) public deposits;

    constructor(
        uint64 _startTime,
        uint64 _endTime,
        uint8 _teamShare,
        address _tokenAddress,
        address _wethAddress,
        address _uniswapV2Factory,
        address _uniswapV2Router02,
        uint128 _minDeposit,
        uint128 _maxDeposit
    ) {
        require(_startTime < _endTime, "Error: INVALID_START_END_TIME");
        require(_teamShare > 0 && _teamShare <= 50, "Error: INVALID_TEAM_SHARE");
        require(_tokenAddress != address(0), "Error: INVALID_TOKEN_ADDRESS");
        require(_uniswapV2Factory != address(0), "Error: INVALID _uniswapV2Factory");
        require(_uniswapV2Router02 != address(0), "Error: INVALID_uniswapV2Router02");

        startTime = _startTime;
        endTime = _endTime;
        teamShare = _teamShare;
        minDeposit = _minDeposit;
        maxDeposit = _maxDeposit;
        tokenAddress = _tokenAddress;
        erc20Contract = IERC20(tokenAddress);
        uniswapV2Router02 = IUniswapV2Router02(_uniswapV2Router02);
        uniswapV2Factory = IUniswapV2Factory(_uniswapV2Factory);

        // approve Uniswap router in order to add liquidity at later stage
        erc20Contract.approve(_uniswapV2Router02, erc20Contract.totalSupply());

        require(
            uniswapV2Factory.getPair(tokenAddress, _wethAddress) == address(0),
            "Error: ALREADY_EXISTING_POOL"
        );
    }

    event DepositTokens(
        address indexed _address,
        uint256 _tokensForClaiming,
        uint256 _tokensForLiquidity
    );

    event CreatePoolAndAddLiquidity(
        address indexed _address,
        uint256 _tokensForLiquidity,
        uint256 _totalEthDeposited
    );

    event CancelFairlaunch(address indexed _address, uint256 _amount);

    event DepositETH(address indexed _address, uint256 _amount);

    event ClaimTokens(address indexed _address, uint256 _amount);

    event WithdrawETH(address indexed _address, uint256 _amount);

    /*
    * Used by the fairlaunch to deposit the tokens for the fairlaunch
    */
    function depositTokens(
        uint256 _tokensForClaiming,
        uint256 _tokensForLiquidity
    ) external onlyOwner {
        require(tokensForClaiming == 0 && tokensForLiquidity == 0, "Error: TOKENS_ALREADY_DEPOSITED");
        require(_tokensForClaiming > _tokensForLiquidity, "Error: INVALID_tokensForLiquidity");
        erc20Contract.transferFrom(_msgSender(), address(this), _tokensForClaiming + _tokensForLiquidity);
        tokensForClaiming = _tokensForClaiming;
        tokensForLiquidity = _tokensForLiquidity;

        emit DepositTokens(_msgSender(), tokensForClaiming, tokensForLiquidity);
    }

    /*
    * Used by the fairlaunch creator to transfer the collected liquidity to Uniswap and enable token claims
    */
    function createPoolAndAddLiquidity() external onlyOwner {
        require(hasDepositsFinished(), "Error: DEPOSITS_STILL_ACTIVE");
        require(totalEthDeposited != 0 && tokensForLiquidity != 0, "Error: INVALID_ETH_BALANCE");

        uint256 _teamShare = (totalEthDeposited * teamShare) / 100;
        uint256 ethForLiquidity = totalEthDeposited - _teamShare;

        // providing liquidity
        (uint amountToken, uint amountETH,) = uniswapV2Router02.addLiquidityETH{value : ethForLiquidity}(
            tokenAddress,
            tokensForLiquidity,
            tokensForLiquidity,
            ethForLiquidity,
            owner(),
            block.timestamp + 600
        );
        require(amountToken == tokensForLiquidity && amountETH == ethForLiquidity, "Error: addLiquidityETH_FAILED");

        // enable token withdrawals
        liquidityAdded = true;

        // sending team share to the owner
        payable(owner()).transfer(_teamShare);

        emit CreatePoolAndAddLiquidity(_msgSender(), tokensForLiquidity, totalEthDeposited);
    }

    /*
    * Used by the fairlaunch creator to cancel the fairlaunch
    */
    function cancelFairlaunch() external onlyOwner {
        require(!cancelFairlaunchBool, "Error: FAILED_LAUNCH_CANCELLED");
        cancelFairlaunchBool = true;

        // owner withdrawing previously deposited tokens
        erc20Contract.transfer(owner(), tokensForClaiming + tokensForLiquidity);

        emit CancelFairlaunch(_msgSender(), tokensForClaiming + tokensForLiquidity);
    }

    /*
    * Method where users participate in the fairlaunch
    */
    function depositETH() external payable {
        require(areDepositsActive(), "Error: DEPOSITS_NOT_ACTIVE");
        require(msg.value >= minDeposit && msg.value + deposits[_msgSender()] <= maxDeposit, "Error: INVALID_DEPOSIT_AMOUNT");
        require(!cancelFairlaunchBool, "Error: FAIRLAUNCH_IS_CANCELLED");

        deposits[_msgSender()] += msg.value;
        totalEthDeposited += msg.value;

        emit DepositETH(_msgSender(), msg.value);
    }

    /*
    * After liquidity is added to Uniswap with this method users are able to claim their token share
    */
    function claimTokens() external returns (uint256) {
        require(hasDepositsFinished(), "Error: CLAIMING_NOT_ACTIVE");
        require(getCurrentTokenShare() > 0, "Error: INVALID_TOKEN_SHARE");
        require(!cancelFairlaunchBool, "Error: FAIRLAUNCH_IS_CANCELLED");
        require(liquidityAdded, "Error: LIQUIDITY_NOT_ADDED");

        uint256 userTokens = getCurrentTokenShare();
        deposits[_msgSender()] = 0;
        erc20Contract.transfer(_msgSender(), userTokens);

        emit ClaimTokens(_msgSender(), userTokens);

        return userTokens;
    }

    /*
    * If the fairlaunch is cancelled users are able to withdraw their previously deposited ETH
    */
    function withdrawETH() external returns (uint256) {
        require(cancelFairlaunchBool, "Error: FAIRLAUNCH_NOT_CANCELLED");
        require(getCurrentTokenShare() > 0 && deposits[_msgSender()] > 0, "Error: INVALID_DEPOSIT_AMOUNT");

        uint256 userEthAmount = deposits[_msgSender()];
        deposits[_msgSender()] = 0;

        payable(_msgSender()).transfer(userEthAmount);

        emit WithdrawETH(_msgSender(), userEthAmount);

        return userEthAmount;
    }

    /*
    * Returning the current token share for the current user
    */
    function getCurrentTokenShare() public view returns (uint256) {
        if (deposits[_msgSender()] > 0) {
            return (((deposits[_msgSender()] * SCALING) / totalEthDeposited) * tokensForClaiming) / SCALING;
        } else {
            return 0;
        }
    }

    function areDepositsActive() public view returns (bool) {
        return block.timestamp > startTime &&
        block.timestamp < endTime &&
        tokensForClaiming != 0 &&
        tokensForLiquidity != 0;
    }

    function hasDepositsFinished() public view returns (bool) {
        return block.timestamp > startTime && block.timestamp > endTime;
    }
}