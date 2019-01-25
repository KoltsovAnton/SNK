pragma solidity 0.4.25;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {
    int256 constant private INT256_MIN = -2**255;

    /**
    * @dev Multiplies two unsigned integers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Multiplies two signed integers, reverts on overflow.
    */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == INT256_MIN)); // This is the only case of overflow not detected by the check below

        int256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Integer division of two signed integers truncating the quotient, reverts on division by zero.
    */
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0); // Solidity only automatically asserts when dividing by 0
        require(!(b == -1 && a == INT256_MIN)); // This is the only case of overflow

        int256 c = a / b;

        return c;
    }

    /**
    * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Subtracts two signed integers, reverts on overflow.
    */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a));

        return c;
    }

    /**
    * @dev Adds two unsigned integers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
    * @dev Adds two signed integers, reverts on overflow.
    */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));

        return c;
    }

    /**
    * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}


/**
 * @title MerkleProof
 * @dev Merkle proof verification based on
 * https://github.com/ameensol/merkle-tree-solidity/blob/master/src/MerkleProof.sol
 */
library MerkleProof {
    /**
     * @dev Verifies a Merkle proof proving the existence of a leaf in a Merkle tree. Assumes that each pair of leaves
     * and each pair of pre-images are sorted.
     * @param proof Merkle proof containing sibling hashes on the branch from the leaf to the root of the Merkle tree
     * @param root Merkle root
     * @param leaf Leaf of Merkle tree
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == root;
    }
}

/**
 * @title Roles
 * @dev Library for managing addresses assigned to a Role.
 */
library Roles {
    struct Role {
        mapping (address => bool) bearer;
    }

    /**
     * @dev give an account access to this role
     */
    function add(Role storage role, address account) internal {
        require(account != address(0));
        require(!has(role, account));

        role.bearer[account] = true;
    }

    /**
     * @dev remove an account's access to this role
     */
    function remove(Role storage role, address account) internal {
        require(account != address(0));
        require(has(role, account));

        role.bearer[account] = false;
    }

    /**
     * @dev check if an account has this role
     * @return bool
     */
    function has(Role storage role, address account) internal view returns (bool) {
        require(account != address(0));
        return role.bearer[account];
    }
}


contract AdminRole {
    using Roles for Roles.Role;

    event AdminAdded(address indexed account);
    event AdminRemoved(address indexed account);
    event OwnerAdded(address indexed account);
    event OwnerRemoved(address indexed account);

    Roles.Role private _admins;
    Roles.Role private _owners;

    constructor () internal {
        _addAdmin(msg.sender);
        _addOwner(msg.sender);
    }

    modifier onlyOwner() {
        require(isOwner(msg.sender));
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender));
        _;
    }

    function isOwner(address account) public view returns (bool) {
        return _owners.has(account);
    }

    function isAdmin(address account) public view returns (bool) {
        return _admins.has(account);
    }

    //    function addOwner(address account) public onlyOwner {
    //        _addOwner(account);
    //    }

    function addAdmin(address account) public onlyOwner {
        _addAdmin(account);
    }

    function renounceAdmin() public {
        _removeAdmin(msg.sender);
    }

    //    function renounceOwner() public {
    //        _removeOwner(msg.sender);
    //    }

    function removeAdmin(address account) public onlyOwner {
        _removeAdmin(account);
    }

    function _addAdmin(address account) internal {
        _admins.add(account);
        emit AdminAdded(account);
    }

    function _addOwner(address account) internal {
        _owners.add(account);
        emit OwnerAdded(account);
    }

    function _removeAdmin(address account) internal {
        _admins.remove(account);
        emit AdminRemoved(account);
    }

    //    function _removeOwner(address account) internal {
    //        _owners.remove(account);
    //        emit OwnerRemoved(account);
    //    }
}

contract DividendManagerInterface {
    function depositDividend() external payable;
}


