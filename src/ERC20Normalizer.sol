// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {IERC20} from "@mgv/src/core/MgvLib.sol";

/// @title ERC20Normalizer
/// @author Paul Razvan Berg
contract ERC20Normalizer {
    /*//////////////////////////////////////////////////////////////////////////
                                       ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Thrown when attempting to compute the scalar for a token whose decimals are zero.
    error ERC20Normalizer_TokenDecimalsZero(IERC20 token);

    /// @notice Thrown when attempting to compute the scalar for a token whose decimals are greater than 18.
    error ERC20Normalizer_TokenDecimalsGreaterThan18(
        IERC20 token,
        uint256 decimals
    );

    /// INTERNAL STORAGE ///

    /// @dev Mapping between ERC-20 tokens and their associated scalars $10^(18 - decimals)$.
    mapping(IERC20 => uint256) internal scalars;

    /// CONSTANT FUNCTIONS ///

    function getScalar(IERC20 token) public view returns (uint256 scalar) {
        // Check if we already have a cached scalar for the given token.
        scalar = scalars[token];
    }

    /// NON-CONSTANT FUNCTIONS ///

    function computeScalar(IERC20 token) public returns (uint256 scalar) {
        // Query the ERC-20 contract to obtain the decimals.
        uint256 decimals = uint256(token.decimals());

        // Revert if the token's decimals are zero.
        if (decimals == 0) {
            revert ERC20Normalizer_TokenDecimalsZero(token);
        }

        // Revert if the token's decimals are greater than 18.
        if (decimals > 18) {
            revert ERC20Normalizer_TokenDecimalsGreaterThan18(token, decimals);
        }

        // Calculate the scalar.
        unchecked {
            scalar = 10 ** (18 - decimals);
        }

        // Save the scalar in storage.
        scalars[token] = scalar;
    }

    function denormalize(
        IERC20 token,
        uint256 amount
    ) external returns (uint256 denormalizedAmount) {
        uint256 scalar = getScalar(token);

        // If the scalar is zero, it means that this is the first time we encounter this ERC-20 token. We compute
        // its precision scalar and cache it.
        if (scalar == 0) {
            scalar = computeScalar(token);
        }

        // Denormalize the amount. It is safe to use unchecked arithmetic because we do not allow tokens with decimals
        // greater than 18.
        unchecked {
            denormalizedAmount = scalar != 1 ? amount / scalar : amount;
        }
    }

    function normalize(
        IERC20 token,
        uint256 amount
    ) external returns (uint256 normalizedAmount) {
        uint256 scalar = getScalar(token);

        // If the scalar is zero, it means that this is the first time we encounter this ERC-20 token. We need
        // to compute its precision scalar and cache it.
        if (scalar == 0) {
            scalar = computeScalar(token);
        }

        // Normalize the amount. We have to use checked arithmetic because the calculation can overflow uint256.
        normalizedAmount = scalar != 1 ? amount * scalar : amount;
    }
}
