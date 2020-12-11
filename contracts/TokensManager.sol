pragma solidity ^0.6.12;

import '@openzeppelin/contracts/access/Ownable.sol';

contract TokensManager is Ownable {
    using SafeMath for uint256;

    PaperToken public paper;

    uint256 public paperReward = 1e18;
    address internal router;
    address public developers;

    address public farmContract;

    uint256 public farmPart = 3; // default param
    uint256 public lpPart = 7; // default param

    uint256 internal approveAmount =
    115792089237316195423570985008687907853269984665640564039457584007913129639935;

    mapping(address => bool) public approvedTokens;

    event AddNewToken(address token);

    function approveToken(address _token) public returns (bool) {
        IERC20(_token).approve(router, approveAmount);
        approvedTokens[_token] = true;
        emit AddNewToken(_token);
        return true;
    }

    function setApproveAmount(uint256 _newAmount) public onlyOwner {
        approveAmount = _newAmount;
    }

    function swap(
        uint256 _tokenAmount,
        uint256 _minAmount,
        address[] memory _path,
        address _recipient
    ) internal returns (uint256) {
        uint256[] memory amounts_ =
        IUniswapV2Router02(router).swapExactTokensForTokens(
            _tokenAmount,
            _minAmount,
            _path,
            _recipient,
            now + 1200
        );
        return amounts_[amounts_.length - 1];
    }

    function mintToken(address _sender) internal {
        paper.mintPaper(_sender, paperReward);
        paper.mintPaper(developers, paperReward.div(10));
    }

    function transferTokens(address _token, uint256 _tokenAmount) internal {
        IERC20(_token).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );
    }

    function getAmountOut(
        uint256 _tokenAmount,
        address[] memory _path
    ) public view returns (uint256) {
        uint256[] memory amountMinArray =
        IUniswapV2Router02(router).getAmountsOut(_tokenAmount, _path);

        return amountMinArray[amountMinArray.length - 1];
    }

    function setPaperReward(uint256 _newAmount) public onlyOwner {
        paperReward = _newAmount;
    }

    function setLPPart(uint256 _newAmount) public onlyOwner {
        lpPart = _newAmount;
    }

    function setFarmPart(uint256 _newAmount) public onlyOwner {
        farmPart = _newAmount;
    }

    function setFarmContract(address _newContract) public onlyOwner {
        farmContract = _newContract;
    }
}
