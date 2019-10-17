pragma solidity ^0.5.0;

import "./Ownable.sol";
import "./IERC20.sol";

/**
 * @title Contracts that should be able to recover tokens
 * @author SylTi
 * @dev This allow a contract to recover any ERC20 token received in a contract by transferring the balance to the contract owner.
 * This will prevent any accidental loss of tokens.
 */
contract CanReclaimToken is Ownable {

  /**
   * @dev Reclaim all ERC20 compatible tokens
   * @param token ERC20 The address of the token contract
   */
  function reclaimToken(IERC20 token) external onlyOwner {
    address payable owner = address(uint160(owner()));

    if (address(token) == address(0)) {
      owner.transfer(address(this).balance);
      return;
    }
    uint256 balance = token.balanceOf(address(this));
    token.transfer(owner, balance);
  }

}
