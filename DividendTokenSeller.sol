pragma solidity ^0.5.0;

import "./lib/IERC20.sol";
import "./lib/CanReclaimToken.sol";


contract DividendToken is IERC20 {
    function name() external view returns (string memory);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}


/// @dev The actual token contract, the default owner is the msg.sender
contract DividendTokenSeller is CanReclaimToken {
    DividendToken private _token;
    uint private _price;
    uint private _discount;
    address private _store;
    address payable private _wallet;

    string public symbol;
    string public name;
    uint8 public decimals;

    modifier ifOwner() {
        if (isOwner()) {
            _;
        }
    }

    constructor(DividendToken token, uint price, uint discount) public {
        setToken(token);
        setPrice(price);
        setDiscount(discount);
    }

    function() external payable {
        if (msg.value > 0) {
            buy();
        }
    }

    function setPrice(uint price) public onlyOwner {
        require(price > 0);
        _price = price;
    }

    // 100 - 1%, 1 - 0.01%, 10000 - 100%
    function setDiscount(uint discount) public onlyOwner {
        require(discount <= 10000);
        _discount = discount;
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

    function setWallet(address payable wallet) public onlyOwner {
        require(wallet != address(0));
        _wallet = wallet;
    }

    function store() external view ifOwner returns (address) {
        return _store;
    }

    function wallet() external view ifOwner returns (address) {
        return _wallet;
    }

    function token() external view returns (address) {
        return address(_token);
    }

    function discount() external view returns (uint) {
        return _discount;
    }

    function price() public view returns (uint) {
        return (_discount > 0 && _token.balanceOf(msg.sender) > 0) ? _price * (10000 - _discount) / 10000 : _price;
    }


    function balance() public view returns (uint) {
        if (_store != address(0)) {
            return _token.allowance(_store, address(this));
        } else {
            return _token.balanceOf(address(this));
        }
    }

    function buy() public payable returns (uint amount){
        uint sum = msg.value * 10 ** uint(decimals);
        uint finalPrice = price();
        amount = balance();
        if (amount > sum / finalPrice) {
            amount = sum / finalPrice;
        }
        require(amount > 0, 'Not enough money');

        uint rest = sum - amount * finalPrice;
        if (rest > 0) {
            msg.sender.transfer(rest);
        }
        if (_wallet != address(0)) {
            _wallet.transfer(msg.value - rest);
        }
        if (_store == address(0)) {
            _token.transfer(msg.sender, amount);
        } else {
            _token.transferFrom(_store, msg.sender, amount);
        }
        return amount;
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

