pragma solidity ^0.6.12;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './AdminContract.sol';

contract PaperToken is ERC20("PAPER token", "PAPER"), AdminContract {
    uint256 private maxSupplyPaper = 69000 * 1e18;

    function mintPaper(address _to, uint256 _amount)
        public
        virtual
        onlyGovernance
        returns (bool)
    {
        require(
            totalSupply().add(_amount) <= maxSupplyPaper,
            "Emission limit exceeded"
        );
        _mint(_to, _amount);
        return true;
    }

    function maxSupply() public view returns (uint256) {
        return maxSupplyPaper;
    }
}
