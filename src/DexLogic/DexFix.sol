pragma solidity >=0.8.10;

//import {IERC20} from "mgv_src/MgvLib.sol";
import {IDexLogic} from "./IDexLogic.sol";
import {UD60x18, ud} from "@prb/math/UD60x18.sol";
import {IERC20} from "mgv_src/MgvLib.sol";
import {ERC20Normalizer} from "src/ERC20Normalizer.sol";

contract DexFix is IDexLogic {
    UD60x18 PRICE;
    address private immutable BASE;
    address private immutable QUOTE;
    ERC20Normalizer internal immutable N;

    constructor(address base_tkn, address quote_tkn) {
        BASE = base_tkn;
        QUOTE = quote_tkn;
        N = new ERC20Normalizer();
    }

    function setPrice(UD60x18 price) external {
        PRICE = price;
    }

    /// @notice See IDexLogic
    function currentPrice(
        address base,
        address quote
    ) external view override returns (UD60x18) {
        if (base == BASE && quote == QUOTE) {
            return PRICE;
        } else if (base == QUOTE && quote == BASE) {
            return ud(1e18).div(PRICE);
        } else {
            revert("DexFix/currentPrice/token not supported");
        }
    }

    /// @notice See IDexLogic
    function swap(
        address token_in,
        address token_out,
        UD60x18 amount_in,
        UD60x18 amount_out_min
    ) external returns (UD60x18 amount_out) {
        require(0 < PRICE.unwrap(), "price not set");
        require(
            token_in == BASE || token_in == QUOTE,
            "token_in not supported"
        );
        require(
            token_out == BASE || token_out == QUOTE,
            "token_out not supported"
        );

        if (token_in == BASE) {
            amount_out = amount_in * PRICE;
        } else {
            amount_out = amount_in / PRICE;
        }
        require(amount_out >= amount_out_min, "DexFix/swap/fail/slippage");

        IERC20(token_in).transferFrom(
            msg.sender,
            address(this),
            N.denormalize(IERC20(token_in), amount_in.unwrap())
        );
        IERC20(token_out).transfer(
            msg.sender,
            N.denormalize(IERC20(token_out), amount_out.unwrap())
        );
    }
}
