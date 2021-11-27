// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./SafeMath.sol";
import "./Strings.sol";
import "./HeroLibrary.sol";

contract BNBHCharacter is Initializable, AccessControlUpgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable {
    using Strings for uint256;
    using SafeMath for uint256;
    //using HeroLibrary for HeroLibrary.Hero;
    //using HeroLibrary for HeroLibrary.Town;
    bytes32 public constant GAME_ADMIN = keccak256("GAME_ADMIN");
    bytes32 public constant NO_OWNED_LIMIT = keccak256("NO_OWNED_LIMIT");    

    uint[] public heroTypes;
    uint[] public heroNames;
    uint[] public heroClasses;
    uint[] public attacks;
    uint[] public armors;
    uint[] public speeds;
    uint[] public randomTable;
    uint256[] public baseChances;
    uint256[] public baseBNBRewards;
    uint256[] public baseEnemyXps;
    uint256[] public requiredHps;
    uint256[] public baseTownTimes;
    uint256[] public baseTownRatio;
    uint256 public constant heroArrivalTime = 12 * 3600;
    HeroLibrary.Hero[] private _heroes;
    
    uint256 public constant maxHP = 1000;
    uint256 public constant secondsPerHp = 86;
    uint public constant characterLimit = 2;
    uint256 public maxHeroesCount;

    mapping (address => HeroLibrary.Town[4]) private towns;

    string private baseURI;

    mapping(uint256 => uint256) public lastTransferTimestamp;
    mapping(uint256 => uint256) public stackedXp;

    function initialize () public initializer {
        __ERC721_init("BNBHCharacter", "BHC");
        __AccessControl_init_unchained();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }

    modifier onlyOwnerOf(address account, uint256 _heroId) {
        require(ownerOf(_heroId) == account, "Must be owner of hero to battle");
        _;
    }

    modifier restricted() {
        _restricted();
        _;
    }

    function _restricted() internal view {
        require(hasRole(GAME_ADMIN, msg.sender) == true, "Does not have role");
    }

    function setEnemyXPs(uint256[] memory xps) public onlyOwner {
        baseEnemyXps = xps;
    }

    function setBaseChances(uint256[] memory chances) public onlyOwner {
        baseChances = chances;
    }

    function setBaseBNBRewards(uint256[] memory rewards) public onlyOwner {
        baseBNBRewards = rewards;
    }

    function setRequiredHps(uint256[] memory hps) public onlyOwner {
        requiredHps = hps;
    }

    function setBaseTownRatio(uint256[] memory ratios) public onlyOwner {
        baseTownRatio = ratios;
    }
    function setHeroNames(uint256[] memory values) public onlyOwner {
        heroNames = values;
    }
    function setBaseTownTimes(uint256[] memory values) public onlyOwner {
        baseTownTimes = values;
    }
    function setHeroTypes(uint256[] memory values) public onlyOwner {
        heroTypes = values;
    }
    function setAttacks(uint256[] memory values) public onlyOwner {
        attacks = values;
    }
    function setArmors(uint256[] memory values) public onlyOwner {
        armors = values;
    }
    function setSpeeds(uint256[] memory values) public onlyOwner {
        speeds = values;
    }

    function setRandomTable(uint256[] memory values) public onlyOwner {
        randomTable = values;
    }

    function setMaxHeroesCount(uint256 count) public onlyOwner {
        maxHeroesCount = count;
    }

    function addHero(uint256 heroType, uint256 heroName, uint256 attack, uint256 armor, uint256 speed) public onlyOwner {
        heroTypes.push(heroType);
        heroNames.push(heroName);
        attacks.push(attack);
        armors.push(armor);
        speeds.push(speed);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        if(to != address(0) && to != address(0x000000000000000000000000000000000000dEaD) && !hasRole(NO_OWNED_LIMIT, to)) {
            require(balanceOf(to) < characterLimit + _getTownLevel(to, 1) , "Recv has too many characters");
        }
        if (from != address(0)) {
            // require (isContract(to) == true || isContract(from) == true, "transfer between wallets was disabled");
            require ((isContract(from) == false && hasRole(NO_OWNED_LIMIT, to)) || isContract(to) == false && hasRole(NO_OWNED_LIMIT, from));
            // lastTransferTimestamp[tokenId] = block.timestamp;
        }        
        super._beforeTokenTransfer(from, to, tokenId);
    }
    function getHero(uint256 _heroId, bool calcTown) external view returns (HeroLibrary.Hero memory) {
        return _getHero(_heroId, calcTown);
    }

    function getLevel(uint256 _heroId) external view returns (uint256) {
        return _heroes[_heroId].xp / 1000;
    }

    function getRarity(uint256 _heroId) external view returns (uint256) {
        return _heroes[_heroId].heroType;
    }

    function _getHero(uint256 _heroId, bool calcTown) internal view returns (HeroLibrary.Hero memory) {
        require(_heroId < _heroes.length, "Does not exist hero");
        uint level = _getTownLevel(ownerOf(_heroId), 3);
        HeroLibrary.Hero memory hero = _heroes[_heroId];
        if (hero.arrivalTime > block.timestamp) {
            // if hero was not arrived yet, it returns fake hero.
            return HeroLibrary.Hero(21, 5, 1000, 0, 0, 0, block.timestamp, _heroId, hero.arrivalTime - block.timestamp, 1, 5);
        }
        hero.attack += 10 * ((hero.xp.div(1000)).sub(1));
        hero.speed += 10 * ((hero.xp.div(1000)).sub(1));
        hero.armor += 10 * ((hero.xp.div(1000)).sub(1));
        if (calcTown == true) {
            hero.attack += baseTownRatio[12 + level];
            hero.speed += baseTownRatio[12 + level];
            hero.armor += baseTownRatio[12 + level];
        }        
        (uint256 hpPoints,) = getHpPoints(_heroId, calcTown);
        hero.hp = hpPoints;
        hero.arrivalTime = hero.arrivalTime <= block.timestamp ? 0: hero.arrivalTime - block.timestamp;
        return hero;
    }

    function getTownsOfPlayer(address account) public view returns (HeroLibrary.Town[4] memory)  {
        return towns[account];
    }

    function getTownLevel(address account, uint8 townType) external view returns (uint8) {
        return _getTownLevel(account, townType);
    }
    function _getTownLevel(address account, uint8 townType) internal view returns (uint8) {
        if (towns[account][townType].lastUpgradedTimeStamp <= block.timestamp) {
            return towns[account][townType].level;                
        } else if (towns[account][townType].level - 1 >= 0) {
            return towns[account][townType].level - 1; 
        }
        return 0;
    }

    function upgradeTown(address player, uint8 townType) external restricted {
        if (towns[player][townType].level == 0) {
            towns[player][townType] = HeroLibrary.Town(0, block.timestamp); 
        }
        HeroLibrary.Town storage town = towns[player][townType];
        require(town.level < 3, "Town was already fully upgraded");
        require(town.lastUpgradedTimeStamp <= block.timestamp);
        town.level += 1;
        town.lastUpgradedTimeStamp = block.timestamp + baseTownTimes[townType * 4 + town.level] * 3600;
    }

    function getHpPoints(uint256 _heroId, bool calcTown) public view returns (uint256, uint256) {
        uint8 level = _getTownLevel(ownerOf(_heroId), 1);
        uint256 _secondsPerHp = secondsPerHp;
        if (calcTown) {
            secondsPerHp.mul(100 - baseTownRatio[4 + level]).div(100);
        }
        return (getHpPointsFromTimestamp(_heroes[_heroId].hp, _secondsPerHp), _secondsPerHp);
    }

    function calcHpForFreeHeroes(uint256 _heroId, uint256 timestamp) public view returns(uint256) {
        return getHpPointsFromTimestamp(_heroes[_heroId].hp + timestamp, secondsPerHp);
    }

    function getHpPointsFromTimestamp(uint256 timestamp, uint256 _secondsPerHp) internal view returns (uint256) {
        if(timestamp  > block.timestamp)
            return 0;

        uint256 points = (block.timestamp <= timestamp? 0: (block.timestamp - timestamp)) / _secondsPerHp;
        if(points > maxHP) {
            points = maxHP;
        }
        return points;
    }
    function unlockLevel(uint256 _heroId) external restricted returns(uint256) {        
        HeroLibrary.Hero storage hero = _heroes[_heroId];
        require(hero.xp == (hero.level + 1) * 1000 - 1, "You can unlock the level after you reach full xp" );
        require(hero.level < 101, "All levels were unlocked");
        hero.level += 1;
        hero.xp += stackedXp[_heroId];
        stackedXp[_heroId] = 0;
        return hero.level;
    }

    function fight(address player, uint256 _attackingHero, uint enemyType, uint256 seed) external restricted onlyOwnerOf(player, _attackingHero) returns(uint256) {
        // require (lastTransferTimestamp[_attackingHero] + 12 * 3600 < block.timestamp, "Transfer cool down time error");
        HeroLibrary.Hero memory attacker = _getHero(_attackingHero, true);
        HeroLibrary.Hero storage hero = _heroes[_attackingHero];
        require (hero.xp != (hero.level + 1) * 1000 - 1, "You need to unlock the level");
        require(hero.arrivalTime < block.timestamp, "Hero did not arrive yet");
        (uint256 hpPoints, uint256 _secondsPerHp) = getHpPoints(_attackingHero, true);
        require (hpPoints >= requiredHps[enemyType], "BNBHero: hero needs to rest for a while" );
        
        if (hpPoints >= maxHP) {
            hero.hp = block.timestamp - getStaminaMaxWait();
            attacker.hp = hero.hp;
        }
        uint successChance = baseChances[enemyType] + attacker.attack * 10 / 100;
        if (seed.mod(1000) + successChance > 1000) {
            successChance = 1;
        } else {
            successChance = 0;
        }
        // calculate xp
        uint8 level = _getTownLevel(player, 2);     
        hero.xp += (baseEnemyXps[enemyType] + baseTownRatio[8 + level]) * successChance; 
        if (hero.xp >= (hero.level + 1) * 1000) {
            stackedXp[_attackingHero] = hero.xp - ((hero.level + 1) * 1000 - 1);
            hero.xp = (hero.level + 1) * 1000 - 1;            
        }
        if (attacker.xp > stackedXp[_attackingHero]) {
            attacker.xp -= stackedXp[_attackingHero];
        }
        // calculate bnb reward        
        uint256 bnbRewards = baseBNBRewards[enemyType] + baseBNBRewards[enemyType] * attacker.speed / 1000;        
        level = _getTownLevel(player, 0);
        bnbRewards = bnbRewards.add(bnbRewards.mul(baseTownRatio[level]).div(100)).mul(successChance);

        uint16 hpLoss = 0;
        
        if (requiredHps[enemyType] > (attacker.armor / 10) * successChance) {
            hpLoss = uint16(requiredHps[enemyType] - (attacker.armor / 10) * successChance);
            hero.hp += hpLoss * _secondsPerHp;
        } 
        return uint256(hpLoss | ((hero.xp - attacker.xp) << 16) | (bnbRewards << 40)) ;
        
    }

    function getStaminaMaxWait() internal pure returns (uint256) {
        return uint256(maxHP * secondsPerHp);
    }

    function resumeStaminaTimeStamp(uint256 _heroId, uint256 timeStamp) external restricted {
        HeroLibrary.Hero storage hero = _heroes[_heroId];
        hero.hp += timeStamp;
    }

    function mint(address minter, uint256 seed) external restricted returns(uint256) {
        // require(_heroes.length <= maxHeroesCount, "BNBHCH: max limit");
        uint256 id = _heroes.length;
        uint256 seedNum = randomTable[seed.mod(100)];
        uint256 hpTimestamp = block.timestamp - getStaminaMaxWait();
        _heroes.push(HeroLibrary.Hero(heroNames[seedNum], heroTypes[seedNum], 1000, attacks[seedNum], armors[seedNum], speeds[seedNum], hpTimestamp, id, block.timestamp + heroArrivalTime, 1, heroClasses[seedNum]));
        _safeMint(minter, id);
        return id;
    }
    function expediteHero(uint256 _heroId) external restricted{
        HeroLibrary.Hero storage hero = _heroes[_heroId];
        hero.arrivalTime = block.timestamp;        
    }
    function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        require(_exists(tokenId), "Cannot query non-existent token");
        
        return string(abi.encodePacked(_baseURI(), tokenId.toString()));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory uri) public onlyOwner {
        baseURI = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}