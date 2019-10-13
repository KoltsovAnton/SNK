pragma solidity ^0.5.2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Roles.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/GSN/Context.sol";


contract AdminRole is Initializable, Context {
    using Roles for Roles.Role;

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);
    event OwnerAdded(address indexed account);
    event OwnerRemoved(address indexed account);

    Roles.Role private _admins;
    Roles.Role private _owners;


    function initialize(address sender) public initializer {
        if (!isOwner(sender)) {
            _addOwner(sender);
        }
        if (!isAdmin()(sender)) {
            _addAdmin(sender);
        }
    }

    modifier onlyOwner() {
        require(isOwner(_msgSender()), "OwnerRole: caller does not have the Owner role");
        _;
    }

    function isOwner(address account) public view returns (bool) {
        return _owners.has(account);
    }

    function addOwner(address account) public onlyOwner {
        _addOwner(account);
    }

    function renounceOwner() public {
        _removeOwner(_msgSender());
    }

    function _addOwner(address account) internal {
        _owners.add(account);
        emit OwnerAdded(account);
    }

    function _removeOwner(address account) internal {
        _owners.remove(account);
        emit OwnerRemoved(account);
    }


    modifier onlyAdmin() {
        require(isOwner(_msgSender()), "AdminRole: caller does not have the Admin role");
        _;
    }

    function isAdmin(address account) public view returns (bool) {
        return _admins.has(account);
    }

    function addAdmin(address account) public onlyOwner {
        _addAdmin(account);
    }

    function renounceAdmin() public {
        _removeAdmin(msg.sender);
    }

    function removeAdmin(address account) public onlyOwner {
        _removeAdmin(account);
    }

    function _addAdmin(address account) internal {
        _admins.add(account);
        emit AdminAdded(account);
    }

    function _removeAdmin(address account) internal {
        _admins.remove(account);
        emit AdminRemoved(account);
    }

    uint256[50] private ______gap;
}
