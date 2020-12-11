pragma solidity ^0.6.12;

import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IWETH.sol';

import './PaperToken.sol';
import './TokensManager.sol';

contract RoundManager is TokensManager {
    uint256 public roundLimit = 1e18;
    uint256 public minBet = 2e17;
    uint256 public roundBalance;
    uint256 public accumulatedBalance;

    struct Round {
        address winner;
        uint256 prize;
    }

    struct UserBet {
        uint256 bet;
        uint256 round;
    }

    uint256 public finishedRounds = 0;
    mapping(address => UserBet) public bets;

    event NewRound(uint256 limit, uint256 paperReward);
    event NewBet(address player, uint256 rate);
    event EndRound(address winner, uint256 prize);

    function setRoundLimit(uint256 _newAmount) public onlyOwner {
        roundLimit = _newAmount;
    }

    function setMinBet(uint256 _newAmount) public onlyOwner {
        minBet = _newAmount;
    }
}

contract Auction is RoundManager {
    address payable internal lastPlayer;
    uint256 public lastBlock = 0;
    uint256 public lastBet = 0;
    uint256 public auctionDuration = 69;

    address public immutable WETH;
    address public immutable paperLP;
    address[] public WETH2PAPER;

    event AuctionStep(uint256 lastBet, address lastPlayer, uint256 lastBlock);

    constructor(
        address _router,
        address _developers,
        address _WETH,
        PaperToken _paper,
        address _farmContract,
        address _paperLP
    ) public {
        router = _router;
        developers = _developers;
        WETH = _WETH;
        paper = _paper;
        paperLP = _paperLP;
        farmContract = _farmContract;
        WETH2PAPER = new address[](2);
        WETH2PAPER[0] = _WETH;
        WETH2PAPER[1] = address(_paper);
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function makeBet(
        address _token,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] memory _path
    ) public {
        require(approvedTokens[_token] == true, "Approve new token first");
        require(
            minBet <= _amountOutMin || _amountIn == 0,
            "Your bet is too small"
        );
        if (lastBlock < block.number && lastBlock != 0) {
            endAuction(lastPlayer);
        }
        if (_amountOutMin > 0) {
            require(_path.length > 1 && _path[_path.length - 1] == WETH, "Wrong path");
            require(
                lastBet < _amountOutMin,
                "Small bet"
            );
            transferTokens(_token, _amountIn);
            uint256 currentBet =
            swap(
                _amountIn,
                _amountOutMin,
                _path,
                address(this)
            );

            mintToken(msg.sender);

            roundBalance = roundBalance.add(currentBet);
            accumulatedBalance = accumulatedBalance.add(currentBet);

            addNewBet(currentBet);

            if (roundBalance > roundLimit) {
                lastBet = currentBet;
                lastPlayer = msg.sender;
                lastBlock = block.number.add(auctionDuration);
                emit AuctionStep(lastBet, lastPlayer, lastBlock);
            }
        }
    }

    function addNewBet(uint256 _amountETH) internal {
        bets[msg.sender].bet = _amountETH;
        bets[msg.sender].round = finishedRounds;
        emit NewBet(msg.sender, _amountETH);
    }


    function getAmountForRedeem(uint256 _amount, uint256 _part)
    internal
    pure
    returns (uint256)
    {
        return (_amount.mul(_part)).div(100);
    }

    function endAuction(address payable _winner) internal {
        uint256 _userReward = allocatePaper();

        IWETH(WETH).withdraw(_userReward);
        _winner.transfer(_userReward);

        emit EndRound(lastPlayer, _userReward);
        emit NewRound(roundLimit, paperReward);

        finishedRounds++;
        roundBalance = 0;
        lastBet = 0;
        lastPlayer = address(0x0);
        lastBlock = 0;
    }

    function allocatePaper() internal returns (uint256) {
        uint256 amountToLP = getAmountForRedeem(roundBalance, lpPart);
        uint256 amountToFarm = getAmountForRedeem(roundBalance, farmPart);

        uint256 maxReturn =
        getAmountOut(
            amountToLP.add(amountToFarm),
            WETH2PAPER
        );

        if (maxReturn < amountToLP.add(amountToFarm)) {
            uint256 share = maxReturn.div(amountToLP.add(amountToFarm));
            amountToLP = amountToLP.mul(share);
            amountToFarm = amountToFarm.mul(share);
        }

        swap(
            amountToFarm,
            getAmountOut(amountToFarm, WETH2PAPER),
            WETH2PAPER,
            farmContract
        );

        IERC20(WETH).transferFrom(
            address(this),
            paperLP,
            amountToLP
        );
        IUniswapV2Pair(paperLP).sync();

        return roundBalance.sub(amountToLP.add(amountToFarm));
    }

    function setDuration(uint256 _newAmount) public onlyOwner {
        auctionDuration = _newAmount;
    }

    function getLastPlayer() public view returns (address) {
        return lastPlayer;
    }
}
