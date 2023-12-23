// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {Ownable} from "lib/allo/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
// import Allo V2
import {Allo} from "lib/allo/contracts/core/Allo.sol";
import {Registry} from "lib/allo/contracts/core/Registry.sol";
// import {Anchor} from "../lib/allo/contracts/core/Anchor.sol";
import {Metadata} from "../lib/allo/contracts/core/libraries/Metadata.sol";
import {ISignatureTransfer} from "lib/allo/lib/permit2/src/interfaces/ISignatureTransfer.sol";
import {DonationVotingMerkleDistributionDirectTransferStrategy} from "lib/allo/contracts/strategies/donation-voting-merkle-distribution-direct-transfer/DonationVotingMerkleDistributionDirectTransferStrategy.sol";
import {DonationVotingMerkleDistributionBaseStrategy} from "lib/allo/contracts/strategies/donation-voting-merkle-base/DonationVotingMerkleDistributionBaseStrategy.sol";

contract PledgePost {
    Allo allo;
    Registry registry;
    // Anchor anchor;
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 nonce = 0;
    uint256 articleCount = 0;

    bytes32 public ownerProfileId;

    // author => articles
    // track articles by author
    mapping(address => Article[]) private authorArticles;

    // profileId => articles
    mapping(bytes32 => Article) private profileArticle;
    mapping(uint256 => address) public strategies;

    struct Article {
        uint256 id;
        address payable author;
        string content; // CID
        uint256 donationsReceived;
        bytes32 profileId;
        uint256 articleCount;
    }
    event ArticlePosted(
        address indexed author,
        string content,
        uint256 articleId,
        bytes32 profileId
    );
    event ArticleDonated(
        address indexed author,
        address indexed from,
        uint256 articleId,
        uint256 amount
    );
    event RoundCreated(
        uint256 indexed poolId,
        string name,
        address token,
        uint256 amount,
        address strategy
    );
    event RoundApplied(
        address indexed author,
        uint256 articleId,
        uint256 roundId
    );

    constructor(
        address _owner,
        address payable _treasury,
        uint256 _percentFee,
        uint256 _baseFee
    ) {
        // deploy Allo V2 contracts
        registry = new Registry();
        allo = new Allo();

        // initialize Allo V2 contracts
        registry.initialize(_owner);
        allo.initialize(
            _owner,
            address(registry),
            payable(_treasury),
            _percentFee,
            _baseFee
        );
        address[] memory members = new address[](1);
        members[0] = _owner;

        // create a new profile for the owner
        ownerProfileId = registry.createProfile(
            nonce,
            "PledgePost Contract Owner Profile",
            Metadata({protocol: 1, pointer: "PledgePost"}),
            address(this),
            members
        );
        nonce++;
    }

    // ====================================
    // PleldgePost function
    // ====================================

    function postArticle(
        string memory _content,
        address[] memory _contributors
    ) external returns (Article memory) {
        require(bytes(_content).length > 0, "Content cannot be empty");
        bytes32 profileId = registry.createProfile(
            nonce,
            "PledgePost Author Profile:",
            Metadata({protocol: 1, pointer: "PledgePost"}),
            msg.sender,
            _contributors
        );
        uint articleId = authorArticles[msg.sender].length;
        Article memory newArticle = Article({
            id: articleId,
            author: payable(msg.sender),
            content: _content,
            donationsReceived: 0,
            profileId: profileId,
            articleCount: articleCount
        });

        authorArticles[msg.sender].push(newArticle);
        articleCount++;
        emit ArticlePosted(msg.sender, _content, articleId, profileId);
        return newArticle;
    }

    function updateArticle(
        uint256 _articleId,
        string calldata _content
    ) external {}

    function donateToArticle(
        address payable _author,
        uint256 _articleId
    ) external payable {}

    function applyForRound(uint256 _roundId, uint256 _articleId) external {}

    function createRound(
        string calldata _name,
        ISignatureTransfer _permit2,
        uint256 _amount,
        address[] memory _managers,
        uint64 registrationStartTime,
        uint64 registrationEndTime,
        uint64 allocationStartTime,
        uint64 allocationEndTime
    ) external payable returns (uint256) {
        // deploy strategy
        DonationVotingMerkleDistributionDirectTransferStrategy _strategy = new DonationVotingMerkleDistributionDirectTransferStrategy(
                address(allo),
                _name,
                _permit2
            );
        // the case of using other tokens,
        // take array of adddress as argument and add to _allowedTokens
        address[] memory _allowedTokens = new address[](1);
        _allowedTokens[0] = NATIVE;

        ///  _data The data to be decoded to initialize the strategy
        bytes memory _data = abi.encode(
            DonationVotingMerkleDistributionBaseStrategy.InitializeData({
                useRegistryAnchor: false,
                metadataRequired: false,
                registrationStartTime: registrationStartTime,
                registrationEndTime: registrationEndTime,
                allocationStartTime: allocationStartTime,
                allocationEndTime: allocationEndTime,
                allowedTokens: _allowedTokens
            })
        );

        Metadata memory _metadata = Metadata({
            protocol: 1,
            pointer: "PledgePost QF Strategy"
        });

        // fund pool when deploying strategy instead of allo.fundPool function
        // strategy is not initialized yet, it'll be initialized here
        uint256 poolId = allo.createPoolWithCustomStrategy{value: _amount}(
            ownerProfileId,
            address(_strategy),
            _data,
            NATIVE,
            _amount,
            _metadata,
            _managers
        );
        strategies[poolId] = address(_strategy);
        emit RoundCreated(poolId, _name, NATIVE, _amount, address(_strategy));
        return poolId;
    }

    function getArticlesByAuthor(
        address _author
    ) external view returns (Article[] memory) {
        return authorArticles[_author];
    }

    function getArticleByProfileId(
        bytes32 _profileId
    ) external view returns (Article memory) {
        return profileArticle[_profileId];
    }

    // ====================================
    // Registry function
    // ====================================

    function addMembers(
        bytes32 _profileId,
        address[] calldata _members
    ) external {
        registry.addMembers(_profileId, _members);
    }

    function getAlloAddress() external view returns (address) {
        return address(allo);
    }

    function getRegistryAddress() external view returns (address) {
        return address(registry);
    }

    function getStrategyAddress(
        uint256 _poolId
    ) external view returns (address) {
        return allo.getStrategy(_poolId);
    }
}
