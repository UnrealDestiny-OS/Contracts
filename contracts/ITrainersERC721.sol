// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract ITrainersERC721 {
    function setURI(string calldata _u) external virtual;

    function model(uint256 _id) public view virtual returns (string memory);

    function encodedData(uint256 _id) public view virtual returns(bytes memory);

    function tokenURI(uint256 _id) public view virtual returns (string memory);

    function mint(address _to, uint16 _m) public virtual;
}