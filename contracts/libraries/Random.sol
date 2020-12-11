pragma solidity ^0.6.12;

contract Random {
    uint256 internal saltForRandom;

    function _rand() internal returns (uint256) {
        // This turns the input data into a 100-sided die
        // by dividing by ceil(2 ^ 256 / 100).
        saltForRandom +=
        (uint256(msg.sender) % 100) +
        uint256(uint256(uint256(blockhash(block.number - 1))) / 1157920892373161954235709850086879078532699846656405640394575840079131296399);

        return saltForRandom;
    }

    function _randRange(uint256 min, uint256 max) internal returns (uint256) {
        return
        (uint256(keccak256(abi.encodePacked(_rand()))) % (max - min + 1)) +
        min;
    }
}
