pragma solidity ^0.6.12;

import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IWETH.sol';

import './librarues/Random.sol';

import './PaperToken.sol';
import './TokensManager.sol';

contract RoundManager is TokensManager {
    uint256 public roundLimit = 1e18;
    uint256 public roundBalance;
    uint256 public accumulatedBalance;

    struct Round {
        address winner;
        uint256 prize;
    }

    struct Bet {
        address player;
        uint256 bet;
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

    function getAmountForRedeem(uint256 _roundBalance, uint256 _part)
        public
        pure
        returns (uint256)
    {
        return (_roundBalance.mul(_part)).div(100);
    }
}

contract Auction is RoundManager {
    address payable internal lastPlayer;
    uint256 public lastBlock = 0;
    uint256 public lastBet = 0;
    uint256 public auctionDuration = 69;

    address public immutable WETH;

    event AuctionStep(uint256 lastBet, address lastPlayer, uint256 lastBlock);

    constructor(
        address _router,
        address _developers,
        address _WETH,
        PaperToken _paper,
        address _farmContract
    ) public {
        router = _router;
        developers = _developers;
        WETH = _WETH;
        paper = _paper;
        farmContract = _farmContract;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    function makeBet(uint256 _tokenId, uint256 _tokenAmount) public {
        uint256 wethAmount = 0;
        if (_tokenAmount > 0) {
            wethAmount = getAmountTokens(
                availableTokens[_tokenId],
                WETH,
                _tokenAmount
            );
        }
        if (lastBlock < block.number && lastBlock != 0) {
            endAuction(lastPlayer);
        }
        if (_tokenAmount > 0) {
            require(
                lastBet < wethAmount,
                "Current bet cannot be less than previous bet"
            );
            uint256 currentBet =
                updateRoundData(_tokenId, _tokenAmount, wethAmount, msg.sender);
            bets[msg.sender].bet = currentBet;
            bets[msg.sender].round = finishedRounds;

            if (roundBalance > roundLimit) {
                lastBet = currentBet;
                lastPlayer = msg.sender;
                lastBlock = block.number.add(auctionDuration);
                emit AuctionStep(lastBet, lastPlayer, lastBlock);
            }
        }
    }

    function updateRoundData(
        uint256 _tokenId,
        uint256 _tokenAmount,
        uint256 _wethAmount,
        address _player
    ) internal returns (uint256) {
        transferTokens(_tokenId, _tokenAmount);
        uint256 _swapWeTH =
            swap(
                _tokenAmount,
                availableTokens[_tokenId],
                WETH,
                _wethAmount,
                address(this)
            );
        mintToken(_player);
        roundBalance = roundBalance.add(_swapWeTH);
        accumulatedBalance = accumulatedBalance.add(_swapWeTH);

        emit NewBet(_player, _swapWeTH);

        return _swapWeTH;
    }

    function endAuction(address payable _winner) internal {
        uint256 amountToBurn = getAmountForRedeem(roundBalance, burnedPart);
        uint256 amountToFarm = getAmountForRedeem(roundBalance, farmPart);

        uint256 maxReturn =
            getAmountTokens(
                WETH,
                address(paper),
                amountToBurn.add(amountToFarm)
            );

        if (maxReturn < amountToBurn.add(amountToFarm)) {
            amountToBurn = amountToBurn.mul(
                maxReturn.div(amountToBurn.add(amountToFarm))
            );
            amountToFarm = amountToFarm.mul(
                maxReturn.div(amountToBurn.add(amountToFarm))
            );
        }
        swap(
            amountToBurn,
            WETH,
            address(paper),
            getAmountTokens(WETH, address(paper), amountToBurn),
            0x0000000000000000000000000000000000000005
        );
        swap(
            amountToFarm,
            WETH,
            address(paper),
            getAmountTokens(WETH, address(paper), amountToFarm),
            farmContract
        );
        uint256 _userReward = roundBalance.sub(amountToBurn.add(amountToFarm));

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

    function setDuration(uint256 _newAmount) public onlyOwner {
        auctionDuration = _newAmount;
    }

    function getLastPlayer() public view returns (address) {
        return lastPlayer;
    }
}
