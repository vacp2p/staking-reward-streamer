import "./shared.spec";

using ERC20A as staked;

methods {
    function ERC20A.balanceOf(address) external returns (uint256) envfree;
    function ERC20A.allowance(address, address) external returns(uint256) envfree;
    function ERC20A.totalSupply() external returns(uint256) envfree;
    function totalStaked() external returns (uint256) envfree;
    function accounts(address) external returns (uint256, uint256, uint256, uint256, uint256, uint256) envfree;
    function lastMPUpdatedTime() external returns (uint256) envfree;
    function emergencyModeEnabled() external returns (bool) envfree;
    function Math.mulDiv(uint256 a, uint256 b, uint256 c) internal returns uint256 => mulDivSummary(a,b,c);
}

function mulDivSummary(uint256 a, uint256 b, uint256 c) returns uint256 {
  require c != 0;
  return require_uint256(a*b/c);
}

rule stakingGreaterLockupTimeMeansGreaterMPs {

  env e;
  uint256 amount;
  uint256 lockupTime1;
  uint256 lockupTime2;
  uint256 multiplierPointsAfter1;
  uint256 multiplierPointsAfter2;

  storage initalStorage = lastStorage;

  stake(e, amount, lockupTime1);
  multiplierPointsAfter1 = getAccountMP(e.msg.sender);

  stake(e, amount, lockupTime2) at initalStorage;
  multiplierPointsAfter2 = getAccountMP(e.msg.sender);

  assert lockupTime1 >= lockupTime2 => to_mathint(multiplierPointsAfter1) >= to_mathint(multiplierPointsAfter2);
  satisfy to_mathint(multiplierPointsAfter1) > to_mathint(multiplierPointsAfter2);
}


