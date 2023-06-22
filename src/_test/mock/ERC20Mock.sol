// SPDX-License-Identifier: Unlicense
pragma solidity <0.9.0;

import {ERC20BL} from "mgv_src/toy/ERC20BL.sol";

contract ERC20Mock is ERC20BL {
    uint8 _decimals;

    constructor(
        string memory _symbol,
        uint8 decimals_
    ) ERC20BL(_symbol, _symbol) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address owner, uint256 amount) public {
        _mint(owner, amount);
    }

    function burn(address owner, uint256 amount) public {
        _burn(owner, amount);
    }
}
