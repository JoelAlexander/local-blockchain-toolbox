//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Faucet {

    using Math for uint;
    using SafeMath for uint;

    uint private constant DISBURSEMENT_FRACTION = 1000000;
    uint private constant DISBURSEMENT_PERIOD_BLOCKS = 14400;

    mapping(address => uint) private canUseFaucetAtBlock;

    function claim() public {
        require(canUse(msg.sender), "You must wait before using the faucet again");
        canUseFaucetAtBlock[msg.sender] = block.number + DISBURSEMENT_PERIOD_BLOCKS;
        (, uint amount) = balance().tryDiv(DISBURSEMENT_FRACTION);
        payable(msg.sender).transfer(amount);
    }

    function balance() public view returns (uint) {
        return address(this).balance;
    }

    function canUseAtBlock(address a) public view returns (uint) {
        return canUseFaucetAtBlock[a];
    }

    function canUse(address a) public view returns (bool) {
        return block.number >= canUseAtBlock(a);
    }

    function pay() public payable {}
}
