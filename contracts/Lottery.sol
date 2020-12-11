pragma solidity ^0.6.12;

import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IWETH.sol';

import './librarues/Random.sol';

import './PaperToken.sol';
import './TokensManager.sol';

contract RoundManager is TokensManager {
    uint256 internal roundLimit = 1e18;

    uint256 internal roundBalance;
    uint256 internal accumulatedBalance;

    struct Bet {
        address player;
        uint256 bet;
    }

    Bet[] public bets;

    mapping(address => uint256) public betsHistory;

    uint256 public finishedRounds = 0;

    event NewRound(uint256 limit, uint256 paperReward);
    event NewBet(address player, uint256 rate);
    event EndRound(address winner, uint256 prize);

    function setRoundLimit(uint256 _newAmount) public onlyOwner {
        roundLimit = _newAmount;
    }

    function getRoundLimit() public view returns (uint256) {
        return roundLimit;
    }

    function getRoundBalance() public view returns (uint256) {
        return roundBalance;
    }

    function getAccumulatedBalance() public view returns (uint256) {
        return accumulatedBalance;
    }

    function getAmountForRedeem(uint256 _roundBalance, uint256 _part)
        public
        pure
        returns (uint256)
    {
        return (_roundBalance.mul(_part)).div(100);
    }

    function getLastBet(address _player) public view returns (uint256 amount) {
        amount = 0;
        if (
            betsHistory[_player] < bets.length &&
            bets[betsHistory[_player]].player == _player
        ) {
            amount = bets[betsHistory[_player]].bet;
        }
        return amount;
    }
}

contract Lottery is RoundManager, Random {
    address public immutable WETH;

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
        transferTokens(_tokenId, _tokenAmount);
        uint256 _swapWeTH =
            swap(
                _tokenAmount,
                availableTokens[_tokenId],
                WETH,
                getAmountTokens(availableTokens[_tokenId], WETH, _tokenAmount),
                address(this)
            );
        mintToken(msg.sender);

        uint256 betAmount = _swapWeTH;
        if (roundBalance.add(betAmount) > roundLimit) {
            betAmount = roundLimit.sub(roundBalance);
        }

        roundBalance = roundBalance.add(_swapWeTH);
        accumulatedBalance = accumulatedBalance.add(_swapWeTH);
        addNewBet(msg.sender, betAmount);

        if (roundBalance >= roundLimit) {
            givePrize();
        }
    }

    function addNewBet(address _player, uint256 _rateEth) internal {
        betsHistory[msg.sender] = bets.length;
        bets.push(Bet({player: _player, bet: _rateEth}));
        emit NewBet(msg.sender, _rateEth);
    }

    function givePrize() internal {
        uint256 prizeNumber = _randRange(1, roundLimit);
        address payable winner = payable(generateWinner(prizeNumber));

        uint256 userReward = allocatePaper();

        finishedRounds++;
        IWETH(WETH).withdraw(userReward);
        winner.transfer(userReward);

        // Clear round
        delete bets;
        roundBalance = 0;

        emit EndRound(winner, userReward);
        emit NewRound(roundLimit, paperReward);
    }

    function generateWinner(uint256 prizeNumber)
        public
        view
        returns (address winner)
    {
        uint256 a = 0;
        for (uint256 i = 0; i < bets.length; i++) {
            if (prizeNumber > a && prizeNumber <= a.add(bets[i].bet)) {
                winner = bets[i].player;
                break;
            }
            a = a.add(bets[i].bet);
        }
    }

    function allocatePaper() internal returns (uint256) {
        uint256 amountToBurn = getAmountForRedeem(roundBalance, burnedPart);
        uint256 amountToFarm = getAmountForRedeem(roundBalance, farmPart);

        uint256 maxReturn =
            getAmountTokens(
                WETH,
                address(paper),
                amountToBurn.add(amountToFarm)
            );

        if (maxReturn < amountToBurn.add(amountToFarm)) {
            uint256 share = maxReturn.div(amountToBurn.add(amountToFarm));
            amountToBurn = amountToBurn.mul(share);
            amountToFarm = amountToFarm.mul(share);
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
        uint256 userReward = roundBalance.sub(amountToBurn.add(amountToFarm));
        return userReward;
    }

    function betsLength() public view returns (uint256) {
        return bets.length;
    }
}
