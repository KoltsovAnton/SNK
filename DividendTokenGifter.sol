pragma solidity ^0.5.0;

import "./lib/IERC20.sol";
import "./lib/CanReclaimToken.sol";


contract DividendToken is IERC20 {
    function name() external view returns (string memory);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}


/// @dev The actual token contract, the default owner is the msg.sender
contract DividendTokenGifter is CanReclaimToken {
    DividendToken private _token;
    uint private _giftAmount;
    address private _store;

    string public symbol;
    string public name;
    uint8 public decimals;

    modifier ifOwner() {
        if (isOwner()) {
            _;
        }
    }

    constructor(DividendToken token, uint amount) public {
        setToken(token);
        setGiftAmount(amount);
    }

    function() external payable {
        gift();
    }

    function setGiftAmount(uint amount) public onlyOwner {
        require(amount > 0);
        _giftAmount = amount;
    }

    function setToken(DividendToken token) public onlyOwner {
        require(address(token) != address(0));
        _token = token;
        name = _token.name();
        symbol = _token.symbol();
        decimals = _token.decimals();
    }

    function setStore(address store) public onlyOwner {
        require(store != address(0));
        _store = store;
    }


    function store() external view ifOwner returns (address) {
        return _store;
    }

    function token() external view returns (address) {
        return address(_token);
    }

    function giftAmount() public view returns (uint) {
        return _token.balanceOf(msg.sender) > 0 ? 0 : _giftAmount;
    }

    function balance() public view returns (uint) {
        if (_store != address(0)) {
            return _token.allowance(_store, address(this));
        } else {
            return _token.balanceOf(address(this));
        }
    }

    function gift() public payable returns (uint amount) {
        amount = giftAmount() * 10 ** uint(decimals);
        require(amount > 0, 'No avail tokens');
        require(balance() > amount, 'Not enough tokens');
        if (_store == address(0)) {
            _token.transfer(msg.sender, amount);
        } else {
            _token.transferFrom(_store, msg.sender, amount);
        }
    }

    function reclaim(address recipient) external onlyOwner returns (uint amount) {
        require(recipient != address(0));
        amount = _token.balanceOf(address(this));
        require(amount > 0);
        _token.transfer(recipient, amount);
    }

    function withdraw(address payable recipient) external onlyOwner returns (uint amount) {
        require(recipient != address(0));
        amount = address(this).balance;
        require(amount > 0);
        recipient.transfer(amount);
    }
}

