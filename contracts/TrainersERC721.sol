// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract TrainersERC721 is AccessControl, ERC721Enumerable {
    event MintTrainer(uint16, uint256, address);

    using Strings for uint256;
    using Strings for uint16;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant DEP = keccak256("DEP");

    string public tokenURI_;
    uint256 public tokenTraker_ = 1;

    mapping(uint256 => uint16) private modelTraker_;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return tokenURI_;
    }

    function setURI(string calldata _u) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenURI_ = _u;
    }

    function tokenModel(uint256 _id) external view returns (uint256) {
        return modelTraker_[_id];
    }

    function tokenURI(
        uint256 _id
    ) public view virtual override returns (string memory) {
        _requireMinted(_id);

        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    _id.toString(),
                    "?model=",
                    modelTraker_[_id].toString()
                )
            );
    }

    function mint(address _to, uint16 _m) public virtual onlyRole(DEP) {
        uint256 _tokenId = tokenTraker_;
        modelTraker_[_tokenId] = _m;
        tokenTraker_ += 1;
        _mint(_to, _tokenId);
        emit MintTrainer(_m, _tokenId, _to);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControl, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}