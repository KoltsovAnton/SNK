pragma solidity ^0.5.10;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./lib/AdminRole.sol";


contract DividendManagerInterface {
    function depositDividend() external payable;
}

//TODO referral
contract SNKGame is Initializable, AdminRole {
    using SafeMath for uint;

    address public dividendManagerAddress;

    struct Node {
        mapping (bool => uint) children;
        uint parent;
        bool side;
        uint height;
        uint count;
        uint dupes;
    }

    struct Game {
        mapping(uint => Node) bets;
        uint res;
        uint resPos;
        uint amount;

        mapping(uint => address[]) users; //betValue => users
        mapping(uint => mapping(address => uint)) betUsers; // betValue => user => userBetAmount
        mapping(address => uint[]) userBets; //user => userBetValue
        mapping(address => bool) executed; //user => prizeExecuted

        uint winnersAmount;
        uint prizePool;
//        uint winnersCount;
        uint lastLeftPos;
        uint lastRightPos;
        uint lastLeftValue;
        uint lastRightValue;
        bool allDone;
    }

    mapping (uint => Game) public games;

    uint public gameStep;
    uint public closeBetsTime;
    uint public gamesStart;

    event NewBet(address indexed user, uint indexed game, uint bet, uint value);
    event ResultSet(uint indexed game, uint res, uint lastLeftValue, uint lastRightValue, uint amount);
    event PrizeTaken(address indexed user, uint game, uint amount);

    function initialize(address _dividendManagerAddress, uint _betAmount) public initializer {
        require(_dividendManagerAddress != address(0));
        AdminRole.initialize(sender);
        dividendManagerAddress = _dividendManagerAddress;

        gameStep = 10 minutes;
        closeBetsTime = 3 minutes;
        gamesStart = 1568332800; //Friday, 13 September 2019 г., 0:00:00
    }


//    constructor(address _dividendManagerAddress) public {
//        require(_dividendManagerAddress != address(0));
//        dividendManagerAddress = _dividendManagerAddress;
//
//        gameStep = 10 minutes;
//        closeBetsTime = 3 minutes;
//        gamesStart = 1568332800; //Friday, 13 September 2019 г., 0:00:00
//    }


    function() external payable {
        revert();
    }


    function makeBet(uint _game, uint _bet) public payable {
        require(_bet > 0);
        require(msg.value > 0);
        if (_game == 0) {
            _game = getCurrentGameId();
            if (now > getGameTime(_game) - closeBetsTime) {
                _game++;
            }
        } else {
            require(now < getGameTime(_game) - closeBetsTime);
        }

        _makeBet(games[_game], _bet);

        emit NewBet(msg.sender, _game, _bet, msg.value);
    }

    function setRes(uint _game, uint _res) onlyAdmin public {
        insertResult(_game, _res);
        setLastLeftRight(_game);
        shiftLeftRight(_game);
        setWinnersAmount(_game, 0, 0);
    }

    function insertResult(uint _game, uint _res) onlyAdmin public {
        //require(getGameTime(_game) < now);
        _insertResult(games[_game], _res);
    }

    function setLastLeftRight(uint _game) onlyAdmin public {
        _setLastLeftRight(games[_game]);
    }

    function shiftLeftRight(uint _game) onlyAdmin public {
        _shiftLeftRight(games[_game]);
    }


    //при передачи старт и стоп необходимо учитывать дубликаты (старт = последняя позиция дубликата)
    function setWinnersAmount(uint _game, uint _start, uint _stop) onlyAdmin public {
        _setWinnersAmount(games[_game], _start, _stop);
        if (games[_game].allDone) {
            emit ResultSet(_game, games[_game].res, games[_game].lastLeftValue, games[_game].lastRightValue, games[_game].amount);
        }
    }

    function isPrizeTaken(uint _game, address _user) public view returns (bool){
        return games[_game].executed[_user];
    }
    function isPrizeTaken(uint _game) public view returns (bool){
        return isPrizeTaken(_game, msg.sender);
    }


    function checkPrize(uint _game, address _user) public view returns (uint) {
        if (games[_game].executed[_user]) {
            return 0;
        }
        return _getPrizeAmount(games[_game], _user);
    }
    function checkPrize(uint _game) public view returns (uint) {
        return checkPrize(_game, msg.sender);
    }


    function getPrize(uint _game, address _user) public {
        uint amount = _getPrize(games[_game], _user);
        emit PrizeTaken(_user, _game, amount);
    }
    function getPrize(uint _game) public {
        getPrize(_game, msg.sender);
    }

    function getGameTime(uint _id) public view returns (uint) {
        return gamesStart + (gameStep * _id);
    }

    function setDividendManager(address _dividendManagerAddress) onlyOwner external  {
        require(_dividendManagerAddress != address(0));
        dividendManagerAddress = _dividendManagerAddress;
    }

    function getCurrentGameId() public view returns (uint) {
        return (now - gamesStart) / gameStep + 1;
    }

    function getNextGameId() external view returns (uint) {
        return (now - gamesStart) / gameStep + 2;
    }

    function getUserBetValues(uint _game, address _user) public view returns (uint[] memory values) {
        // values = new uint[](games[_game].userBets[msg.sender].length);
        // for (uint i = 0; i < games[_game].userBets[msg.sender].length; i++) {
        //     values[i] = games[_game].userBets[msg.sender][i];
        // }
        return games[_game].userBets[_user];
    }
    function getUserBetValues(uint _game) external view returns (uint[] memory values) {
        return getUserBetValues(_game, msg.sender);
    }

    function getUserBetAmounts(uint _game, address _user) public view returns (uint[] memory amounts) {
        amounts = new uint[](games[_game].userBets[_user].length);
        for (uint i = 0; i < games[_game].userBets[_user].length; i++) {
            amounts[i] = games[_game].betUsers[ games[_game].userBets[_user][i] ][_user];
        }
    }
    function getUserBetAmounts(uint _game) external view returns (uint[] memory values) {
        return getUserBetAmounts(_game, msg.sender);
    }


    //INTERNAL FUNCTIONS

    function _makeBet(Game storage game, uint _bet) internal {
        if (game.betUsers[_bet][msg.sender] == 0) {
            _insert(game, _bet);
            game.users[_bet].push(msg.sender);
            game.userBets[msg.sender].push(_bet);
        }

        game.amount = game.amount.add(msg.value);
        game.betUsers[_bet][msg.sender] = game.betUsers[_bet][msg.sender].add(msg.value);
    }


    function _insertResult(Game storage game, uint _res) internal {
        _insert(game, _res);
        game.res = _res;
        game.resPos = _getPos(game, _res);
    }


    function _setLastLeftRight(Game storage game) internal returns (bool) {
        require(game.res > 0);

        //JackPot
        if (game.bets[game.res].dupes > 0) {
            game.lastLeftPos = game.resPos;
            game.lastRightPos = game.resPos;
            game.lastLeftValue = game.res;
            game.lastRightValue = game.res;
            return true;
        }

        uint lastPos = _count(game) - 1;

        if (lastPos < 19) { //1 winner
            //если результат на первой или последней позиции то ставим победителя слева или справа
            if (game.resPos == 0 || game.resPos == lastPos) {
                game.lastLeftPos = game.resPos == 0 ? 1 : lastPos - 1;
                game.lastRightPos = game.lastLeftPos;
            } else {
                uint leftBet =  _select_at(game, game.resPos - 1);
                uint rightBet = _select_at(game, game.resPos + 1);
                uint leftBetDif = game.res - leftBet;
                uint rightBetDif = rightBet - game.res;

                if (leftBetDif == rightBetDif) {
                    game.lastLeftPos = game.resPos - 1;
                    game.lastRightPos = game.resPos + 1;
                }

                if (leftBetDif > rightBetDif) {
                    game.lastLeftPos = game.resPos + 1;
                    game.lastRightPos = game.resPos + 1;
                }

                if (leftBetDif < rightBetDif) {
                    //дубликатов в resPos нет, т.к. проверили выше в джекпоте
                    game.lastLeftPos = game.resPos - 1;
                    game.lastRightPos = game.resPos - 1;
                }
            }
        } else {
            uint winnersCount = lastPos.add(1).mul(10).div(100);
            uint halfWinners = winnersCount.div(2);

            if (game.resPos < halfWinners) {
                game.lastLeftPos = 0;
                game.lastRightPos = game.lastLeftPos + winnersCount;
            } else {
                if (game.resPos + halfWinners > lastPos) {
                    game.lastRightPos = lastPos;
                    game.lastLeftPos = lastPos - winnersCount;
                } else {
                    game.lastLeftPos = game.resPos - halfWinners;
                    game.lastRightPos = game.lastLeftPos + winnersCount;
                }
            }
        }

        game.lastLeftValue = _select_at(game, game.lastLeftPos);
        game.lastRightValue = _select_at(game, game.lastRightPos);


        //не учитывает дубликаты для left - dupes для right + dupes, но они и не нужны нам
        game.lastLeftPos = _getPos(game, game.lastLeftValue);
        game.lastRightPos = _getPos(game, game.lastRightValue);// + games[_game].bets[games[_game].lastRightValue].dupes;

        return true;
    }


    function _shiftRight(Game storage game, uint leftBetDif, uint rightBetDif, uint _val, uint lastPos) internal {
        uint gleft = gasleft();
        uint gasused = 0;
        uint lastRightValue = game.lastRightValue;
        uint lastRightPos = game.lastRightPos;
        uint lastLeftValue = game.lastLeftValue;
        uint lastLeftPos = game.lastLeftPos;
        while (leftBetDif > rightBetDif) {

            lastRightValue = _val;
            lastRightPos = lastRightPos + 1 + game.bets[_val].dupes;

            lastLeftValue = _select_at(game, lastLeftValue + 1);
            lastLeftPos = _getPos(game, lastLeftValue);

            if (lastRightPos == lastPos) break;
            if (lastLeftPos >= game.resPos) break;

            _val = _select_at(game, lastRightPos + 1);
            leftBetDif = game.res - lastLeftValue;
            rightBetDif = _val - game.res;

            if (gasused == 0) {
                gasused = gleft - gasleft() + 100000;
            }
            if (gasleft() < gasused) break;
        }

        game.lastRightValue = lastRightValue;
        game.lastRightPos = lastRightPos;
        game.lastLeftValue = lastLeftValue;
        game.lastLeftPos = lastLeftPos;
    }


    function _shiftLeft(Game storage game, uint leftBetDif, uint rightBetDif, uint _val) internal {
        uint gleft = gasleft();
        uint gasused = 0;
        uint lastRightValue = game.lastRightValue;
        uint lastRightPos = game.lastRightPos;
        uint lastLeftValue = game.lastLeftValue;
        uint lastLeftPos = game.lastLeftPos;
        while (rightBetDif > leftBetDif) {
            lastLeftValue = _val;
            lastLeftPos = lastLeftPos - game.bets[lastLeftValue].dupes - 1;

            lastRightPos = lastRightPos - game.bets[lastRightValue].dupes - 1;
            lastRightValue = _select_at(game, lastRightPos);

            if (lastLeftPos - game.bets[lastLeftValue].dupes == 0) break;
            if (lastRightPos <= game.resPos) break;

            _val = _select_at(game, lastLeftPos - game.bets[lastLeftValue].dupes - 1);
            leftBetDif = game.res - lastLeftValue;
            rightBetDif = _val - game.res;

            if (gasused == 0) {
                gasused = gleft - gasleft() + 100000;
            }
            if (gasleft() < gasused) break;
        }

        game.lastRightValue = lastRightValue;
        game.lastRightPos = lastRightPos;
        game.lastLeftValue = lastLeftValue;
        game.lastLeftPos = lastLeftPos;
    }

    function _shiftLeftRight(Game storage game) internal returns (bool) {
        uint leftBetDif = game.res - game.lastLeftValue;
        uint rightBetDif = game.lastRightValue - game.res;
        if (rightBetDif == leftBetDif) return true;

        uint _val;


        if (leftBetDif > rightBetDif) {
            uint lastPos = _count(game) - 1;
            if (game.lastRightPos == lastPos) return true;
            if (game.lastLeftPos >= game.resPos) return true;
            // в lastRightPos последняя позиция дубля поэтому просто +1
            _val = _select_at(game, game.lastRightPos + 1);
            rightBetDif = _val - game.res;

            _shiftRight(game, leftBetDif, rightBetDif, _val, lastPos);

        } else {
            if (game.lastLeftPos - game.bets[game.lastLeftValue].dupes == 0) return true;
            if (game.lastRightPos <= game.resPos) return true;
            //последняя позиция дубля поэтому минус дубликаты
            _val = _select_at(game, game.lastLeftPos - game.bets[game.lastLeftValue].dupes - 1);
            leftBetDif = game.res - _val;

            _shiftLeft(game, leftBetDif, rightBetDif, _val);
        }

        return true;
    }


    //при передачи старт и стоп необходимо учитывать дубликаты (старт = последняя позиция дубликата)
    function _setWinnersAmount(Game storage game, uint _start, uint _stop) internal {
        uint _bet;
        uint _betAmount;
        if (game.lastLeftPos == game.lastRightPos) {
            _bet = _select_at(game, game.lastLeftPos);
            game.winnersAmount = _getBetAmount(game, _bet);
//            game.winnersCount = game.users[_bet].length;
            game.allDone = true;
        } else {
            _start = _start > 0 ? _start : game.lastLeftPos;
            _stop = _stop > 0 ? _stop : game.lastRightPos;
            uint i = _start;
            uint winnersAmount;
//            uint winnersCount;
            while(i <= _stop) {
                if (i == game.resPos) {
                    i++;
                    continue;
                }
                _bet = _select_at(game, i);
                _betAmount = _getBetAmount(game, _bet);
                winnersAmount = winnersAmount.add(_betAmount);
//                winnersCount = winnersCount.add(1);
                //верим что старт == последней позиции дубликата
                if (i != _start && game.bets[_bet].dupes > 0) {
                    i += game.bets[_bet].dupes;
//                    winnersCount = winnersCount.add(game.bets[_bet].dupes);
//                    winnersAmount = winnersAmount.add(game.bets[_bet].dupes * _betAmount);
                }

                if (i >= game.lastRightPos) game.allDone = true;
                i++;
            }
            // это сумма ставок победителей!
            game.winnersAmount = winnersAmount;
//            game.winnersCount = winnersCount;
        }

        if (game.allDone) {
            uint profit = game.amount - game.winnersAmount;
            uint ownerPercent = _valueFromPercent(profit, 1000); //10% fee
            DividendManagerInterface dividendManager = DividendManagerInterface(dividendManagerAddress);
            dividendManager.depositDividend.value(ownerPercent)();
            game.prizePool = profit.sub(ownerPercent);
        }

    }


    function _getBetAmount(Game storage game, uint _bet) internal view returns (uint amount) {
        for (uint i = 0; i < game.users[_bet].length; i++) {
            amount = amount.add(game.betUsers[_bet][game.users[_bet][i]]);
        }
    }


    function _getPrize(Game storage game, address user) internal returns (uint amount) {
        require(game.allDone);
        require(!game.executed[user]);
        game.executed[user] = true;
        amount = _getPrizeAmount(game, user);

        require(amount > 0);
        msg.sender.transfer(amount);

//        for (uint i = 0; i < game.userBets[msg.sender].length; i++) {
//            if (game.userBets[msg.sender][i] >= game.lastLeftValue &&
//                game.userBets[msg.sender][i] <= game.lastRightValue)
//            {
//                amount += game.betUsers[game.userBets[msg.sender][i]][msg.sender];
//            }
//        }
//
//        if (amount > 0) {
//            uint p = _percent(amount, game.winnersAmount, 4);
//            msg.sender.transfer(_valueFromPercent(game.amount, p));
//        }
    }


    // todo remove
    function getPrizeAmount(uint _game, address _user) public view returns (uint) {
        return _getPrizeAmount(games[_game], _user);
    }
    function getUserAmount(uint _game, address _user) public view returns (uint) {
        return _getUserAmount(games[_game], _user);
    }

    function _getPrizeAmount(Game storage game, address user) internal view returns (uint amount){
        amount = _getUserAmount(game, user);
        if (amount > 0) {
            // доля суммы ставок игрока, которые вошли в число победивших от общей суммы ставок победителей
            amount = game.prizePool.mul(amount).div(game.winnersAmount);
        }
    }

    function _getUserAmount(Game storage game, address user) internal view returns (uint amount){
//        amount = 0;
        for (uint i = 0; i < game.userBets[user].length; i++) {
            if (game.userBets[user][i] >= game.lastLeftValue &&
                game.userBets[user][i] <= game.lastRightValue)
            {
                amount += game.betUsers[game.userBets[user][i]][user];
            }
        }
    }

    //1% - 100, 10% - 1000 50% - 5000
    function _valueFromPercent(uint _value, uint _percent) internal pure returns(uint quotient) {
        uint _quotient = _value.mul(_percent).div(10000);
        return ( _quotient);
    }


    function _percent(uint numerator, uint denominator, uint precision) internal pure returns(uint) {
        uint _numerator  = numerator * 10 ** (precision+1);
        uint _quotient =  ((_numerator / denominator) + 5) / 10;
        return _quotient;
    }



    //AVL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    function getPos(uint _game, uint _value) public view returns (uint) {
        return _getPos(games[_game], _value);
    }

    function select_at(uint _game, uint pos) public view returns (uint) {
        return _select_at(games[_game], pos);
    }

    function count(uint _game) public view returns (uint) {
        return _count(games[_game]);
    }



    //internal
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function _insert(Game storage game, uint _value) internal {
        if (_value==0)
            game.bets[_value].dupes++;
        else{
            insert_helper(game, 0, true, _value);
        }
    }

    //если есть дупбликаты, то возвращает позицию послденего элемента
    function _getPos(Game storage game, uint _value) internal view returns (uint) {
        uint c = _count(game);
        if (c == 0) return 0; //err
        if (game.bets[_value].count == 0) return 0; //err

        uint _first = _select_at(game, 0);
        uint _last = _select_at(game, c-1);

        // Shortcut for the actual value
        if (_value > _last || _value < _first) return 0; //err
        if (_value == _first) return 0;
        if (_value == _last) return c - 1;

        // Binary search of the value in the array
        uint min = 0;
        uint max = c-1;
        while (max > min) {
            uint mid = (max + min + 1)/ 2;
            uint _val = _select_at(game, mid);
            if (_val <= _value) {
                min = mid;
            } else {
                max = mid-1;
            }
        }
        return min;
    }


    function _select_at(Game storage game, uint pos) internal view returns (uint value){
        uint zeroes=game.bets[0].dupes;
        // Node memory left_node;
        uint left_count;
        if (pos<zeroes) {
            return 0;
        }
        uint pos_new=pos-zeroes;
        uint cur=game.bets[0].children[true];
        Node storage cur_node=game.bets[cur];
        while(true){
            uint left=cur_node.children[false];
            uint cur_num=cur_node.dupes+1;
            if (left!=0) {

                left_count=game.bets[left].count;
            }
            else {
                left_count=0;
            }
            if (pos_new<left_count) {
                cur=left;
                cur_node=game.bets[left];
            }
            else if (pos_new<left_count+cur_num){
                return cur;
            }
            else {
                cur=cur_node.children[true];
                cur_node=game.bets[cur];
                pos_new-=left_count+cur_num;
            }
        }

    }


    function _count(Game storage game) internal view returns (uint){
        Node storage root=game.bets[0];
        Node storage child=game.bets[root.children[true]];
        return root.dupes+child.count;
    }


    function insert_helper(Game storage game, uint p_value, bool side, uint value) private {
        Node storage root=game.bets[p_value];
        uint c_value=root.children[side];
        if (c_value==0){
            root.children[side]=value;
            Node storage child=game.bets[value];
            child.parent=p_value;
            child.side=side;
            child.height=1;
            child.count=1;
            update_counts(game, value);
            rebalance_insert(game, value);
        }
        else if (c_value==value){
            game.bets[c_value].dupes++;
            update_count(game, value);
            update_counts(game, value);
        }
        else{
            bool side_new=(value >= c_value);
            insert_helper(game, c_value,side_new,value);
        }
    }


    function update_count(Game storage game, uint value) private {
        Node storage n=game.bets[value];
        n.count=1+game.bets[n.children[false]].count+game.bets[n.children[true]].count+n.dupes;
    }


    function update_counts(Game storage game, uint value) private {
        uint parent=game.bets[value].parent;
        while (parent!=0) {
            update_count(game, parent);
            parent=game.bets[parent].parent;
        }
    }


    function rebalance_insert(Game storage game, uint n_value) private {
        update_height(game, n_value);
        Node storage n=game.bets[n_value];
        uint p_value=n.parent;
        if (p_value!=0) {
            int p_bf=balance_factor(game, p_value);
            bool side=n.side;
            int sign;
            if (side)
                sign=-1;
            else
                sign=1;
            if (p_bf == sign*2) {
                if (balance_factor(game, n_value) == (-1 * sign))
                    rotate(game, n_value,side);
                rotate(game, p_value,!side);
            }
            else if (p_bf != 0)
                rebalance_insert(game, p_value);
        }
    }


    function update_height(Game storage game, uint value) private {
        Node storage n=game.bets[value];
        uint height_left=game.bets[n.children[false]].height;
        uint height_right=game.bets[n.children[true]].height;
        if (height_left>height_right)
            n.height=height_left+1;
        else
            n.height=height_right+1;
    }


    function balance_factor(Game storage game, uint value) private view returns (int bf) {
        Node storage n=game.bets[value];
        return int(game.bets[n.children[false]].height)-int(game.bets[n.children[true]].height);
    }


    function rotate(Game storage game, uint value,bool dir) private {
        bool other_dir=!dir;
        Node storage n=game.bets[value];
        bool side=n.side;
        uint parent=n.parent;
        uint value_new=n.children[other_dir];
        Node storage n_new=game.bets[value_new];
        uint orphan=n_new.children[dir];
        Node storage p=game.bets[parent];
        Node storage o=game.bets[orphan];
        p.children[side]=value_new;
        n_new.side=side;
        n_new.parent=parent;
        n_new.children[dir]=value;
        n.parent=value_new;
        n.side=dir;
        n.children[other_dir]=orphan;
        o.parent=value;
        o.side=other_dir;
        update_height(game, value);
        update_height(game, value_new);
        update_count(game, value);
        update_count(game, value_new);
    }

}