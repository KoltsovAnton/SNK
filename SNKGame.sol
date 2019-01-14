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

        uint winnersAmount;
        uint lastLeft;
        uint lastRight;
        //TODO bool AllDone (set left right and winnersAmount)
    }

    mapping (uint => Game) public games;

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
        if (games[_game].bets[games[_game].res].dupes > 0) {
            games[_game].lastLeft = games[_game].resPos;
            games[_game].lastRight = games[_game].resPos;
            return true;
        }

        uint betsCount = count(_game);
        uint winnersCount;


        if (betsCount < 10) {
            winnersCount = 1;
        } else {
            winnersCount = betsCount.mul(10).div(100);
        }

        //TODO duples + games[_game].bets[select_at(_game, winnersCount)].dupes
        if (games[_game].resPos == 0) {
            games[_game].lastLeft = 1;
            games[_game].lastRight = winnersCount;
            return true;
        }

        //TODO overflow
        if (games[_game].resPos == betsCount - 1) {
            games[_game].lastRight = betsCount - 2;
            games[_game].lastLeft = betsCount - 2 - winnersCount;
            return true;
        }

        //TODO duples
        if (winnersCount == 1) {
            uint leftBet = games[_game].res - select_at(_game, games[_game].resPos - 1);
            uint rightBet = select_at(_game, games[_game].resPos + 1) - games[_game].res;

            if (leftBet == rightBet) {
                games[_game].lastLeft = games[_game].resPos - 1;
                games[_game].lastRight = games[_game].resPos + 1;
                return true;
            }

            if (leftBet > rightBet) {
                games[_game].lastLeft = games[_game].resPos + 1;
                games[_game].lastRight = games[_game].resPos + 1;
                return true;
            }

            if (leftBet < rightBet) {
                games[_game].lastLeft = games[_game].resPos - 1;
                games[_game].lastRight = games[_game].resPos - 1;
                return true;
            }
        }

        winnersCount = winnersCount.div(2);

        //TODO overflow + duples + разницу между overflow
        games[_game].lastLeft = games[_game].resPos - winnersCount;
        games[_game].lastRight = games[_game].resPos + winnersCount;

        return true;
    }

    //TODO iteration count
    function setWinnersAmount(uint _game) onlyAdmin public {
        uint _bet;
        if (games[_game].lastLeft == games[_game].lastRight) {
            _bet = select_at(_game, games[_game].lastLeft);
            games[_game].winnersAmount = getBetAmount(_game, _bet);
        } else {
           for (uint i = games[_game].lastLeft; i <= games[_game].lastRight; i++) {
                if (i == games[_game].resPos) continue;
                _bet = select_at(_game, i);
                games[_game].winnersAmount = games[_game].winnersAmount.add(getBetAmount(_game, _bet));
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

    //TODO get once
    function getPrize(uint _game) public {
        require(games[_game].winnersAmount > 0);
        //
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


//    function rank(uint _game, uint value) public view returns (uint smaller){
//        if(value!=0){
//            smaller=games[_game].bets[0].dupes;
//            uint cur=games[_game].bets[0].children[true];
//            Node storage cur_node=games[_game].bets[cur];
//            while(true){
//                if (cur<=value){
//                    if(cur<value)
//                        smaller+=1+cur_node.dupes;
//                    uint left_child=cur_node.children[false];
//                    if (left_child!=0)
//                        smaller+=games[_game].bets[left_child].count;
//                }
//                if (cur==value)
//                    break;
//                cur=cur_node.children[cur<value];
//            }
//        }
//    }
    //////////////////////////////////////////////////////////////////////////////

//    function rebalance_delete(uint _game, uint p_value,bool side) private{
//        if (p_value!=0) {
//            update_height(_game, p_value);
//            int p_bf=balance_factor(_game, p_value);
//            //bool dir=side;
//            int sign;
//            if (side)
//                sign=1;
//            else
//                sign=-1;
//            int bf=balance_factor(_game, p_value);
//            if (bf==(2*sign)) {
//                Node storage p=games[_game].bets[p_value];
//                uint s_value=p.children[!side];
//                int s_bf=balance_factor(_game, s_value);
//                if (s_bf == (-1 * sign))
//                    rotate(_game, s_value,!side);
//                rotate(_game, p_value,side);
//                if (s_bf!=0){
//                    p=games[_game].bets[p_value];
//                    rebalance_delete(_game, p.parent,p.side);
//                }
//            }
//            else if (p_bf != sign){
//                p=games[_game].bets[p_value];
//                rebalance_delete(_game, p.parent,p.side);
//            }
//        }
//    }
//
//    function fix_parents(uint _game, uint parent,bool side) private {
//        if(parent!=0) {
//            update_count(_game, parent);
//            update_counts(_game, parent);
//            rebalance_delete(_game, parent,side);
//        }
//    }

//    function rightmost_leaf(uint _game, uint value) private view returns (uint leaf) {
//        uint child=games[_game].bets[value].children[true];
//        if (child!=0)
//            return rightmost_leaf(_game, child);
//        else
//            return value;
//    }

//    function zero_out(uint _game, uint value) private {
//        Node storage n=games[_game].bets[value];
//        n.parent=0;
//        n.side=false;
//        n.children[false]=0;
//        n.children[true]=0;
//        n.count=0;
//        n.height=0;
//        n.dupes=0;
//    }

//    function remove_branch(uint _game, uint value,uint left,uint right) private {
//        uint ipn=rightmost_leaf(_game, left);
//        Node storage i=games[_game].bets[ipn];
//        uint dupes=i.dupes;
//        remove_helper(_game, ipn);
//        Node storage n=games[_game].bets[value];
//        uint parent=n.parent;
//        Node storage p=games[_game].bets[parent];
//        uint height=n.height;
//        bool side=n.side;
//        uint count=n.count;
//        right=n.children[true];
//        left=n.children[false];
//        p.children[side]=ipn;
//        i.parent=parent;
//        i.side=side;
//        i.count=count+dupes-n.dupes;
//        i.height=height;
//        i.dupes=dupes;
//        if (left!=0) {
//            i.children[false]=left;
//            games[_game].bets[left].parent=ipn;
//        }
//        if (right!=0) {
//            i.children[true]=right;
//            games[_game].bets[right].parent=ipn;
//        }
//        zero_out(_game, value);
//        update_counts(_game, ipn);
//    }
//
//    function remove_helper(uint _game, uint value) private {
//        Node storage n=games[_game].bets[value];
//        uint parent=n.parent;
//        bool side=n.side;
//        Node storage p=games[_game].bets[parent];
//        uint left=n.children[false];
//        uint right=n.children[true];
//        if ((left == 0) && (right == 0)) {
//            p.children[side]=0;
//            zero_out(_game, value);
//            fix_parents(_game, parent,side);
//        }
//        else if ((left !=0) && (right != 0)) {
//            remove_branch(_game, value,left,right);
//        }
//        else {
//            uint child=left+right;
//            Node storage c=games[_game].bets[child];
//            p.children[side]=child;
//            c.parent=parent;
//            c.side=side;
//            zero_out(_game, value);
//            fix_parents(_game, parent,side);
//        }
//    }
//
//    function remove(uint _game, uint value) public {
//        Node storage n=games[_game].bets[value];
//        if (value==0){
//            if (n.dupes==0)
//                return;
//        }
//        else{
//            if (n.count==0)
//                return;
//        }
//        if (n.dupes>0) {
//            n.dupes--;
//            if(value!=0)
//                n.count--;
//            fix_parents(_game, n.parent,n.side);
//        }
//        else
//            remove_helper(_game, value);
//    }





//    function in_top_n(uint _game, uint value, uint n) public view returns (bool truth){
//        uint pos=rank(_game, value);
//        uint num=count(_game);
//        return (num-pos-1<n);
//    }
//
//    function percentile(uint _game, uint value) public view returns (uint k){
//        uint pos=rank(_game, value);
//        uint same=games[_game].bets[value].dupes;
//        uint num=count(_game);
//        return (pos*100+(same*100+100)/2)/num;
//    }
//
//    function at_percentile(uint _game, uint _percentile) public view returns (uint){
//        uint n=count(_game);
//        return select_at(_game, _percentile*n/100);
//    }
//
//    function permille(uint _game, uint value) public view returns (uint k){
//        uint pos=rank(_game, value);
//        uint same=games[_game].bets[value].dupes;
//        uint num=count(_game);
//        return (pos*1000+(same*1000+1000)/2)/num;
//    }
//
//    function at_permille(uint _game, uint _permille) public view returns (uint){
//        uint n=count(_game);
//        return select_at(_game, _permille*n/1000);
//    }
//
//    function median(uint _game) public view returns (uint value){
//        return at_percentile(_game, 50);
//    }
//
//    function node_left_child(uint _game, uint value) public view returns (uint child){
//        child=games[_game].bets[value].children[false];
//    }
//
//    function node_right_child(uint _game, uint value) public view returns (uint child){
//        child=games[_game].bets[value].children[true];
//    }
//
//    function node_parent(uint _game, uint value) public view returns (uint parent){
//        parent=games[_game].bets[value].parent;
//    }
//
//    function node_side(uint _game, uint value) public view returns (bool side){
//        side=games[_game].bets[value].side;
//    }
//
//    function node_height(uint _game, uint value) public view returns (uint height){
//        height=games[_game].bets[value].height;
//    }
//
//    function node_count(uint _game, uint value) public view returns (uint){
//        return games[_game].bets[value].count;
//    }
//
//    function node_dupes(uint _game, uint value) public view returns (uint dupes){
//        dupes=games[_game].bets[value].dupes;
//    }

}


