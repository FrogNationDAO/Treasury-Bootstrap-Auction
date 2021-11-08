pragma solidity ^0.8.7;

import "./ERC721/CustomERC721Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FrogBootstrap is CustomERC721Metadata, Ownable {
    using SafeMath for uint256;

    event Mint(
        address indexed _to,
        uint256 indexed _tokenId,
        uint256 indexed _projectId

    );

    struct Project {
        string name;
        string artist;
        string description;
        string website;
        string license;
        bool dynamic;
        string projectBaseURI;
        string projectBaseIpfsURI;
        uint256 invocations;
        uint256 maxInvocations;
        string ipfsHash;
        bool useHashString;
        bool useIpfs;
        bool active;
        bool locked;
        bool paused;
        bool whitelist;
        mapping(address => bool) isMintWhitelisted;
    }

    address public frogBootstrapAddress;
    uint256 public frogBootstrapPercentage = 20;
    uint256 public nextProjectId = 0;

    uint256 constant ONE_MILLION = 1_000_000;

    mapping(uint256 => Project) projects;

    mapping(uint256 => address) public projectIdToArtistAddress;
    mapping(uint256 => string) public projectIdToCurrencySymbol;
    mapping(uint256 => address) public projectIdToCurrencyAddress;
    mapping(uint256 => uint256) public projectIdToPricePerTokenInWei;
    mapping(uint256 => address) public projectIdToAdditionalPayee;
    mapping(uint256 => uint256) public projectIdToAdditionalPayeePercentage;
    mapping(uint256 => uint256) public projectIdToSecondaryMarketRoyaltyPercentage;

    mapping(uint256 => string) public staticIpfsImageLink;
    mapping(uint256 => uint256) public tokenIdToProjectId;
    mapping(uint256 => uint256[]) internal projectIdToTokenIds;
    mapping(uint256 => bytes32) public tokenIdToHash;
    mapping(bytes32 => uint256) public hashToTokenId;

    mapping(address => bool) public isWhitelisted;

    modifier onlyArtist(uint256 _projectId) {
        require(msg.sender == projectIdToArtistAddress[_projectId], "Only artist");
        _;
    }

    modifier onlyWhitelisted() {
        require(isWhitelisted[msg.sender], "Only whitelisted");
        _;
    }

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) CustomERC721Metadata(_name, _symbol) {
        isWhitelisted[msg.sender] = true;
        frogBootstrapAddress = msg.sender;
    }

    function addProject(
        string memory _projectName,
        address _artistAddress,
        uint256 _pricePerToken,
        bool _whitelist
    )
        public onlyWhitelisted
    {

        uint256 projectId = nextProjectId;
        projectIdToArtistAddress[projectId] = _artistAddress;
        projects[projectId].name = _projectName;
        projectIdToCurrencySymbol[projectId] = "FTM";
        projectIdToPricePerTokenInWei[projectId] = _pricePerToken;

        projects[projectId].paused = true;
        projects[projectId].whitelist = _whitelist;
        projects[projectId].maxInvocations = ONE_MILLION;

        nextProjectId = nextProjectId.add(1);
    }

    function mint(address _to, uint256 _projectId, address _by) external returns (uint256 _tokenId) {
        require(
            projects[_projectId].whitelist && projects[_projectId].isMintWhitelisted[msg.sender],
            "Must mint from whitelisted minter contract."
        );
        require(projects[_projectId].invocations.add(1) <= projects[_projectId].maxInvocations, "Must not exceed max invocations");
        require(projects[_projectId].active || _by == projectIdToArtistAddress[_projectId], "Project must exist and be active");
        require(!projects[_projectId].paused || _by == projectIdToArtistAddress[_projectId], "Purchases are paused.");

        return _mintToken(_to, _projectId);
    }

    function _mintToken(address _to, uint256 _projectId) internal returns (uint256) {
        uint256 upcomingToken = (_projectId * ONE_MILLION) + projects[_projectId].invocations;
        projects[_projectId].invocations = projects[_projectId].invocations.add(1);

        bytes32 hash = keccak256(
            abi.encodePacked(
                projects[_projectId].invocations,
                block.number,
                blockhash(block.number - 1),
                msg.sender)
        );

        tokenIdToHash[upcomingToken] = hash;
        hashToTokenId[hash] = upcomingToken;

        super._mint(_to, upcomingToken);

        tokenIdToProjectId[upcomingToken] = _projectId;
        projectIdToTokenIds[_projectId].push(upcomingToken);

        emit Mint(_to, upcomingToken, _projectId);

        return upcomingToken;
    }

    function updateFrogBootstrap(address _frogBootstrap) public onlyOwner {
        frogBootstrapAddress = _frogBootstrap;
    }

    function addWhitelisted(address _address) public onlyOwner {
        isWhitelisted[_address] = true;
    }

    function removeWhitelisted(address _address) public onlyOwner {
        isWhitelisted[_address] = false;
    }

    function addMintWhitelisted(uint256 _projectId, address _address) public onlyArtist(_projectId) {
        require(projects[_projectId].whitelist, "Bootstrap: Not a whitelist project");
        projects[_projectId].isMintWhitelisted[_address] = true;
    }

    function removeMintWhitelisted(uint256 _projectId, address _address) public onlyArtist(_projectId) {
        require(projects[_projectId].whitelist, "Bootstrap: Not a whitelist project");
        projects[_projectId].isMintWhitelisted[_address] = false;
    }

    function toggleProjectPaused(uint256 _projectId) public onlyArtist(_projectId) {
        projects[_projectId].paused = !projects[_projectId].paused;
    }

    function updateFrogBootstrapPercentage(uint256 _frogBootstrapPercentage) public onlyOwner {
        require(_frogBootstrapPercentage <= 50, "Bootstrap: Max %50");
        frogBootstrapPercentage = _frogBootstrapPercentage;
    }

    function toggleProjectActive(uint256 _projectId) public onlyOwner {
        projects[_projectId].active = !projects[_projectId].active;
    }
}
