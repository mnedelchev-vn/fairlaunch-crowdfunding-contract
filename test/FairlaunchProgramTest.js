const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("Fairlaunch Program", function () {
    function sleep(ms) {
        return new Promise((resolve) => {
            setTimeout(resolve, ms);
        });
    }

    it("Owner depositing tokens; Starting user deposits; Deposits fulfilled; Send liquidity to Uniswap; Users claiming tokens", async function () {
        const [owner, user1, user2, user3] = await ethers.getSigners();
        if (owner == undefined || user1 == undefined || user2 == undefined || user3 == undefined) {
            console.error('ERROR - In order to execute the tests on Rinkeby network you have to provide 4 testing private keys with rETH balances into your hardhat.config.js file.');
            return false;
        }
        console.log('Owner address: ' + owner.address);
        console.log('User 1 address: ' + user1.address);
        console.log('User 2 address: ' + user2.address);
        console.log('User 3 address: ' + user3.address);

        // deploy sample ERC20 contract
        const SampleERC20ContractFactory = await ethers.getContractFactory('SampleERC20Contract');
        const SampleERC20Contract = await SampleERC20ContractFactory.deploy(BigInt(1000 * (10 ** 18)));
        await SampleERC20Contract.deployed();
        console.log('SampleERC20Contract address: ' + SampleERC20Contract.address);

        // deploying the fairlaunch contract
        const currentTimestamp = Math.round(new Date().getTime() / 1000);
        const FairlaunchProgramContractFactory = await ethers.getContractFactory('FairlaunchProgramContract');
        const FairlaunchProgramContract = await FairlaunchProgramContractFactory.deploy(currentTimestamp, currentTimestamp + 120, 30, SampleERC20Contract.address, '0xc778417e063141139fce010982780140aa0cd5ab', '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f', '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D', BigInt(1000000000000000), BigInt(10000000000000000000));
        await FairlaunchProgramContract.deployed();
        console.log('FairlaunchProgramContract address: ' + FairlaunchProgramContract.address);

        // owner giving approval to FairlaunchProgramContract in order to accept the owner tokens deposit
        const ownerApproval = await SampleERC20Contract.connect(owner).approve(FairlaunchProgramContract.address, await SampleERC20Contract.totalSupply());
        await ownerApproval.wait();
        console.log('Allowance: ' + await SampleERC20Contract.allowance(owner.address, FairlaunchProgramContract.address));

        // owner depositing tokens
        const ownerDepositTokens = await FairlaunchProgramContract.connect(owner).depositTokens(BigInt(300 * (10 ** 18)), BigInt(250 * (10 ** 18)));
        await ownerDepositTokens.wait();
        console.log('Owner successfully deposited ' + (parseInt(await FairlaunchProgramContract.tokens_for_claiming()) + parseInt(await FairlaunchProgramContract.tokens_for_liquidity())) + ' tokens to the FairlaunchProgramContract. ' + parseInt(await FairlaunchProgramContract.tokens_for_claiming()) + ' tokens for token claims and ' + parseInt(await FairlaunchProgramContract.tokens_for_liquidity()) + ' tokens for Uniswap liquidity.');

        // user deposits
        const user1Deposit = await FairlaunchProgramContract.connect(user1).depositETH({
            value: BigInt(15500000000000000)
        });
        await user1Deposit.wait();
        console.log('User 1 deposited ' + ethers.utils.formatEther(BigInt(10000000000000000)) + ' ETH.');

        const user2Deposit = await FairlaunchProgramContract.connect(user2).depositETH({
            value: BigInt(25500000000000000)
        });
        await user2Deposit.wait();
        console.log('User 2 deposited ' + ethers.utils.formatEther(BigInt(20000000000000000)) + ' ETH.');

        const user3Deposit = await FairlaunchProgramContract.connect(user3).depositETH({
            value: BigInt(35500000000000000)
        });
        await user3Deposit.wait();
        console.log('User 3 deposited ' + ethers.utils.formatEther(BigInt(30000000000000000)) + ' ETH.');

        console.log('User 1 current token share: ' + await FairlaunchProgramContract.connect(user1).getCurrentTokenShare());
        console.log('User 2 current token share: ' + await FairlaunchProgramContract.connect(user2).getCurrentTokenShare());
        console.log('User 3 current token share: ' + await FairlaunchProgramContract.connect(user3).getCurrentTokenShare());

        console.log('Waiting for fairlaunch to end ...');
        await sleep(60000);

        var hasDepositsFinished = await FairlaunchProgramContract.hasDepositsFinished();
        if (hasDepositsFinished) {
            console.log('Fairlaunch deposits ended.');
            const ownerAddingLiquidity = await FairlaunchProgramContract.connect(owner).createPoolAndAddLiquidity();
            await ownerAddingLiquidity.wait();
            console.log('Owner added liquidity of ' + ethers.utils.formatEther(await FairlaunchProgramContract.total_eth_deposited()) + ' ETH and ' + await FairlaunchProgramContract.tokens_for_liquidity() + ' tokens to Uniswap.');

            const user1Claim = await FairlaunchProgramContract.connect(user1).claimTokens();
            await user1Claim.wait();
            console.log('User 1 claimed tokens.');

            const user2Claim = await FairlaunchProgramContract.connect(user2).claimTokens();
            await user2Claim.wait();
            console.log('User 2 claimed tokens.');

            const user3Claim = await FairlaunchProgramContract.connect(user3).claimTokens();
            await user3Claim.wait();
            console.log('User 3 claimed tokens.');
        }
    });

    // testing canceling owner fairlaunch
    it("Owner depositing tokens; Starting user deposits; Deposits fulfilled; Owner canceling fairlaunch; Users withdrawing ETH", async function () {
        const [owner, user1, user2, user3] = await ethers.getSigners();
        if (owner == undefined || user1 == undefined || user2 == undefined || user3 == undefined) {
            console.error('ERROR - In order to execute the tests on Rinkeby network you have to provide 4 testing private keys with rETH balances into your hardhat.config.js file.');
            return false;
        }
        console.log('Owner address: ' + owner.address);
        console.log('User 1 address: ' + user1.address);
        console.log('User 2 address: ' + user2.address);
        console.log('User 3 address: ' + user3.address);

        // deploy sample ERC20 contract
        const SampleERC20ContractFactory = await ethers.getContractFactory('SampleERC20Contract');
        const SampleERC20Contract = await SampleERC20ContractFactory.deploy(BigInt(1000 * (10 ** 18)));
        await SampleERC20Contract.deployed();
        console.log('SampleERC20Contract address: ' + SampleERC20Contract.address);

        // deploying the fairlaunch contract
        const currentTimestamp = Math.round(new Date().getTime() / 1000);
        const FairlaunchProgramContractFactory = await ethers.getContractFactory('FairlaunchProgramContract');
        const FairlaunchProgramContract = await FairlaunchProgramContractFactory.deploy(currentTimestamp, currentTimestamp + 120, SampleERC20Contract.address, '0xc778417e063141139fce010982780140aa0cd5ab', '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f', '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D', BigInt(1000000000000000), BigInt(10000000000000000000));
        await FairlaunchProgramContract.deployed();
        console.log('FairlaunchProgramContract address: ' + FairlaunchProgramContract.address);

        // owner giving approval to FairlaunchProgramContract in order to accept the owner tokens deposit
        const ownerApproval = await SampleERC20Contract.connect(owner).approve(FairlaunchProgramContract.address, await SampleERC20Contract.totalSupply());
        await ownerApproval.wait();
        console.log('Allowance: ' + await SampleERC20Contract.allowance(owner.address, FairlaunchProgramContract.address));

        // owner depositing tokens
        const ownerDepositTokens = await FairlaunchProgramContract.connect(owner).depositTokens(BigInt(300 * (10 ** 18)), BigInt(250 * (10 ** 18)));
        await ownerDepositTokens.wait();
        console.log('Owner successfully deposited ' + (parseInt(await FairlaunchProgramContract.tokens_for_claiming()) + parseInt(await FairlaunchProgramContract.tokens_for_liquidity())) + ' tokens to the FairlaunchProgramContract. ' + parseInt(await FairlaunchProgramContract.tokens_for_claiming()) + ' tokens for token claims and ' + parseInt(await FairlaunchProgramContract.tokens_for_liquidity()) + ' tokens for Uniswap liquidity.');

        // user deposits
        const user1Deposit = await FairlaunchProgramContract.connect(user1).depositETH({
            value: BigInt(10000000000000000)
        });
        await user1Deposit.wait();
        console.log('User 1 deposited ' + ethers.utils.formatEther(BigInt(10000000000000000)) + ' ETH.');

        const user2Deposit = await FairlaunchProgramContract.connect(user2).depositETH({
            value: BigInt(20000000000000000)
        });
        await user2Deposit.wait();
        console.log('User 2 deposited ' + ethers.utils.formatEther(BigInt(20000000000000000)) + ' ETH.');

        const user3Deposit = await FairlaunchProgramContract.connect(user3).depositETH({
            value: BigInt(30000000000000000)
        });
        await user3Deposit.wait();
        console.log('User 3 deposited ' + ethers.utils.formatEther(BigInt(30000000000000000)) + ' ETH.');

        console.log('User 1 current token share: ' + await FairlaunchProgramContract.connect(user1).getCurrentTokenShare());
        console.log('User 2 current token share: ' + await FairlaunchProgramContract.connect(user2).getCurrentTokenShare());
        console.log('User 3 current token share: ' + await FairlaunchProgramContract.connect(user3).getCurrentTokenShare());

        // owner canceling fairlaunch
        const cancelFairlaunch = await FairlaunchProgramContract.connect(owner).cancelFairlaunch();
        await cancelFairlaunch.wait();

        const user1ETHWithdraw = await FairlaunchProgramContract.connect(user1).withdrawETH();
        await user1ETHWithdraw.wait();
        console.log('User 1 successfully withdrawn ETH deposit.');

        const user2ETHWithdraw = await FairlaunchProgramContract.connect(user2).withdrawETH();
        await user2ETHWithdraw.wait();
        console.log('User 2 successfully withdrawn ETH deposit.');

        const user3ETHWithdraw = await FairlaunchProgramContract.connect(user3).withdrawETH();
        await user3ETHWithdraw.wait();
        console.log('User 3 successfully withdrawn ETH deposit.');
    });
});