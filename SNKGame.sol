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

    Roles.Role private _admins;

    constructor () internal {
        _addAdmin(msg.sender);
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender));
        _;
    }

    function isAdmin(address account) public view returns (bool) {
        return _admins.has(account);
    }

    function addAdmin(address account) public onlyAdmin {
        _addAdmin(account);
    }

    function renounceAdmin() public {
        _removeAdmin(msg.sender);
    }

    function _addAdmin(address account) internal {
        _admins.add(account);
        emit AdminAdded(account);
    }

    function _removeAdmin(address account) internal {
        _admins.remove(account);
        emit AdminRemoved(account);
    }
}


//TODO TEST + OWNER PERCENT
contract SNKGame is AdminRole {
    using SafeMath for uint;

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


    constructor() public {
        gameStep = 1 hours;
        closeBetsTime = 1 hours;
        gamesStart = 1546318800;
    }


    function() public payable {
        revert();
    }


    function makeBet(uint _game, uint _bet) public payable {
        require(_bet > 0);
        require(getGameTime(_game) - closeBetsTime > now);

        if (games[_game].betUsers[_bet][msg.sender] == 0) {
            insert(_game, _bet);
            games[_game].users[_bet].push(msg.sender);
            games[_game].userBets[msg.sender].push(_bet);
        }

        games[_game].amount = games[_game].amount.add(msg.value);
        games[_game].betUsers[_bet][msg.sender] = games[_game].betUsers[_bet][msg.sender].add(msg.value);
    }


    function insertResult(uint _game, uint _res) onlyAdmin public {
        //require(getGameTime(_game) < now);
        insert(_game, _res);
        games[_game].res = _res;
        games[_game].resPos = getPos(_game, _res) - 1;
    }


    function setLastLeftRight(uint _game) onlyAdmin public returns (bool) {
        require(games[_game].res > 0);

        //JackPot
        if (games[_game].bets[games[_game].res].dupes > 0) {
            games[_game].lastLeftPos = games[_game].resPos;
            games[_game].lastRightPos = games[_game].resPos;
            games[_game].lastLeftValue = games[_game].res;
            games[_game].lastRightValue = games[_game].res;
            return true;
        }

        uint lastPos = count(_game) - 1;

        if (lastPos < 19) { //1 winner
            if (games[_game].resPos == 0 || games[_game].resPos == lastPos) {
                games[_game].lastLeftPos = games[_game].resPos == 0 ? 1 : lastPos - 1;
                games[_game].lastRightPos = games[_game].lastLeftPos;
            } else {
                uint leftBet =  select_at(_game, games[_game].resPos - 1);
                uint rightBet = select_at(_game, games[_game].resPos + 1);
                uint leftBetDif = games[_game].res - leftBet;
                uint rightBetDif = rightBet - games[_game].res;

                if (leftBetDif == rightBetDif) {
                    games[_game].lastLeftPos = games[_game].resPos - 1;
                    games[_game].lastRightPos = games[_game].resPos + 1;
                }

                if (leftBetDif > rightBetDif) {
                    games[_game].lastLeftPos = games[_game].resPos + 1;
                    games[_game].lastRightPos = games[_game].resPos + 1;
                }

                if (leftBetDif < rightBetDif) {
                    games[_game].lastLeftPos = games[_game].resPos - 1;
                    games[_game].lastRightPos = games[_game].resPos - 1;
                }
            }
        } else {
            uint winnersCount = lastPos.add(1).mul(10).div(100);
            uint halfWinners = winnersCount.div(2);

            if (games[_game].resPos < halfWinners) {
                games[_game].lastLeftPos = 0;
                games[_game].lastRightPos = games[_game].lastLeftPos + winnersCount;
            } else {
                if (games[_game].resPos + halfWinners > lastPos) {
                    games[_game].lastRightPos = lastPos;
                    games[_game].lastLeftPos = lastPos - winnersCount;
                } else {
                    games[_game].lastLeftPos = games[_game].resPos - halfWinners;
                    games[_game].lastRightPos = games[_game].lastLeftPos + winnersCount;
                }
            }
        }

        games[_game].lastLeftValue = select_at(_game, games[_game].lastLeftPos);
        games[_game].lastRightValue = select_at(_game, games[_game].lastRightPos);

        games[_game].lastLeftPos = getPos(_game, games[_game].lastLeftValue) - 1;
        games[_game].lastRightPos = getPos(_game, games[_game].lastRightValue) - 1 + games[_game].bets[lastRightValue].dupes;

        return true;
    }


    function setWinnersAmount(uint _game, uint _start, uint _stop) onlyAdmin public {
        uint _bet;
        if (games[_game].lastLeftPos == games[_game].lastRightPos) {
            _bet = select_at(_game, games[_game].lastLeftPos);
            games[_game].winnersAmount = getBetAmount(_game, _bet);
            games[_game].allDone = true;
        } else {
            _start = _start > 0 ? _start : games[_game].lastLeftPos;
            _stop = _stop > 0 ? _stop : games[_game].lastRightPos;
            for (uint i = _start; i <= _stop; i++) {
                if (i == games[_game].resPos) continue;
                _bet = select_at(_game, i);
                games[_game].winnersAmount = games[_game].winnersAmount.add(getBetAmount(_game, _bet));
                if (i == games[_game].lastRightPos) games[_game].allDone = true;
            }
        }
    }


    function getBetAmount(uint _game, uint _bet) public view returns (uint) {
        uint amount;
        for (uint i = 0; i < games[_game].users[_bet].length; i++) {
            amount = amount.add(games[_game].betUsers[_bet][games[_game].users[_bet][i]]);
        }
        return amount;
    }


    function getPrize(uint _game) public {
        require(games[_game].allDone);
        require(!games[_game].prizeExecuted[msg.sender]);
        games[_game].prizeExecuted[msg.sender] = true;
        uint amount;

        for (uint i = 0; i < games[_game].userBets[msg.sender].length; i++) {
            if (games[_game].userBets[msg.sender][i] >= games[_game].lastLeftValue &&
                games[_game].userBets[msg.sender][i] <= games[_game].lastRightValue)
            {
                amount += games[_game].betUsers[games[_game].userBets[msg.sender][i]][msg.sender];
            }
        }

        if (amount > 0) {
            uint p = percent(amount, games[_game].winnersAmount, 4);
            msg.sender.transfer(valueFromPercent(games[_game].amount, p));
        }
    }


    function valueFromPercent(uint _value, uint _percent) internal pure returns(uint quotient) {
        uint _quotient = _value.mul(_percent).div(10000);
        return ( _quotient);
    }


    function percent(uint numerator, uint denominator, uint precision) internal pure returns(uint) {
        uint _numerator  = numerator * 10 ** (precision+1);
        uint _quotient =  ((_numerator / denominator) + 5) / 10;
        return _quotient;
    }


    function getGameTime(uint _id) public view returns (uint) {
        return gamesStart + (gameStep * _id);
    }


    //AVL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    function insert(uint _game, uint _value) internal {
        if (_value==0)
            games[_game].bets[_value].dupes++;
        else{
            insert_helper(_game, 0, true, _value);
        }
    }

    //return pos+1; 0 == error
    function getPos(uint _game, uint _value) public view returns (uint) {
        uint _count = count(_game);
        if (_count == 0) return 0;
        if (games[_game].bets[_value].count == 0) return 0;

        uint _first = select_at(_game, 0);
        uint _last = select_at(_game, _count-1);

        // Shortcut for the actual value
        if (_value > _last || _value < _first) return 0;
        if (_value == _first) return 1;
        if (_value == _last) _count;

        // Binary search of the value in the array
        uint min = 0;
        uint max = _count-1;
        while (max > min) {
            uint mid = (max + min + 1)/ 2;
            uint _val = select_at(_game, mid);
            if (_val <= _value) {
                min = mid;
            } else {
                max = mid-1;
            }
        }
        return min+1;
    }

    function select_at(uint _game, uint pos) public view returns (uint value){
        uint zeroes=games[_game].bets[0].dupes;
        if (pos<zeroes)
            return 0;
        else {
            uint pos_new=pos-zeroes;
            uint cur=games[_game].bets[0].children[true];
            Node storage cur_node=games[_game].bets[cur];
            while(true){
                uint left=cur_node.children[false];
                uint cur_num=cur_node.dupes+1;
                if (left!=0) {
                    Node storage left_node=games[_game].bets[left];
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
                    cur_node=games[_game].bets[cur];
                    pos_new-=left_count+cur_num;
                }
            }
        }
    }


    function duplicates(uint _game, uint value) public view returns (uint){
        return games[_game].bets[value].dupes;
    }


    function count(uint _game) public view returns (uint){
        Node storage root=games[_game].bets[0];
        Node storage child=games[_game].bets[root.children[true]];
        return root.dupes+child.count;
    }


    function insert_helper(uint _game, uint p_value, bool side, uint value) private {
        Node storage root=games[_game].bets[p_value];
        uint c_value=root.children[side];
        if (c_value==0){
            root.children[side]=value;
            Node storage child=games[_game].bets[value];
            child.parent=p_value;
            child.side=side;
            child.height=1;
            child.count=1;
            update_counts(_game, value);
            rebalance_insert(_game, value);
        }
        else if (c_value==value){
            games[_game].bets[c_value].dupes++;
            update_count(_game, value);
            update_counts(_game, value);
        }
        else{
            bool side_new=(value >= c_value);
            insert_helper(_game, c_value,side_new,value);
        }
    }

    function update_count(uint _game, uint value) private {
        Node storage n=games[_game].bets[value];
        n.count=1+games[_game].bets[n.children[false]].count+games[_game].bets[n.children[true]].count+n.dupes;
    }

    function update_counts(uint _game, uint value) private {
        uint parent=games[_game].bets[value].parent;
        while (parent!=0) {
            update_count(_game, parent);
            parent=games[_game].bets[parent].parent;
        }
    }

    function rebalance_insert(uint _game, uint n_value) private {
        update_height(_game, n_value);
        Node storage n=games[_game].bets[n_value];
        uint p_value=n.parent;
        if (p_value!=0) {
            int p_bf=balance_factor(_game, p_value);
            bool side=n.side;
            int sign;
            if (side)
                sign=-1;
            else
                sign=1;
            if (p_bf == sign*2) {
                if (balance_factor(_game, n_value) == (-1 * sign))
                    rotate(_game, n_value,side);
                rotate(_game, p_value,!side);
            }
            else if (p_bf != 0)
                rebalance_insert(_game, p_value);
        }
    }

    function update_height(uint _game, uint value) private {
        Node storage n=games[_game].bets[value];
        uint height_left=games[_game].bets[n.children[false]].height;
        uint height_right=games[_game].bets[n.children[true]].height;
        if (height_left>height_right)
            n.height=height_left+1;
        else
            n.height=height_right+1;
    }

    function balance_factor(uint _game, uint value) private view returns (int bf) {
        Node storage n=games[_game].bets[value];
        return int(games[_game].bets[n.children[false]].height)-int(games[_game].bets[n.children[true]].height);
    }

    function rotate(uint _game, uint value,bool dir) private {
        bool other_dir=!dir;
        Node storage n=games[_game].bets[value];
        bool side=n.side;
        uint parent=n.parent;
        uint value_new=n.children[other_dir];
        Node storage n_new=games[_game].bets[value_new];
        uint orphan=n_new.children[dir];
        Node storage p=games[_game].bets[parent];
        Node storage o=games[_game].bets[orphan];
        p.children[side]=value_new;
        n_new.side=side;
        n_new.parent=parent;
        n_new.children[dir]=value;
        n.parent=value_new;
        n.side=dir;
        n.children[other_dir]=orphan;
        o.parent=value;
        o.side=other_dir;
        update_height(_game, value);
        update_height(_game, value_new);
        update_count(_game, value);
        update_count(_game, value_new);
    }




}


