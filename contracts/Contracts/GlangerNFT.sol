// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GlangerNFT is ERC721A, Ownable, ReentrancyGuard{
    using SafeMath for uint256;
    using Address for address;
    using Strings for string;

    bool private PAUSE;
    string private _baseTokenURI;
    string public openBoxBeforeTokenURI;
    uint256 public maxTotalSupply;
    uint256 public openBoxTime;
    address public executorAddress;
    
    mapping(uint => mapping(address => bool)) public mintedNum;
    mapping (address => bool) _blackMarketplaces;

    struct Stage {
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        uint256 mintedNum;
        uint256 maxQuantity;
        uint256 stageNo;
    }

    mapping(uint256 => Stage) stageList;
    uint256 private stageNow = 0;

    event StageEvent(uint256 stageType, uint256 startTime, uint256 endTime, uint maxQuantity, uint mintedNum, uint256 price);
    event NFTMintEvent(uint256 stageType, uint256 token, address to, uint256 quantity, uint256 price);
    event PauseEvent(bool pause);
    event UpdateStageEvent(uint stageType, address to, uint mintedNum);
    event OpenBoxTimeEvent(uint256 openBoxTime);
    event MaxTotalSupplyEvent(uint256 _maxTotalSupply);
    event setOpenBoxBeforeTokenURIEvent(string tokenURI);
    event ExecutorAddressEvent(address indexed executorAddress);

    constructor(
        string memory baseTokenURI,
        string memory _openBoxBeforeTokenURI,
        uint256 _maxTotalSupply,
        uint256 _openBoxTime,
        address _executorAddress
    ) ERC721A("Glanger NFT", "GGN") {
        _baseTokenURI = baseTokenURI;
        openBoxBeforeTokenURI = _openBoxBeforeTokenURI;
        maxTotalSupply = _maxTotalSupply;
        openBoxTime = _openBoxTime;
        executorAddress = _executorAddress;
    }

    modifier onlyExecutor {
        require(executorAddress ==  _msgSender(), "caller is not Executor");
        _;
    }

    modifier nftIsOpen {
        require(!PAUSE, "nft is not open");
        _;
    }

    modifier stageIsOpen {
        require(stageNow > 0, "No stage set");
        _;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if(!_exists(tokenId)) revert URIQueryForNonexistentToken();
        string memory baseURI = _baseURI();
        if (bytes(baseURI).length == 0) {
            return '';
        }

        if (openBoxTime == 0 || openBoxTime > block.timestamp) {
            if (bytes(openBoxBeforeTokenURI).length == 0) {
                return '';
            }
            return string(abi.encodePacked(baseURI, openBoxBeforeTokenURI));
        } 
        return string(abi.encodePacked(baseURI, Strings.toString(tokenId), '.json'));
    } 

    function setStage(uint256 stageNo, uint256 startTime, uint256 endTime, uint256 maxQuantity, uint256 price) public onlyExecutor {
        require(stageNo > 0 && stageNo < 5, "invalid type");
        require(startTime < endTime, "The Stage Start Time And Sale Time Must Be Less End Time");
        require(endTime > block.timestamp, getCurrentTime(block.timestamp));
        require(maxQuantity > 0, "The Stage quantity has not zero");
        
        Stage memory stage;
        stage.startTime = startTime;
        stage.endTime = endTime;
        stage.maxQuantity = maxQuantity;
        stage.price = price;

        stageList[stageNo] = stage;

        stageNow = stageNo;

        emit StageEvent(stageNo, startTime, endTime, maxQuantity, stage.mintedNum, price);
    }

    function setBaseTokenURI(string memory baseTokenURI) public onlyExecutor {
        _baseTokenURI = baseTokenURI;
    }

    function setOpenBoxBeforeTokenURI(string memory _openBoxBeforeTokenURI) public onlyExecutor {
        openBoxBeforeTokenURI = _openBoxBeforeTokenURI;
        emit setOpenBoxBeforeTokenURIEvent(openBoxBeforeTokenURI);
    }

    function setMaxTotalSupply(uint256 _maxTotalSupply) public onlyExecutor {
        maxTotalSupply = _maxTotalSupply;
        emit MaxTotalSupplyEvent(maxTotalSupply);
    }

    function setOpenBoxTime(uint256 _openBoxTime) public onlyExecutor {
        require(_openBoxTime > block.timestamp, "Open Box Time Must Be More Current Time");
        openBoxTime = _openBoxTime;
        emit OpenBoxTimeEvent(_openBoxTime);
    }

    function getStage(uint8 stageNo) public view  
        returns(uint _stageType, uint256 startTime, uint256 endTime, uint _maxQuantity, uint mintNum, uint256 price) {
        require(stageNo > 0, "invalid type");
        

        Stage memory stage = stageList[stageNo];
        return (stageNo, stage.startTime, stage.endTime, stage.maxQuantity, stage.mintedNum, stage.price);
    }

    function getExecutorAddress() public view returns (address) {
        if (owner() != _msgSender()) {
            return address(0);
        }
        return executorAddress;
    }

    function executorMint(address to, uint256 quantity) public onlyExecutor nftIsOpen {
        require(_msgSender() == tx.origin, "only origin");
        require(to == msg.sender, "The address of to cannot be the address of the caller");
        require(executorAddress == msg.sender, "The address of to cannot be the address of the executor");
        require(maxTotalSupply == 0 || (totalSupply() + quantity) < maxTotalSupply, "The total supply more than max");

        _mint(to, quantity);
        emit NFTMintEvent(0, _nextTokenId() - 1, to, quantity, 0);
    }

    function currentStage() public view returns (uint256 _stage, bool _mint, uint256 _price) {
        if(stageNow == 0) {
            return (0, false, 0);
        }
        return (stageNow, true, stageList[stageNow].price);
    } 

    function updateStage(uint stageNo, address to, uint256 quantity, uint256 price) internal {
        require(stageNo > 0, "The stage has not open");
        Stage memory stage = stageList[stageNow];

        require((stage.mintedNum + quantity) <= stage.maxQuantity, "Minted more than max quantity in stage");

        require((quantity.mul(price)) <= msg.value, "value error");

        stage.mintedNum = stage.mintedNum + quantity;
        stageList[stageNow] = stage;
        
        emit UpdateStageEvent(stageNo, to, stage.mintedNum);

    }

    function getCurrentTime(uint256 settime) private pure returns(string memory) {
        return Strings.toString(settime);
    }

    function mint(address to, uint256 quantity) public payable {
        _mint(to, quantity);
    }

    function approve(address to, uint256 tokenId) public payable virtual override {
        require(_blackMarketplaces[to] == false, "Invalid Marketplace");
        super.approve(to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_blackMarketplaces[operator] == false, "Invalid Marketplace");
        super.setApprovalForAll(operator, approved);
    }

    function setBlackMarketplaces(address operator, bool approved) public onlyExecutor {
        _blackMarketplaces[operator] = approved;
    }

    function isBlackMarketplaces(address operator) public view onlyExecutor returns (bool) {
        return _blackMarketplaces[operator];
    }

    function setPause(bool _pause) public onlyOwner {
        PAUSE = _pause;
        emit PauseEvent(PAUSE);
    }

    function withDrawAll(address payable to) public onlyOwner {
        (bool success,) = to.call{gas : 21000, value : address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function setExecutorAddress(address _executorAddress) public onlyOwner {
        executorAddress = _executorAddress;
        emit ExecutorAddressEvent(_executorAddress);
    }

    function batchSafeTransferFrom(
        address _from,
        address _to,
        uint256[] memory _tokenIds,
        bytes memory _data
    ) public {
        for (uint256 i; i < _tokenIds.length; i++) {
            super.safeTransferFrom(_from, _to, _tokenIds[i], _data);
        }
    }
}