using RewardsStreamerMP as streamer;

function getAccountStakedBalance(address account) returns uint256 {
    uint256 stakedBalance;
    stakedBalance, _, _, _, _, _ = streamer.accounts(account);
    return stakedBalance;
}

function getAccountMP(address account) returns uint256 {
    uint256 accountMP;
    _, _, accountMP, _, _, _ = streamer.accounts(account);
    return accountMP;
}