//TODO referral
contract SNKGame is AdminRole {
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
        uint lastLeftPos;
        uint lastRightPos;
        uint lastLeftValue;
        uint lastRightValue;
        bool allDone;
    }

    mapping (uint => Game) public games;
    mapping (uint => Game) public royalGames;

    uint public gameStep;
    uint public closeBetsTime;
    uint public gamesStart;

    uint public gameStepRoyal;
    uint public closeBetsTimeRoyal;
    uint public gamesStartRoyal;

    uint public royalGameBonus;


    event NewBet(address indexed user, uint game, uint bet, uint value);
    event NewRoyalBet(address indexed user, uint game, uint bet, uint value);
    event ResultSet(uint game, uint res, uint lastLeftValue, uint lastRightValue);
    event RoyalResultSet(uint game, uint res, uint lastLeftValue, uint lastRightValue);

    constructor(address _dividendManagerAddress) public {
        require(_dividendManagerAddress != address(0));
        dividendManagerAddress = _dividendManagerAddress;

        gameStep = 1 hours;
        closeBetsTime = 1 hours;
        gamesStart = 1546318800;

        gameStepRoyal = 7 days;
        closeBetsTimeRoyal = 1 days;
        gamesStartRoyal = 1546318800;
    }


    function() public payable {
        revert();
    }



    function makeBet(uint _game, uint _bet) public payable {
        require(_bet > 0);
        require(msg.value > 0);
        require(getGameTime(_game) - closeBetsTime > now);

        _makeBet(games[_game], _bet);

        emit NewBet(msg.sender, _game, _bet, msg.value);
    }

    //TODO merkle proof
    function makeBetRoyal(uint _game, uint _bet) public payable {
        require(_bet > 0);
        require(msg.value > 0);
        require(getGameTimeRoyal(_game) - closeBetsTimeRoyal > now);

        _makeBet(royalGames[_game], _bet);

        emit NewRoyalBet(msg.sender, _game, _bet, msg.value);
    }


    function insertResult(uint _game, uint _res) onlyAdmin public {
        //require(getGameTime(_game) < now);
        _insertResult(games[_game], _res);
    }


    function insertResultRoyal(uint _game, uint _res) onlyAdmin public {
        //require(getGameTimeRoyal(_game) < now);
        _insertResult(royalGames[_game], _res);
        royalGames[_game].amount = royalGames[_game].amount.add(royalGameBonus);
        royalGameBonus = 0;
    }

    function setLastLeftRight(uint _game) onlyAdmin public {
        _setLastLeftRight(games[_game]);
    }

    function setLastLeftRightRoyal(uint _game) onlyAdmin public {
        _setLastLeftRight(royalGames[_game]);
    }

    function shiftLeftRight(uint _game) onlyAdmin public {
        _shiftLeftRight(games[_game]);
    }

    function shiftLeftRightRoyal(uint _game) onlyAdmin public {
        _shiftLeftRight(royalGames[_game]);
    }


    //при передачи старт и стоп необходимо учитывать дубликаты (старт = последняя позиция дубликата)
    function setWinnersAmount(uint _game, uint _start, uint _stop) onlyAdmin public {
        _setWinnersAmount(games[_game], _start, _stop);
        if (games[_game].allDone) {
            emit ResultSet(_game, games[_game].res, games[_game].lastLeftValue, games[_game].lastRightValue);
        }
    }

    //при передачи старт и стоп необходимо учитывать дубликаты (старт = последняя позиция дубликата)
    function setWinnersAmountRoyal(uint _game, uint _start, uint _stop) onlyAdmin public {
        _setWinnersAmount(royalGames[_game], _start, _stop);
        if (royalGames[_game].allDone) {
            emit RoyalResultSet(_game, royalGames[_game].res, royalGames[_game].lastLeftValue, royalGames[_game].lastRightValue);
        }
    }


    function _getPrize(uint _game) public {
        _getPrize(games[_game]);
    }


    function _getPrizeRoyal(uint _game) public {
        _getPrize(royalGames[_game]);
    }


    function getGameTime(uint _id) public view returns (uint) {
        return gamesStart + (gameStep * _id);
    }


    function getGameTimeRoyal(uint _id) public view returns (uint) {
        return gamesStartRoyal + (gameStepRoyal * _id);
    }

    function setDividendManager(address _dividendManagerAddress) onlyOwner external  {
        require(_dividendManagerAddress != address(0));
        dividendManagerAddress = _dividendManagerAddress;
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


    function _shiftLeftRight(Game storage game) internal returns (bool) {
        uint leftBetDif = game.res - game.lastLeftValue;
        uint rightBetDif = game.lastRightValue - game.res;
        if (rightBetDif == leftBetDif) return true;

        uint _val;
        uint lastPos = _count(game) - 1;

        uint gleft = 0;
        uint gasused = 0;

        if (leftBetDif > rightBetDif) {
            if (game.lastRightPos == lastPos) return true;
            if (game.lastLeftPos >= game.resPos) return true;
            // в lastRightPos последняя позиция дубля поэтому просто +1
            _val = _select_at(game, game.lastRightPos + 1);
            rightBetDif = _val - game.res;

            gleft = gasleft();
            gasused = 0;
            while (leftBetDif > rightBetDif) {

                game.lastRightValue = _val;
                game.lastRightPos = game.lastRightPos + 1 + game.bets[_val].dupes;

                game.lastLeftValue = _select_at(game, game.lastLeftPos + 1);
                game.lastLeftPos = _getPos(game, game.lastLeftValue);

                if (game.lastRightPos == lastPos) break;
                if (game.lastLeftPos >= game.resPos) break;

                _val = _select_at(game, game.lastRightPos + 1);
                leftBetDif = game.res - game.lastLeftValue;
                rightBetDif = _val - game.res;

                if (gasused == 0) {
                    gasused = gleft - gasleft() + 20000;
                }
                if (gasleft() < gasused) break;
            }

        } else {
            if (game.lastLeftPos - game.bets[game.lastLeftValue].dupes == 0) return true;
            if (game.lastRightPos <= game.resPos) return true;
            //последняя позиция дубля поэтому минус дубликаты
            _val = _select_at(game, game.lastLeftPos - game.bets[game.lastLeftValue].dupes - 1);
            leftBetDif = game.res - _val;

            gleft = gasleft();
            gasused = 0;
            while (rightBetDif > leftBetDif) {
                game.lastLeftValue = _val;
                game.lastLeftPos = game.lastLeftPos - game.bets[game.lastLeftValue].dupes - 1;

                game.lastRightPos = game.lastRightPos - game.bets[game.lastRightValue].dupes - 1;
                game.lastRightValue = _select_at(game, game.lastRightPos);

                if (game.lastLeftPos - game.bets[game.lastLeftValue].dupes == 0) break;
                if (game.lastRightPos <= game.resPos) break;

                _val = _select_at(game, game.lastLeftPos - game.bets[game.lastLeftValue].dupes - 1);
                leftBetDif = game.res - game.lastLeftValue;
                rightBetDif = _val - game.res;

                if (gasused == 0) {
                    gasused = gleft - gasleft() + 20000;
                }
                if (gasleft() < gasused) break;
            }
        }

        return true;
    }


    //при передачи старт и стоп необходимо учитывать дубликаты (старт = последняя позиция дубликата)
    function _setWinnersAmount(Game storage game, uint _start, uint _stop) internal {
        uint _bet;
        if (game.lastLeftPos == game.lastRightPos) {
            _bet = _select_at(game, game.lastLeftPos);
            game.winnersAmount = _getBetAmount(game, _bet);
            game.allDone = true;
        } else {
            _start = _start > 0 ? _start : game.lastLeftPos;
            _stop = _stop > 0 ? _stop : game.lastRightPos;
            uint i = _start;
            while(i <= _stop) {
                if (i == game.resPos) {
                    i++;
                    continue;
                }
                _bet = _select_at(game, i);
                game.winnersAmount = game.winnersAmount.add(_getBetAmount(game, _bet));

                //верим что старт == последней позиции дубликата
                if (i != _start && game.bets[_bet].dupes > 0) {
                    i += game.bets[_bet].dupes;
                }

                if (i >= game.lastRightPos) game.allDone = true;
                i++;
            }
        }

        if (game.allDone) {
            uint profit = game.amount - game.winnersAmount;
            uint royalBonus = _valueFromPercent(profit, 500);
            uint ownerPercent = _valueFromPercent(profit, 400);
            royalGameBonus = royalGameBonus.add(royalBonus);
            DividendManagerInterface dividendManager = DividendManagerInterface(dividendManagerAddress);
            dividendManager.depositDividend.value(ownerPercent)();
            game.winnersAmount = game.winnersAmount.sub(royalBonus).sub(ownerPercent);
        }

    }


    function _getBetAmount(Game storage game, uint _bet) internal view returns (uint) {
        uint amount;
        for (uint i = 0; i < game.users[_bet].length; i++) {
            amount = amount.add(game.betUsers[_bet][game.users[_bet][i]]);
        }
        return amount;
    }


    function _getPrize(Game storage game) internal {
        require(game.allDone);
        require(!game.executed[msg.sender]);
        game.executed[msg.sender] = true;
        uint amount;

        for (uint i = 0; i < game.userBets[msg.sender].length; i++) {
            if (game.userBets[msg.sender][i] >= game.lastLeftValue &&
            game.userBets[msg.sender][i] <= game.lastRightValue)
            {
                amount += game.betUsers[game.userBets[msg.sender][i]][msg.sender];
            }
        }

        if (amount > 0) {
            uint p = _percent(amount, game.winnersAmount, 4);
            msg.sender.transfer(_valueFromPercent(game.amount, p));
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

    function getPosRoyal(uint _game, uint _value) public view returns (uint) {
        return _getPos(royalGames[_game], _value);
    }

    function select_atRoyal(uint _game, uint pos) public view returns (uint) {
        return _select_at(royalGames[_game], pos);
    }

    function countRoyal(uint _game) public view returns (uint) {
        return _count(royalGames[_game]);
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
        if (pos<zeroes)
            return 0;
        else {
            uint pos_new=pos-zeroes;
            uint cur=game.bets[0].children[true];
            Node storage cur_node=game.bets[cur];
            while(true){
                uint left=cur_node.children[false];
                uint cur_num=cur_node.dupes+1;
                if (left!=0) {
                    Node storage left_node=game.bets[left];
                    uint left_count=left_node.count;
                }
                else {
                    left_count=0;
                }
                if (pos_new<left_count) {
                    cur=left;
                    cur_node=left_node;
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