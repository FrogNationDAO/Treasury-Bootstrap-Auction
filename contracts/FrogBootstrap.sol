pragma solidity ^0.8.7;

import "./ERC721/CustomERC721Metadata.sol";

contract FrogBootstrap is CustomERC721Metadata {


    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) CustomERC721Metadata(_name, _symbol) {

    }
}
