pragma solidity <0.9.0;

import "../../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 public _decimals;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 decimals_
    ) ERC20(_name, _symbol) {
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
