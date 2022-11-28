// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IERC721A.sol";

contract GlangerStaking is Ownable, ReentrancyGuard, Pausable{
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardsToken;
    IERC721A public immutable nftCollection;

    bool public hasEnded;
    uint256 public endTimestamp;

    struct Staker {
        uint256 timeOfLastUpdate;
        uint256 unclaimedRewards;
        uint256[] tokenIds;
    }

    uint256 private _rewardsPerHour = 100000;

    mapping(address => Staker) public stakers;

    event StakeBatch( address indexed user, uint256[] indexed tokenIds, bool indexed locked);
    event Stake( address indexed user, uint256 indexed tokenId, bool indexed locked);
    event StakingEnded(uint256 timeEnded);


    constructor(IERC721A _nftCollection, IERC20 _rewardsToken) {
        nftCollection = _nftCollection;
        rewardsToken = IERC20(_rewardsToken);
    }

    function stakeBatch(uint256[] calldata _tokenIds) payable external nonReentrant {
        require(hasEnded == false, "Staking has ended");
        require(_tokenIds.length > 0, "Must stake at least 1 NFT");

        if (stakers[msg.sender].tokenIds.length > 0) {
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
        }
        uint256 len = _tokenIds.length;
        for (uint256 i; i < len; i++) {
            nftCollection.transferFrom{value:msg.value}(msg.sender, address(this), _tokenIds[i]);
            stakers[msg.sender].tokenIds.push(_tokenIds[i]);
        }
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;

        emit StakeBatch(msg.sender, _tokenIds, true);
    }

    function stake(uint256 _tokenId) external payable nonReentrant whenNotPaused {

        require(hasEnded == false, "Staking has ended");
        
        if (stakers[msg.sender].tokenIds.length > 0) {
            uint256 rewards = calculateRewards(msg.sender);
            stakers[msg.sender].unclaimedRewards += rewards;
        }

        nftCollection.transferFrom{value:msg.value}(msg.sender, address(this), _tokenId);
        stakers[msg.sender].tokenIds.push(_tokenId);
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;

        emit Stake(msg.sender, _tokenId, true);
    }

    /**
     * @notice Returns if user is a staker or not
     *
     * @param _staker The stakers address being checked
     */
    function isStaking(address _staker) public view returns (bool) {
        return stakers[_staker].tokenIds.length > 0;
    }

    function getIndexOf(uint256 item, uint256[] memory array)
        internal
        pure
        returns (uint256)
    {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == item) {
                return i;
            }
        }
        revert("Token not found");
    }

    function remove(uint256 index, uint256[] storage array) internal {
        if (index >= array.length) return;

        for (uint256 i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        array.pop();
    }

    function withdraw(uint256 tokenId) external nonReentrant {
        Staker memory staker = stakers[msg.sender];
        require(
            staker.tokenIds.length > 0,
            "You have no tokens staked"
        );
        uint256 rewards = calculateRewards(msg.sender);
        staker.unclaimedRewards += rewards;
        nftCollection.transferFrom(address(this), msg.sender, tokenId);
        
        uint256 index = getIndexOf(
                tokenId,
                stakers[msg.sender].tokenIds
            );
        remove(index, stakers[msg.sender].tokenIds);

        if (stakers[msg.sender].tokenIds.length == 0) {
            delete stakers[msg.sender];
        }

        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
    }

    function withdrawBatch(uint256[] calldata _tokenIds) external nonReentrant {
        Staker memory staker = stakers[msg.sender];
        require(
            staker.tokenIds.length > 0,
            "You have no tokens staked"
        );
        uint256 rewards = calculateRewards(msg.sender);
        staker.unclaimedRewards += rewards;
        uint256 len = _tokenIds.length;
        for (uint256 i; i< len; i++) {
            uint256 index = getIndexOf(
                _tokenIds[i],
                stakers[msg.sender].tokenIds
            );

            remove(index, stakers[msg.sender].tokenIds);

            nftCollection.transferFrom(address(this), msg.sender, _tokenIds[i]);
        }
        if (stakers[msg.sender].tokenIds.length == 0) {
            delete stakers[msg.sender];
        }
        
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
    }

    function claimRewards() external {
        uint256 rewards = calculateRewards(msg.sender) + stakers[msg.sender].unclaimedRewards;
        require(rewards > 0, "You have no rewards to claim");
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].unclaimedRewards = 0;
        rewardsToken.transfer(msg.sender, rewards);
    }

    function setRewardsPerHour(uint256 _newValue) public onlyOwner {
        _rewardsPerHour = _newValue;
    }

    function userStakeInfo(address _user) public view returns (uint256 _tokensStaked, uint256 _availableRewards, uint256[] memory tokenIds){
        return (stakers[_user].tokenIds.length, availableRewards(_user), stakers[_user].tokenIds);
    }

    function availableRewards(address _user) internal view returns (uint256){
        if (stakers[_user].tokenIds.length == 0) {
            return stakers[_user].unclaimedRewards;
        }
        uint256 _rewards = stakers[_user].unclaimedRewards + calculateRewards(_user);
        return _rewards;

    }

    function calculateRewards(address _staker) internal view returns (uint256 _rewards) {
        Staker memory staker = stakers[_staker];
        return (((
            ((block.timestamp - staker.timeOfLastUpdate) * staker.tokenIds.length)
        ) * _rewardsPerHour ) / 3600);
    }

    function getRewardsPerHour() public view returns(uint256) {
        return _rewardsPerHour;
    }

    /**
     * @notice Ends staking rewards at current `block.timestamp`
     *
     * Requirements
     * - Caller must be `Owner`
     */
    function endStaking(bool _isEnded) public onlyOwner {
        hasEnded = _isEnded;
        endTimestamp = _isEnded == true ? block.timestamp : 0;
        emit StakingEnded(endTimestamp);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}