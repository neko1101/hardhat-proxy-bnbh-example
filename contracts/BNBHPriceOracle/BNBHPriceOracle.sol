// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "./IPriceOracle.sol";
import "./IPancakeswapV2Router02.sol";
import "./IPancakeswapV2Factory.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract BNBHPriceOracle is Initializable, AccessControlUpgradeable, IPriceOracle {
    bytes32 public constant PRICE_UPDATER = keccak256("RANDOMNESS_REQUESTER");
    uint256 public characterPriceInBNB;
    uint256[] public upgradesPriceInBNB;
    uint256 public bnbhPrice;
    uint256 public basePriceToUnlockInBNB;
    uint256 public unlockRate;

    bool public isStarted;

    IPancakeswapV2Router02 public pancakeswapV2Router;
    address public pancakeswapV2Pair;
    address public tokenAddress;

    function initialize (address _tokenAddress) public initializer {
        __AccessControl_init_unchained();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        characterPriceInBNB = 30 * 10 ** 16;
        upgradesPriceInBNB = [
        0, 75 * 10 ** 15, 75 * 10 ** 15, 125 * 10 ** 15, 
        0, 75 * 10 ** 15, 75 * 10 ** 15, 125 * 10 ** 15, 
        0, 5 * 10 ** 16, 5 * 10 ** 16, 10 * 10 ** 16, 
        0, 5 * 10 ** 16, 5 * 10 ** 16, 10 * 10 ** 16];
        bnbhPrice = 37500 * 10 ** 18;
        basePriceToUnlockInBNB = 8 * 10 ** 15;
        unlockRate = 4;
        isStarted = false;
        tokenAddress = _tokenAddress;
        //Test Net
        // IPancakeswapV2Router02 _pancakeswapV2Router = IPancakeswapV2Router02(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3);
        //Mian Net
        IPancakeswapV2Router02 _pancakeswapV2Router = IPancakeswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        
        // set the rest of the contract variables
        pancakeswapV2Router = _pancakeswapV2Router;
    }

    function getBNBHPrice() internal view returns(uint256) {
        address[] memory path = new address[](2);
        path[0] = pancakeswapV2Router.WETH();
        path[1] = tokenAddress;
        uint256[] memory result = pancakeswapV2Router.getAmountsOut(1 * 10 ** 18, path);
        return result[1];
    }

    function getCharacterPrice() external override view returns (uint256) {
        return _getCharacterPrice();
    }

    function _getCharacterPrice() internal view returns (uint256) {
        if (isStarted) {
            return characterPriceInBNB * bnbhPrice / (10 ** 18);
        }
        else
            return 5000 * 10 ** 18;
    }
    
    function getUnlockLevelPrice(uint256 level) external override view returns (uint256) {
        return ((basePriceToUnlockInBNB + (basePriceToUnlockInBNB * unlockRate * level) / 100) * bnbhPrice) / (10 ** 18);
    }

    function getExpeditePrice() external override view returns (uint256) {
        return _getCharacterPrice() / 10;
    }

    function getTownUpgradePrice(uint256 townType, uint256 level) external override view returns (uint256) {
        require(townType * 4 + level < upgradesPriceInBNB.length, "Invalid town");
        return upgradesPriceInBNB[townType * 4 + level] * bnbhPrice / (10 ** 18);
    }

    function getTownUpgradePrices() external view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](upgradesPriceInBNB.length);
        for(uint i = 0; i < upgradesPriceInBNB.length; i++){
            prices[i] = upgradesPriceInBNB[i] * bnbhPrice / (10 ** 18);
        }
        return prices;
    }

    function fetchBNBHPrice() external {
        require(hasRole(PRICE_UPDATER, msg.sender), "Sender cannot update price");
        bnbhPrice = getBNBHPrice();
        if (!isStarted &&  (5000 * 10 ** 18) >= characterPriceInBNB * bnbhPrice / (10 ** 18) ) {
            isStarted = true;
        }
    }
    function setBasePriceToUnlock(uint256 amount) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "You are not admin");
        basePriceToUnlockInBNB = amount;
    }
    function setCharacterPriceInBNB(uint256 amount) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "You are not admin");
        characterPriceInBNB = amount;
    }

    function getTokenPrice() external override view returns(uint256) {
        return bnbhPrice;
    }
}