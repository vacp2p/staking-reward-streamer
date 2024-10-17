using RewardsStreamerMP as streamer;
using ERC20A as staked;

methods {
    function totalStaked() external returns (uint256) envfree;
    function totalMP() external returns (uint256) envfree;
    function users(address) external returns (uint256, uint256, uint256, uint256, uint256, uint256) envfree;
    function lastMPUpdatedTime() external returns (uint256) envfree;
    function updateGlobalState() external;
    function updateUserMP(address userAddress) external;
}

ghost mathint sumOfBalances {
	init_state axiom sumOfBalances == 0;
}

hook Sstore users[KEY address account].stakedBalance uint256 newValue (uint256 oldValue) {
    sumOfBalances = sumOfBalances - oldValue + newValue;
}

hook Sload uint256 balance users[KEY address addr].stakedBalance {
    require sumOfBalances >= to_mathint(balance);
}

ghost mathint sumOfAccountMP {
	init_state axiom sumOfAccountMP == 0;
}

hook Sstore users[KEY address account].userMP uint256 newValue (uint256 oldValue) {
    sumOfAccountMP = sumOfAccountMP - oldValue + newValue;
}

hook Sload uint256 userMP users[KEY address addr].userMP {
    require sumOfAccountMP >= to_mathint(userMP);
}

function getAccountMaxMP(address account) returns uint256 {
    uint256 maxMP;
    _, _, _, maxMP, _, _ = streamer.users(account);
    return maxMP;
}

function getAccountMP(address account) returns uint256 {
    uint256 accountMP;
    _, _, accountMP, _, _, _ = streamer.users(account);
    return accountMP;
}

function getAccountStakedBalance(address account) returns uint256 {
    uint256 stakedBalance;
    stakedBalance, _, _, _, _, _ = streamer.users(account);
    return stakedBalance;
}

invariant sumOfBalancesIsTotalStaked()
  sumOfBalances == to_mathint(totalStaked());

invariant accountMPLessEqualAccountMaxMP(address account)
  to_mathint(getAccountMP(account)) <= to_mathint(getAccountMaxMP(account));

invariant accountMPGreaterEqualAccountStakedBalance(address account)
  to_mathint(getAccountMP(account)) >= to_mathint(getAccountStakedBalance(account));

invariant totalMPGreaterEqualSumOfAccountMP() 
    to_mathint(totalMP()) >= sumOfAccountMP
    { preserved with (env e) {
        requireInvariant sumOfBalancesIsTotalStaked();
        requireInvariant accountMPGreaterEqualAccountStakedBalance(e.msg.sender);
        //requireInvariant accountMPLessEqualAccountMaxMP(e.msg.sender);
        }}

// rule sumOfAccountMPIsTotalMP() {
//
//    method f; 
//    calldataarg args;
//    env e;
//
//    requireInvariant accountMPGreaterEqualAccountStakedBalance(e.msg.sender);
//    requireInvariant accountMPLessEqualAccountMaxMP(e.msg.sender);
//
//    uint256 t = lastMPUpdatedTime(); // 10 
//
//    updateGlobalState(e);
//    updateUserMP(e, args);
//
//    require sumOfAccountMP == to_mathint(totalMP());
//
//    require lastMPUpdatedTime() == t; // 10
//    f(e, args); // stake
//    require lastMPUpdatedTime() == t; // 10
//
//    updateGlobalState(e);
//    updateUserMP(e, args);
//    require lastMPUpdatedTime() == t;
//
//
//    assert sumOfAccountMP == to_mathint(totalMP());
// }

