pragma solidity ^0.6.12;

import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IWETH.sol';

import './librarues/Random.sol';

import './PaperToken.sol';
import './TokensManager.sol';

contract RoundManager is TokensManager {
    uint256 public roundLimit = 1e18;
    uint256 public minBet = 2e17;
    uint256 public roundBalance;
    uint256 public accumulatedBalance;

    struct Bet {
        address player;
        uint256 bet;
    }

    Bet[] public bets;

    mapping(address => uint256) public betsHistory;

    event NewRound(uint256 limit, uint256 paperReward);
    event NewBet(address player, uint256 rate);
    event EndRound(address winner, uint256 prize);

    function setRoundLimit(uint256 _newAmount) public onlyOwner {
        roundLimit = _newAmount;
    }

    function setMinBet(uint256 _newAmount) public onlyOwner {
        minBet = _newAmount;
    }

    function getLastBet(address _player) public view returns (uint256 amount) {
        if (
            betsHistory[_player] < bets.length &&
            bets[betsHistory[_player]].player == _player
        ) {
            amount = bets[betsHistory[_player]].bet;
        }
        return 0;
    }

    function betsLength() public view returns (uint256) {
        return bets.length;
    }
}

contract Lottery is RoundManager, Random {
    address public immutable WETH;
    address public immutable paperLP;
    address[] public WETH2PAPER;

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
        require(_path.length > 1 && _path[_path.length - 1] == WETH, "Wrong path");
        require(approvedTokens[_token] == true, "Approve new token first");
        require(_amountOutMin >= minBet, "Your bet is too small");

        transferTokens(_token, _amountIn);
        uint256 _swapWeTH =
        swap(
            _amountIn,
            _amountOutMin,
            _path,
            address(this)
        );

        roundBalance = roundBalance.add(_swapWeTH);
        accumulatedBalance = accumulatedBalance.add(_swapWeTH);
        addNewBet(_swapWeTH);
        mintToken(msg.sender);

        if (roundBalance >= roundLimit) {
            givePrize();
        }
    }

    function addNewBet(uint256 _amountETH) internal {
        betsHistory[msg.sender] = bets.length;
        bets.push(Bet({player: msg.sender, bet: _amountETH}));
        emit NewBet(msg.sender, _amountETH);
    }

    function givePrize() internal {
        uint256 prizeNumber = _randRange(1, roundLimit);
        address payable winner = payable(generateWinner(prizeNumber));

        uint256 userReward = allocatePaper();

        IWETH(WETH).withdraw(userReward);
        winner.transfer(userReward);

        // Clear round
        delete bets;
        roundBalance = 0;

        emit EndRound(winner, userReward);
        emit NewRound(roundLimit, paperReward);
    }

    function generateWinner(uint256 prizeNumber)
    internal
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

    function getAmountForRedeem(uint256 _amount, uint256 _part)
    internal
    pure
    returns (uint256)
    {
        return (_amount.mul(_part)).div(100);
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
}
