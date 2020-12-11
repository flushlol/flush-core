pragma solidity ^0.6.12;

import '@openzeppelin/contracts/access/Ownable.sol';

contract TokensManager is Ownable {
    using SafeMath for uint256;

    PaperToken public paper;

    uint256 internal paperReward = 1e18;
    address internal router;
    address public developers;
    address[] public availableTokens;

    address public farmContract;

    uint256 internal farmPart = 3; // default param
    uint256 internal burnedPart = 7; // default param

    uint256 internal approveAmount =
    115792089237316195423570985008687907853269984665640564039457584007913129639935;

    event AddNewToken(address token, uint256 tokenId);
    event UpdateToken(address previousToken, address newToken, uint256 tokenId);

    function addTokens(address _token) public onlyOwner returns (uint256) {
        availableTokens.push(_token);
        emit AddNewToken(_token, availableTokens.length);
        IERC20(_token).approve(router, approveAmount);
        return availableTokens.length;
    }

    function setToken(uint256 _tokenId, address _token) public onlyOwner {
        emit UpdateToken(availableTokens[_tokenId], _token, _tokenId);
        availableTokens[_tokenId] = _token;
        IERC20(_token).approve(router, 1e66);
    }

    function setApproveAmount(uint256 _newAmount) public onlyOwner {
        approveAmount = _newAmount;
    }

    function swap(
        uint256 _tokenAmount,
        address _a,
        address _b,
        uint256 amountMinArray,
        address _recipient
    ) internal returns (uint256) {
        address[] memory _path = new address[](2);
        _path[0] = _a;
        _path[1] = _b;
        uint256[] memory amounts_ =
        IUniswapV2Router02(router).swapExactTokensForTokens(
            _tokenAmount,
            amountMinArray,
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

    function transferTokens(uint256 _tokenId, uint256 _tokenAmount) internal {
        IERC20(availableTokens[_tokenId]).transferFrom(
            msg.sender,
            address(this),
            _tokenAmount
        );
    }

    function getAmountTokens(
        address _a,
        address _b,
        uint256 _tokenAmount
    ) public view returns (uint256) {
        address[] memory _path = new address[](2);
        _path[0] = _a;
        _path[1] = _b;
        uint256[] memory amountMinArray =
        IUniswapV2Router02(router).getAmountsOut(_tokenAmount, _path);

        return amountMinArray[1];
    }

    function setPaperReward(uint256 _newAmount) public onlyOwner {
        paperReward = _newAmount;
    }

    function getPaperReward() public view returns (uint256) {
        return paperReward;
    }

    function getBurnedPart() public view returns (uint256) {
        return burnedPart;
    }

    function getFarmPart() public view returns (uint256) {
        return farmPart;
    }

    function setBurnedPart(uint256 _newAmount) public onlyOwner {
        burnedPart = _newAmount;
    }

    function setFarmPart(uint256 _newAmount) public onlyOwner {
        farmPart = _newAmount;
    }

    function setFarmContract(address _newContract) public onlyOwner {
        farmContract = _newContract;
    }
}
